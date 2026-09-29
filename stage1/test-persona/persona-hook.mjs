// Stage 1.3, second half - used ONLY after the first half proved that a phone
// session inherits ARENA_PERSONA from the server process.
//
// SessionStart hook: tells the new session which persona it plays. It must run
// on "clear" as well as "startup", because /clear from the phone is how Dror
// starts a clean conversation (decision 3, 29/09/2026) - and /clear starts a
// fresh context that would otherwise forget the persona.
//
// Prints nothing when ARENA_PERSONA is unset, so the hook is harmless in any
// session that was not started by a persona server.

const persona = (process.env.ARENA_PERSONA || '').trim();
if (!persona) process.exit(0);

const context =
  `הפרסונה של הסשן הזה: ${persona}. ` +
  'כשדרור שואל "מה הפרסונה שלך?", ענה בשם הזה במדויק. ' +
  '(זו בדיקה של שלב 1.3 — אין לה משמעות מעבר לאימות המנגנון.)';

process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'SessionStart',
    additionalContext: context,
    sessionTitle: `בדיקה – ${persona}`,
  },
}));
