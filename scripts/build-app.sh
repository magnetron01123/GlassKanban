#!/bin/bash
# Keeps a ready-to-use "Glass Kanban.app" directly in the project folder, so
# the current state of the project can always be opened from the Finder
# without anyone asking for a build first.
#
# Wired into two hooks in .claude/settings.json:
#   --session-start  Checked when a session starts.
#   --stop           Checked after every turn.
# Both modes only take a fingerprint of the sources (a few milliseconds) and,
# if it changed, hand the actual build to a detached background process —
# hooks stay fast and never make a turn wait on xcodebuild. Run without
# arguments (or --manual) from a terminal for a synchronous, visible build.
# Add --release for an optimized build (slower, but the animations run the
# way they will ship).
#
# The build itself still lands in ~/Library/Caches/GlassKanban/DerivedData —
# that part is unrelated to where the app ends up and stays outside
# ~/Documents on purpose (iCloud's extended attributes break code signing
# mid-build, see CLAUDE.md). Only the finished, already-signed bundle is then
# copied straight into the project folder with `ditto`. The project folder is
# inside iCloud Drive, so this app gets re-uploaded on every rebuild and can
# be evicted from local storage under storage pressure (a re-download before
# the next open is the only symptom) — accepted trade-off, chosen over a
# symlink into ~/Applications.

set -u

MODE="--manual"
CONFIG="Debug"
for arg in "$@"; do
    case "$arg" in
        --stop | --session-start | --manual | --worker) MODE="$arg" ;;
        --release) CONFIG="Release" ;;
        --debug) CONFIG="Debug" ;;
        *)
            printf 'build-app.sh: unbekanntes Argument: %s\n' "$arg" >&2
            exit 2
            ;;
    esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 0

SUPPORT="$HOME/Library/Caches/GlassKanban"
DERIVED="$SUPPORT/DerivedData"
STATE_DIR="$SUPPORT/state"
LOG="$SUPPORT/build.log"
BUILT_STATE="$STATE_DIR/built-$CONFIG"
FAILED_STATE="$STATE_DIR/failed-$CONFIG"
REPORTED_STATE="$STATE_DIR/reported-$CONFIG"
LOCK="$STATE_DIR/lock"
TARGET="$ROOT/Glass Kanban.app"
STAGING="$ROOT/.Glass Kanban.app.building"

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# Everything the built app is made of. .DS_Store is skipped: the Finder rewrites
# it constantly and it never reaches the bundle.
fingerprint() {
    {
        find GlassKanban -name '.DS_Store' -prune -o -type f -print0 |
            sort -z | xargs -0 shasum 2>/dev/null
        shasum project.yml 2>/dev/null
        printf '%s\n' "$CONFIG"
    } | shasum | cut -d' ' -f1
}

json_string() {
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Runs the actual build. Used both for a synchronous --manual run from a
# terminal and for a detached --worker run kicked off in the background by a
# hook — same steps either way, only whether progress is echoed differs.
do_build() {
    if ! mkdir "$LOCK" 2>/dev/null; then
        [ "$MODE" = "--manual" ] && printf 'Ein Build läuft bereits — übersprungen.\n'
        return 0
    fi
    trap 'rmdir "$LOCK" 2>/dev/null' RETURN

    FP="$(fingerprint)"

    run() {
        if [ "$MODE" = "--manual" ]; then
            "$@" 2>&1 | tee -a "$LOG"
            return "${PIPESTATUS[0]}"
        fi
        "$@" >>"$LOG" 2>&1
    }

    : >"$LOG"
    local ok=1

    if [ project.yml -nt GlassKanban.xcodeproj/project.pbxproj ]; then
        run xcodegen generate || ok=0
    fi

    run xcodebuild \
        -project GlassKanban.xcodeproj \
        -scheme GlassKanban \
        -configuration "$CONFIG" \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED" \
        build || ok=0

    local product="$DERIVED/Build/Products/$CONFIG/Glass Kanban.app"
    [ -d "$product" ] || ok=0

    if [ "$ok" = "1" ]; then
        # Stage under a dot-prefixed name first, then swap into place with a
        # single rename: a half-copied "Glass Kanban.app" would be a broken
        # app, and a running instance survives its bundle being replaced
        # this way underneath it.
        rm -rf "$STAGING"
        # ditto, not cp: it preserves the extended attributes the code
        # signature is checked against.
        if ditto "$product" "$STAGING" >>"$LOG" 2>&1; then
            rm -rf "$TARGET"
            mv "$STAGING" "$TARGET" || ok=0
        else
            ok=0
        fi
    fi

    if [ "$ok" = "1" ]; then
        # iCloud Drive quarantines anything freshly written under it, which
        # makes Gatekeeper run the app translocated (a randomized
        # /private/var/folders/... copy instead of the real path) on first
        # open. Not a signing problem — codesign is valid either way — but
        # translocation defeats the whole point of a fixed, double-clickable
        # location. Stripping once right after the move isn't enough: the
        # iCloud daemon has been observed re-tagging the file a few seconds
        # later, racing this very script. Keep checking for a few seconds so
        # the app is clean by the time anyone actually clicks it.
        for _ in 1 2 3 4 5 6; do
            xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null
            sleep 1
            xattr -p com.apple.quarantine "$TARGET" >/dev/null 2>&1 || break
        done
    fi

    if [ "$ok" = "1" ]; then
        printf '%s' "$FP" >"$BUILT_STATE"
        rm -f "$FAILED_STATE" "$REPORTED_STATE"
        [ "$MODE" = "--manual" ] && printf '\nGlass Kanban.app (%s) neu gebaut: %s\n' "$CONFIG" "$TARGET"
        return 0
    fi

    rm -rf "$STAGING"
    local tail
    tail="$(grep -E 'error:|BUILD FAILED|xcodebuild:' "$LOG" 2>/dev/null | tail -20)"
    [ -n "$tail" ] || tail="$(tail -20 "$LOG" 2>/dev/null)"
    local message="App-Build fehlgeschlagen ($CONFIG). Glass Kanban.app im Projektordner zeigt weiterhin den letzten funktionierenden Stand.

$tail

Vollständiges Log: $LOG"

    printf '%s' "$FP" >"$FAILED_STATE"
    rm -f "$REPORTED_STATE"
    if [ "$MODE" = "--manual" ]; then
        printf '%s\n' "$message" >&2
        return 1
    fi
    return 0
}

if [ "$MODE" = "--manual" ] || [ "$MODE" = "--worker" ]; then
    do_build
    exit $?
fi

# --- --stop / --session-start: fast dispatch called by hooks. Never builds
# inline — only decides whether a background build is needed and, if a
# previous one failed, reports it once.
FP="$(fingerprint)"

app_is_current() {
    [ -d "$TARGET" ] &&
        [ -f "$BUILT_STATE" ] &&
        [ "$(cat "$BUILT_STATE" 2>/dev/null)" = "$FP" ]
}

# iCloud Drive has been observed to re-tag an unchanged app with
# com.apple.quarantine well after it was written (independent of anything this
# script does). No rebuild needed for that — just strip it again; this is
# milliseconds, cheap enough to check on every hook run.
if app_is_current && xattr -p com.apple.quarantine "$TARGET" >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null
fi

CONTEXT=""
if [ -f "$FAILED_STATE" ] && [ "$(cat "$FAILED_STATE" 2>/dev/null)" = "$FP" ]; then
    ALREADY_REPORTED="$(cat "$REPORTED_STATE" 2>/dev/null)"
    if [ "$ALREADY_REPORTED" != "$FP" ]; then
        printf '%s' "$FP" >"$REPORTED_STATE"
        CONTEXT="App-Build ist für den aktuellen Stand fehlgeschlagen. Log: $LOG"
    fi
elif ! app_is_current && [ ! -d "$LOCK" ]; then
    # Detached: survives this hook process exiting, keeps writing to LOG.
    RELEASE_FLAG=""
    [ "$CONFIG" = "Release" ] && RELEASE_FLAG="--release"
    nohup "$0" --worker $RELEASE_FLAG >/dev/null 2>&1 </dev/null &
    disown 2>/dev/null || true
fi

if [ -n "$CONTEXT" ]; then
    ESCAPED="$(json_string "$CONTEXT")"
    if [ "$MODE" = "--session-start" ]; then
        printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s},"suppressOutput":true}\n' "$ESCAPED"
    else
        printf '{"systemMessage":%s}\n' "$ESCAPED"
    fi
fi

exit 0
