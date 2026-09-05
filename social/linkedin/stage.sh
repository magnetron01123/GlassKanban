#!/bin/zsh
# Clears the stage for a take: hides every visible app except Glass Kanban, and
# puts them back afterwards. Written 05.09.2026 — without this the 130 pt top
# margin of the recording region shows whatever window happens to sit behind
# the board (measured: the Claude and Mail windows were in frame).
# Usage: stage.sh hide | stage.sh show
set -euo pipefail
LIST=/tmp/stage-hidden.txt
case "${1:?hide|show}" in
hide)
  osascript -e 'tell application "System Events" to get name of every process whose visible is true and background only is false' \
    | tr ',' '\n' | sed 's/^ *//' | grep -v '^Glass Kanban$' | grep -v '^Finder$' > "$LIST"
  # Finder is deliberately left alone: hiding it needs Apple Events consent for
  # Finder, and macOS raises that dialog mid-take (measured 05.09.2026 — it cost
  # takes 2 and 3). Desktop icons are already off, so Finder shows nothing.
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    osascript -e "tell application \"System Events\" to set visible of process \"$p\" to false" >/dev/null 2>&1 || true
  done < "$LIST"
  osascript -e 'tell application "Glass Kanban" to activate' >/dev/null
  ;;
show)
  [ -f "$LIST" ] || exit 0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    osascript -e "tell application \"System Events\" to set visible of process \"$p\" to true" >/dev/null 2>&1 || true
  done < "$LIST"
  ;;
esac
