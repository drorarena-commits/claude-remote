# שלב 1 — תוצאות (29/09/2026, 23:05–24:00)

שרת: `claude remote-control --name "יוני קומקס" --spawn=same-dir --capacity 1 --permission-mode default`
(מקובץ Startup `comax-agent.cmd`, גרסה 2.1.284).

## 1.2 — בדיקות מהטלפון

| # | בדיקה | תוצאה |
|---|---|---|
| 1 | השם בטלפון | ⚠️ הטלפון מציג **מחשב → תיקייה** (`DESKTOP-M2EJSOI` → `C:\AGENT-COMAX-CLOAD`), לא את `--name`. שם הסשן = ההודעה הראשונה |
| 2 | שיחה נקייה | ✅ לא זוכר שיחות, מכיר CLAUDE.md / זיכרון / git |
| 3 | מלאי (comax-stock) | ✅ ענה מ-`content/` בלבד, לא נגע בקומקס. ⚠️ לא מכיר את הייצוא הלילי לפי מחסן ב-`data/exports/` — לתקן בנפרד (משימה ליוני) |
| 4–5 | מחברי claude.ai | ✅ Gmail, WordPress, Canva, Drive, Calendar, Trello — מחוברים ועובדים. ⚠️ "המייל האחרון": לבדוק תאריך של כל הודעה בשרשור, לא רק הראשונה |
| 6 | דפדפן | ✅ הכרום של קומקס (CDP, `ensure-window.js`). ⚪ Claude in Chrome לא נבדק (`claudeInChromeDefaultEnabled=false`) — נחמה כנראה צריכה אותו |
| 6+ | **שליחת קובץ לטלפון** | ❌ `SendUserFile`: "this session is not on a project thread, so it has nowhere to place a file" |
| 7 | בקשת אישור | ✅ אחרי מעבר ל-Manual: בקשת אישור הגיעה לטלפון |
| 8 | פוש | ✅ `PushNotification` הגיע. הסוכן שולח פוש רק כשמבקשים במפורש |
| 9 | סשן שני | ✅ "Directory at capacity — end one of its sessions" |
| 10 | שיחה נקייה | ✅ ארכוב → סשן חדש נפתח · ✅ `/clear` מהאייפון עובד. **נשארים עם `/clear`** |

## ממצאים שמשנים את התוכנית

1. **מצב ההרשאות נקבע בצד שפותח את הסשן**, לא בשרת. סשן שנפתח מאפליקציית הדסקטופ קיבל
   `auto` (העדפת התיקייה באפליקציה: comax=auto). `--permission-mode default` הוא רק ברירת מחדל.
2. **אין שמות בטלפון** — רק תיקיות. שרתים נוספים באותה תיקייה (נחמה/רונית) לא יהיו ניתנים להבחנה.
3. **קבצים לטלפון רק ב-Projects** (בטא). אבל: Project לא יכול להריץ שרשור על המחשב כש-Trusted
   Devices דלוק, ושרשור מקומי רץ ב-auto.
4. `lock.js`: בדיקה ו-`--confirm` הן הרצות נפרדות ואטומיות — אין צורך בנעילה לפי סשן (שלב 4).
5. קובצי cmd חייבים CRLF (עם LF + `chcp 65001` ה-cmd בולע תווים).

## החלטות פתוחות לדרור

- שליחת קבצים: א. Projects · ב. Google Drive (קישור) · ג. טלגרם. המלצה: ב' עכשיו, לבדוק א' בנפרד.
- Trusted Devices מול Projects — אי אפשר את שניהם.
- מצב ההרשאות באפליקציית הדסקטופ לתיקיית קומקס (היום: auto).
- Claude in Chrome לסשנים מהשרת (`claudeInChromeDefaultEnabled`).
- נשאר: 1.3 (ניסוי שמות — פחות רלוונטי אחרי ממצא 2), 1.4 (Trusted Devices).

## לבדוק בהזדמנות

- שגרה (Routine) באפליקציית הדסקטופ "ייצוא פריטים לילי מקומקס" רצה ב-22:57 אחרי הריסטרט — כפילות של COMAX-Items-Export-Nightly (03:00)?
- נעילת המסך אחרי Autologon מגיעה ~2 דקות מאוחר (Startup folder) — משימה מתוזמנת בשלב 3.
