#!/bin/zsh
# Records one take of the Glass Kanban board: window + MX pt side margin and
# MY pt top/bottom margin, cursor included, stops after DURATION seconds.
# Clears the stage first (stage.sh) and brings the board to the front.
# Usage: social/linkedin/record.sh <take-number> [duration=20]
# Needs: stage.sh and window-id.swift next to this file, ffmpeg, a 2x display,
#        and macOS screen-recording permission for the terminal host.
#
# Defaults are the published clip (take 14, 05.09.2026): window 1220 x 1000 pt,
# MX=20 MY=130 → a square 1260 x 1260 pt region = 2520 x 2520 px. README.md in
# this folder is the runbook.
#
# 05.09.2026: rewritten from `screencapture -v -C -R` to ffmpeg/AVFoundation.
# Measured that day: screencapture wrote a file whose 495 extracted frames were
# byte-identical — a frozen still, although the move really happened on screen.
# It also ignored -V (ran minutes past the requested seconds). AVFoundation
# grabs the full HiDPI backing store (3840 x 2160 = 2 x the 1920 x 1080 logical
# desktop), so the crop below is simply points x 2.
set -euo pipefail
N=${1:?take number}; DUR=${2:-20}; OUT=/tmp/take$N.mov
S=2                      # pixels per point on the recording display
MX=${MX:-20}; MY=${MY:-130}   # margins in points, must match cut.sh.
# 05.09.2026: for the 1:1 cut the region is made square in the RECORDING
# (MX=20, MY=130 around a 1220 x 1000 pt window = 1260 x 1260 pt), so the
# wallpaper above and below is really there. Padding it in afterwards looks
# like padding; this does not.
# The avfoundation index of the main display moves whenever an iPhone
# (Continuity Camera) is nearby, so look it up by name instead of hard-coding it.
SCREEN=$(ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 | sed -n 's/.*\[\([0-9]*\)\] Capture screen 0$/\1/p')
[ -n "$SCREEN" ] || { echo "no 'Capture screen 0' device — screen-recording permission missing?"; exit 1; }
pgrep -q -f "Glass Kanban.app/Contents/MacOS/Glass Kanban" || { echo "Glass Kanban is not running"; exit 1; }
[ -x /tmp/window-id ] || swiftc -O -o /tmp/window-id "$(dirname "$0")/window-id.swift"
"$(dirname "$0")/stage.sh" hide
trap '"$(dirname "$0")/stage.sh" show' EXIT
osascript -e 'tell application "Glass Kanban" to activate'; sleep 1
eval $(/tmp/window-id | tr ' ' '\n' | grep -v '^id=' | tr '\n' ' ')
CW=$(( S*(w+2*MX) )); CH=$(( S*(h+2*MY) )); CX=$(( S*(x-MX) )); CY=$(( S*(y-MY) ))
[ "$CW" -eq "$CH" ] || echo "note: region ${CW}x${CH} is not square — cut.sh FRAME=native scales it to 1080x1080 anyway; adjust MY for a square"
echo "board at x=$x y=$y w=$w h=$h — recording $OUT, crop ${CW}x${CH}+${CX}+${CY}, ${DUR}s, starting in 3 s"
sleep 3
ffmpeg -hide_banner -loglevel error -f avfoundation -capture_cursor 1 -framerate 30 \
  -i "$SCREEN" -t "$DUR" -vf "crop=${CW}:${CH}:${CX}:${CY}" \
  -c:v libx264 -preset ultrafast -crf 16 -pix_fmt yuv420p -y "$OUT"
echo "recorded $OUT"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames -show_entries format=duration -of default=nw=1 "$OUT"
