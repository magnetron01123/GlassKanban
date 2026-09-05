#!/bin/zsh
# Records one take of the Glass Kanban board: window + 40 pt side margin and
# 130 pt top/bottom margin (room for the 4:5 crop), cursor included, stops
# after DURATION seconds. Clears the stage first (stage.sh) and brings the
# board to the front.
# Usage: plans/linkedin/record.sh <take-number> [duration=40]
# Needs: /tmp/window-id, stage.sh next to this file, ffmpeg, and macOS
#        screen-recording permission for the terminal host.
#
# 05.09.2026: rewritten from `screencapture -v -C -R` to ffmpeg/AVFoundation.
# Measured that day: screencapture wrote a file whose 495 extracted frames were
# byte-identical — a frozen still, although the move really happened on screen.
# It also ignored -V (ran minutes past the requested seconds). AVFoundation
# grabs the full HiDPI backing store (3840 x 2160 = 2 x the 1920 x 1080 logical
# desktop), so the crop below is simply points x 2.
set -euo pipefail
N=${1:?take number}; DUR=${2:-40}; OUT=/tmp/take$N.mov
S=2                      # pixels per point on the recording display
MX=${MX:-40}; MY=${MY:-130}   # margins in points, must match cut.sh.
# 05.09.2026: for the 1:1 cut the region is made square in the RECORDING
# (MX=20, MY=364 around a 1300 x 612 pt window = 1340 x 1340 pt), so the
# wallpaper above and below is really there. Padding it in afterwards looks
# like padding; this does not.
SCREEN=1                 # avfoundation index of "Capture screen 0" (main display)
pgrep -q -f "Glass Kanban.app/Contents/MacOS/Glass Kanban" || { echo "Glass Kanban is not running"; exit 1; }
[ -x /tmp/window-id ] || swiftc -O -o /tmp/window-id "$(dirname "$0")/window-id.swift"
"$(dirname "$0")/stage.sh" hide
trap '"$(dirname "$0")/stage.sh" show' EXIT
osascript -e 'tell application "Glass Kanban" to activate'; sleep 1
eval $(/tmp/window-id | tr ' ' '\n' | grep -v '^id=' | tr '\n' ' ')
CW=$(( S*(w+2*MX) )); CH=$(( S*(h+2*MY) )); CX=$(( S*(x-MX) )); CY=$(( S*(y-MY) ))
echo "board at x=$x y=$y w=$w h=$h — recording $OUT, crop ${CW}x${CH}+${CX}+${CY}, ${DUR}s, starting in 3 s"
sleep 3
ffmpeg -hide_banner -loglevel error -f avfoundation -capture_cursor 1 -framerate 30 \
  -i "$SCREEN" -t "$DUR" -vf "crop=${CW}:${CH}:${CX}:${CY}" \
  -c:v libx264 -preset ultrafast -crf 16 -pix_fmt yuv420p -y "$OUT"
echo "recorded $OUT"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames -show_entries format=duration -of default=nw=1 "$OUT"
