/**
 * השומר של שרת "יוני קומקס" (claude remote-control על C:\AGENT-COMAX-CLOAD).
 *
 *   node guard.mjs            בדיקה (כל 5 דקות): השרת לא רץ ⇒ מפעיל אותו ומודיע בטלגרם
 *   node guard.mjs --boot     אחרי כניסה ל-Windows: כמו בדיקה + פותח את הכרום של דרור
 *   node guard.mjs --nightly  04:30: הפעלה מחדש יזומה — מדלג אם יש שיחה פעילה או משימת קומקס
 *
 * השרת מופעל **רק** מכאן, דרך `comax-agent.cmd` שבתיקייה הזאת (לא מתיקיית Startup —
 * שני מפעילים היו מרימים שני שרתים על אותה תיקייה בכניסה ל-Windows).
 *
 * ⛔ לא נוגע ב-`runs/.lock` (רק מציץ), במאזין התור ובמשימות COMAX-*.
 * טלגרם: הכלי הקיים של קומקס (`orders-app/telegram.js`), **רק לדרור**, ורק כשקרה משהו.
 */
import { execFileSync, spawn } from 'node:child_process';
import { appendFileSync, existsSync, readFileSync, writeFileSync, openSync, readSync, fstatSync, closeSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const COMAX = 'C:\\AGENT-COMAX-CLOAD';
const CMD = resolve(HERE, 'comax-agent.cmd');
const SERVER_LOG = resolve(HERE, 'logs', 'yoni-debug.log');
const GUARD_LOG = resolve(HERE, 'logs', 'guard.log');
const STATE = resolve(HERE, 'logs', 'guard-state.json');
const ACTIVE_MIN = Number(process.argv.find((a) => a.startsWith('--active-min='))?.split('=')[1] ?? 15);
const ALERT_EVERY_MS = 60 * 60 * 1000; // כישלון חוזר — הודעה אחת בשעה, לא כל 5 דקות

const mode = process.argv.includes('--nightly') ? 'nightly' : process.argv.includes('--boot') ? 'boot' : 'check';
const now = () => new Date().toLocaleString('he-IL', { hour12: false });
const log = (m) => appendFileSync(GUARD_LOG, `${new Date().toISOString()} [${mode}] ${m}\n`, 'utf8');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function ps(command) {
  return execFileSync('powershell', ['-NoProfile', '-NonInteractive', '-Command',
    `[Console]::OutputEncoding=[Text.Encoding]::UTF8; ${command}`], {
    encoding: 'utf8', timeout: 30_000, stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true,
  });
}

/** כל תהליכי chrome.exe / claude.exe — מזהה, הורה ושורת פקודה. */
function processes() {
  const out = ps(`Get-CimInstance Win32_Process -Filter "Name='claude.exe' or Name='chrome.exe'" | ` +
    `Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress`);
  const j = out.trim() ? JSON.parse(out) : [];
  return (Array.isArray(j) ? j : [j]).map((p) => ({ pid: p.ProcessId, ppid: p.ParentProcessId, name: p.Name, cmd: p.CommandLine ?? '' }));
}

const servers = (list) => list.filter((p) => p.name === 'claude.exe' && p.cmd.includes('remote-control') && p.cmd.includes('yoni-debug.log'));

/** הכרום האישי של דרור: chrome.exe ראשי (בלי --type) שאינו על --user-data-dir (הכרום של קומקס כן). */
const personalChrome = (list) => list.some((p) => p.name === 'chrome.exe' && !p.cmd.includes('--type=') && !p.cmd.includes('--user-data-dir'));

/** מתי השרת רשם פעילות של שיחה לאחרונה — מסוף הלוג (זמנים ב-UTC). */
function lastSessionActivity() {
  if (!existsSync(SERVER_LOG)) return null;
  const fd = openSync(SERVER_LOG, 'r');
  try {
    const size = fstatSync(fd).size;
    const len = Math.min(size, 2_000_000);
    const buf = Buffer.alloc(len);
    readSync(fd, buf, 0, len, size - len);
    const lines = buf.toString('utf8').split('\n').filter((l) => /\[bridge:(ws|activity)\] sessionId=/.test(l));
    const last = lines.at(-1);
    return last ? new Date(last.slice(0, 24)) : null;
  } finally {
    closeSync(fd);
  }
}

/** מי מחזיק בנעילת קומקס — הצצה בלבד, דרך הקוד של קומקס עצמו. */
async function comaxLockHolder() {
  const { peek } = await import(pathToFileURL(resolve(COMAX, 'src', 'lock.js')).href);
  return peek();
}

function loadState() {
  try { return JSON.parse(readFileSync(STATE, 'utf8')); } catch { return {}; }
}

async function telegram(text, { throttle = false } = {}) {
  const state = loadState();
  if (throttle && state.lastAlert && Date.now() - state.lastAlert < ALERT_EVERY_MS) {
    log('טלגרם: דולג (כבר נשלחה התראה בשעה האחרונה)');
    return;
  }
  try {
    const { sendMessage } = await import(pathToFileURL(resolve(COMAX, 'orders-app', 'telegram.js')).href);
    const { config } = await import(pathToFileURL(resolve(COMAX, 'orders-app', 'config.js')).href);
    await sendMessage(text, { chatId: config.telegram.chatId }); // רק לדרור, לא לכל נמעני הבוט
    writeFileSync(STATE, JSON.stringify({ ...state, lastAlert: throttle ? Date.now() : state.lastAlert }), 'utf8');
    log(`טלגרם נשלח: ${text.split('\n')[0]}`);
  } catch (e) {
    log(`טלגרם נכשל: ${e.message}`);
  }
}

/** מפעיל את השרת דרך explorer.exe — לא יורש סביבה ולא תלוי בתהליך הזה. מחזיר את התהליך או null. */
async function startServer() {
  if (!existsSync(CMD)) throw new Error(`לא נמצא ${CMD}`);
  spawn('explorer.exe', [CMD], { detached: true, stdio: 'ignore' }).unref();
  for (let i = 0; i < 30; i++) {
    await sleep(2000);
    const s = servers(processes());
    if (s.length) return s[0];
  }
  return null;
}

function killServer(pid) {
  try {
    execFileSync('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore', windowsHide: true });
  } catch { /* כבר נסגר */ }
}

async function ensureRunning(reason) {
  const list = processes();
  const s = servers(list);
  if (s.length > 1) log(`⚠️ ${s.length} שרתים רצים: ${s.map((x) => x.pid).join(', ')}`);
  if (s.length) return { running: true, pid: s[0].pid };

  log(`השרת לא רץ — מפעיל (${reason})`);
  const started = await startServer();
  if (started) {
    log(`הופעל, PID ${started.pid}`);
    if (mode === 'check') await telegram(`🔄 השרת של יוני קומקס (Remote Control) לא רץ והופעל מחדש — ${now()}.\nאפשר לפתוח שיחה מהטלפון.`);
    writeFileSync(STATE, JSON.stringify({ ...loadState(), lastAlert: 0 }), 'utf8');
    return { running: true, pid: started.pid, started: true };
  }
  log('ההפעלה נכשלה — אין תהליך אחרי 60 שניות');
  await telegram(`⚠️ השרת של יוני קומקס לא רץ, והפעלה מחדש נכשלה — ${now()}.\nצריך מבט במחשב (logs\\guard.log).`, { throttle: true });
  return { running: false };
}

async function nightly() {
  const holder = await comaxLockHolder();
  if (holder) return log(`דילוג: משימת קומקס "${holder.task}" רצה (PID ${holder.pid})`);
  const last = lastSessionActivity();
  const idleMin = last ? (Date.now() - last.getTime()) / 60000 : Infinity;
  if (idleMin < ACTIVE_MIN) return log(`דילוג: פעילות שיחה לפני ${idleMin.toFixed(1)} דק' (סף ${ACTIVE_MIN})`);

  const s = servers(processes());
  for (const x of s) killServer(x.pid);
  log(`הפעלה מחדש יזומה — נסגרו ${s.length} שרתים (פעילות אחרונה לפני ${Number.isFinite(idleMin) ? idleMin.toFixed(0) : '∞'} דק')`);
  await sleep(3000);
  await ensureRunning('הפעלה מחדש יזומה');
}

async function openPersonalChrome() {
  if (personalChrome(processes())) return log('הכרום של דרור כבר פתוח');
  const exe = ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    `${process.env.LOCALAPPDATA ?? ''}\\Google\\Chrome\\Application\\chrome.exe`].find((p) => existsSync(p));
  if (!exe) return log('לא נמצא chrome.exe — הכרום של דרור לא נפתח');
  spawn(exe, ['--profile-directory=Profile 1'], { detached: true, stdio: 'ignore' }).unref();
  log('נפתח הכרום של דרור (Profile 1)');
}

try {
  if (mode === 'nightly') await nightly();
  else {
    if (mode === 'boot') await openPersonalChrome();
    const r = await ensureRunning(mode === 'boot' ? 'כניסה ל-Windows' : 'בדיקה תקופתית');
    if (r.running && !r.started && mode === 'boot') log(`השרת כבר רץ, PID ${r.pid}`);
  }
} catch (e) {
  log(`שגיאה: ${e.stack ?? e.message}`);
  await telegram(`⚠️ השומר של יוני קומקס נכשל — ${now()}:\n${e.message}`, { throttle: true });
  process.exitCode = 1;
}
