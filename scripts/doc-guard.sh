#!/bin/bash
# Guards against documentation drift.
#
# The project's rule is that behaviour never changes without SPEC.md, CONCEPT.md
# or BACKLOG.md changing with it (see CLAUDE.md). A rule that only lives in a
# prompt is a rule that gets forgotten, so this script is wired into two hooks in
# .claude/settings.json and runs regardless of what any session remembers.
#
# Modes:
#   --stop           Stop hook. Holds the turn once with a reminder when the
#                    branch changed app code but no documentation.
#   --session-start  SessionStart hook. Reports drift inherited from an earlier
#                    session as context, without holding anything.
#
# The signal is everything the current branch changed against main (committed)
# plus the working tree — the project works one topic per branch, so the branch
# is the right unit, and a mid-session commit cannot hide the drift. Tests are
# deliberately excluded: they follow behaviour, they don't define it.
#
# The reminder fires at most once per session per state of the code. Warning
# again on a turn that changed nothing would make the guard noise, and a guard
# that becomes noise gets switched off. Touching further Swift files changes the
# fingerprint and earns a fresh reminder.
#
# Deliberately not wrapped in `|| true` by its callers: a guard that fails
# silently is worse than no guard, so a broken script must surface as a hook
# error rather than as quiet success.

set -u

MODE="${1:---stop}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0
cd "$ROOT" || exit 0

INPUT=""
if [ ! -t 0 ]; then
    INPUT="$(cat)"
fi

# A held Stop hook makes Claude continue, which fires Stop again. Without this
# guard the reminder would repeat forever.
case "$INPUT" in
    *'"stop_hook_active": true'* | *'"stop_hook_active":true'*) exit 0 ;;
esac

SESSION="$(printf '%s' "$INPUT" |
    sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -1)"
[ -n "$SESSION" ] || SESSION="unknown"

changed_files() {
    base="$(git merge-base main HEAD 2>/dev/null)"
    if [ -n "$base" ]; then
        git diff --name-only "$base" HEAD 2>/dev/null
    fi
    git status --porcelain 2>/dev/null | sed 's/^...//' | sed 's/.* -> //'
}

FILES="$(changed_files | sort -u)"
CODE="$(printf '%s\n' "$FILES" | grep '^GlassKanban/.*\.swift$')"
DOCS="$(printf '%s\n' "$FILES" | grep '^[^/]*\.md$')"

# Nothing to say: either no app code moved, or the docs moved with it.
[ -n "$CODE" ] || exit 0
[ -z "$DOCS" ] || exit 0

# .git is outside the working tree, so state can never be committed by accident.
STATE_DIR="$(git rev-parse --git-dir 2>/dev/null)/doc-guard"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
find "$STATE_DIR" -name '*.state' -mtime +7 -delete 2>/dev/null

STATE_FILE="$STATE_DIR/$(printf '%s' "$SESSION" | tr -c 'a-zA-Z0-9._-' '_').state"
FINGERPRINT="$(printf '%s' "$CODE" | cksum)"
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$FINGERPRINT" ]; then
    exit 0
fi
printf '%s' "$FINGERPRINT" >"$STATE_FILE" 2>/dev/null

COUNT="$(printf '%s\n' "$CODE" | grep -c .)"
LIST="$(printf '%s\n' "$CODE" | sed 's/^/  - /')"

REMINDER="Doku-Wächter: Dieser Branch ändert ${COUNT} Swift-Datei(en), aber keine Projekt-Dokumentation.

${LIST}

Bitte prüfen:
- Hat sich sichtbares Verhalten geändert? Dann SPEC.md nachziehen.
- Wurde eine Design-Entscheidung getroffen oder eine Alternative verworfen? Dann CONCEPT.md oder BACKLOG.md, mit Datum.
- Wurde eine früher abgelehnte Idee revidiert? Dann den Eintrag in BACKLOG.md unter \"Explizit abgelehnt\" als revidiert markieren statt ihn zu löschen — sonst widersprechen sich die Dokumente.
- Ist wirklich keine Doku-Änderung nötig (reines Refactoring, Bugfix ohne Verhaltensänderung)? Dann das in einem Satz ausdrücklich sagen und beenden."

json_string() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

ESCAPED="$(json_string "$REMINDER")"

if [ "$MODE" = "--session-start" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s},"suppressOutput":true}\n' "$ESCAPED"
else
    printf '{"decision":"block","reason":%s,"systemMessage":"Doku-Wächter: Code geändert, Dokumentation nicht — Claude prüft das noch."}\n' "$ESCAPED"
fi

exit 0
