#!/bin/zsh
# Contact sheet for picking a take and reading marks: one frame every 0.25 s.
# Usage: plans/linkedin/frames.sh /tmp/take2.mov [fps=4]
# Output: /tmp/frames-<name>/f%03d.png — frame number ÷ fps = seconds into the take.
set -euo pipefail
IN=${1:?take.mov}; FPS=${2:-4}; NAME=$(basename "$IN" .mov); OUT=/tmp/frames-$NAME
rm -rf "$OUT"; mkdir -p "$OUT"
ffmpeg -v error -i "$IN" -vf "fps=$FPS,scale=690:-1" "$OUT/f%03d.png"
echo "$(ls "$OUT" | wc -l | tr -d ' ') frames in $OUT (÷$FPS = seconds)"
