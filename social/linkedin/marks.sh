#!/bin/zsh
# Reads the three cut marks off a take automatically, from per-frame motion.
# Usage: social/linkedin/marks.sh /tmp/take14.mov        → prints "HOVER DROP END"
#        eval $(social/linkedin/marks.sh /tmp/take14.mov --export)  → B_HOVER=… B_DROP=… B_END=…
#
# Written 05.09.2026, calibrated on take14 (the published clip: hand-read marks
# 7.69 / 9.93 / 11.65, this script says 7.83 / 9.98 / 11.63 — same clip). The
# take has exactly one move: pointer rests on the card, drags it to Erledigt,
# the card settles and strikes through, then nothing moves. Motion per frame is
# the mean absolute difference to the previous frame (0…255) on a 160 px
# grayscale copy; the drag shows as spikes ≈ 1 (the synthetic move is stepwise),
# the settle + strike-through as the last, larger burst (≈ 2.5).
#   HOVER = first motion − 0.5 s   (half a second of rest on the card)
#   DROP  = start of the last burst − CHIME_OFFSET (0.45 s; cut.sh puts the
#           chime at DROP + 0.45, i.e. exactly on the strike-through)
#   END   = last motion + 1.1 s   (the rest that makes the loop breathe)
set -euo pipefail
IN=${1:?take.mov}; MODE=${2:-}
NOISE=0.02      # below this a frame counts as still
BURST=0.3       # above this a frame belongs to the move / the strike-through
GAP=0.4         # seconds of quiet that separate two bursts
CSV=$(mktemp)
ffmpeg -hide_banner -loglevel error -i "$IN" \
  -vf "scale=160:-2,format=gray,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" \
  -f null - \
  | awk '/pts_time/{t=$3;sub("pts_time:","",t)} /YAVG/{split($0,a,"=");printf "%.3f %.4f\n",t,a[2]}' > "$CSV"
read HOVER DROP END <<< "$(awk -v noise=$NOISE -v burst=$BURST -v gap=$GAP '
  $1<1.0                     { next }   # frame 1 has no predecessor, and the first quarter second carries encoder noise
  $2>noise && first==""      { first=$1 }
  $2>burst                   { if (last!="" && $1-last>gap) start=$1; if (start=="") start=$1; last=$1 }
  $2>noise                   { lastany=$1 }
  END { if (first=="") { print "no motion in take" > "/dev/stderr"; exit 1 }
        printf "%.2f %.2f %.2f\n", first-0.5, start-0.45, lastany+1.1 }' "$CSV")"
rm -f "$CSV"
case "$MODE" in
  --export) echo "B_HOVER=$HOVER B_DROP=$DROP B_END=$END" ;;
  *)        echo "$HOVER $DROP $END" ;;
esac
