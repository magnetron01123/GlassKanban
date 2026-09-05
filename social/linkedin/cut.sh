#!/bin/zsh
# Cuts the LinkedIn clips from one screen-recording take — each in 4:5 (main,
# 1080×1350) and 1:1 (1080×1080).
# Usage: social/linkedin/cut.sh TAKE.mov OUTDIR
# Requires ffmpeg (brew install ffmpeg). Written 05.09.2026 as a template:
# every value in the "MARKS" block is read off the take (QuickTime: ⌘T shows
# the timecode) and filled in BEFORE the first run. Not yet run — ffmpeg was
# not installed when this was written; ran end to end on a synthetic 40-s take
# the same day (1380×692 still image, CROP 692/692/688/0) — outputs h264/aac
# 1080×1080, chime at the mark, silence elsewhere, GIF 720 px.
set -euo pipefail
ffmpeg()  { command ffmpeg  -hide_banner -loglevel error -stats "$@"; }
ffprobe() { command ffprobe -hide_banner "$@"; }
TAKE=${1:?take.mov}; OUT=${2:?outdir}; mkdir -p "$OUT"
CHIME="$(dirname "$0")/../../GlassKanban/CompletionChime.wav"

# ---- MARKS (seconds in the take, decimals allowed) ---------------------------
# Geometry: window size in points (from /tmp/window-id), pixels per point,
# and the recording margins used by record.sh. Crops are derived below.
WIN_W=1300; WIN_H=612; S=2; MX=${MX:-40}; MY=${MY:-130}
# Idea B — one move. HOVER = cursor rests on the card, DROP = card released,
# END = 2.5 s after the strike-through finished.
# Read off take1 (05.09.2026) with frames.sh: frames 39-47 identical = cursor
# resting on the card, frame 48 (12.00 s) = lift, frame 54 (13.50 s) = landed,
# frame 58 (14.50 s) = strike-through and settle finished.
B_HOVER=7.69; B_DROP=9.93; B_END=11.65
# Idea A — three moves. Ruhe phases get trimmed to the durations in konzept.md 3.2.
A_HOVER=3.0
A_M1_START=4.0;  A_M1_END=6.2      # move 1 incl. wiggle
A_M2_START=8.0;  A_M2_END=12.5     # move 2 incl. dialog (1.5 s) and return
A_M3_START=14.0; A_M3_END=16.5     # move 3 incl. strike-through
A_END=18.5
# Seconds from the DROP of the finishing move to the strike-through start
# (240 ms settle + spring). Chime is placed there.
CHIME_OFFSET=0.45
# -----------------------------------------------------------------------------

# Square crop (1:1): as tall as window + 2×40, right-aligned with 40 px of wallpaper.
SQ=$(( S*(WIN_H+80) ));  SQ_X=$(( S*(WIN_W+MX) + S*40 - SQ ));  SQ_Y=$(( S*(MY-40) ))
# Portrait crop (4:5): same width, 5/4 as tall, centred on the window.
P_W=$SQ; P_H=$(( SQ*5/4 )); P_X=$SQ_X; P_Y=$(( S*MY + S*WIN_H/2 - P_H/2 ))
[ $P_Y -ge 0 ] || { echo "recording too short for 4:5 — raise MY in record.sh"; exit 1; }
# BT.709 tags must be set inside the filter graph (setparams) — encoder-side
# -color_trc alone leaves the transfer tag at bt470m (measured 05.09.2026).
T709="setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv"
# FRAME=half (default): the right half of the board, as konzept.md 2.5 describes
# it — In Bearbeitung and Erledigt at reading size. FRAME=full: the whole window
# in frame. The recording is 1380 x 872 pt, so no 4:5 or 1:1 frame can hold the
# whole window against real wallpaper (that would need 1725 pt of height on a
# 1080 pt screen). FRAME=full therefore lays the window on a blurred, enlarged
# copy of the same wallpaper — no invented content, but the board is then 1080 px
# wide instead of 1384, i.e. every label is 44 % smaller than in FRAME=half.
FRAME=${FRAME:-half}
if [ "$FRAME" = "hero" ]; then
  # The frame follows the window: side margin SIDE_PT, top/bottom VERT_PT, so the
  # app dominates and the desktop only frames it. At 1:1 the vertical margin is
  # forced to 285 px by the window's own 2.12:1 shape — measured 05.09.2026,
  # desktop share 54.3 %. With SIDE=20 / VERT=70 pt it drops to 21.0 %.
  SIDE=${SIDE_PT:-20}; VERT=${VERT_PT:-70}
  HX=$(( S*(MX-SIDE) )); HY=$(( S*(MY-VERT) ))
  HW=$(( S*(WIN_W+2*SIDE) )); HH=$(( S*(WIN_H+2*VERT) ))
  OH=$(( (1080*HH/HW + 1)/2*2 ))
  VF_SQ="crop=${HW}:${HH}:${HX}:${HY},scale=1080:${OH}:flags=lanczos:out_color_matrix=bt709:out_range=tv,fps=30,format=yuv420p,$T709"
  VF_45="$VF_SQ"
  echo "frame — hero: crop ${HW}x${HH}+${HX}+${HY} → 1080x${OH}, desktop share $(( 100 - 100*WIN_W*WIN_H/(HW/S*HH/S) ))%"
elif [ "$FRAME" = "native" ]; then
  # The recording already has the right shape (record.sh MX/MY made it square),
  # so the cut only scales. No crop, no bed, no bands — the wallpaper in frame
  # is the real desktop.
  VF_SQ="scale=1080:1080:flags=lanczos:out_color_matrix=bt709:out_range=tv,fps=30,format=yuv420p,$T709"
  VF_45="$VF_SQ"
  echo "frame — native: whole recording scaled to 1080x1080, real wallpaper"
elif [ "$FRAME" = "full" ]; then
  # Trim the recording down to the window plus FULL_MARGIN pt, so the window
  # itself — not the recording margins — spans the full video width.
  FM=${FULL_MARGIN:-8}
  FX=$(( S*(MX-FM) )); FY=$(( S*(MY-FM) ))
  FW=$(( S*(WIN_W+2*FM) )); FH=$(( S*(WIN_H+2*FM) ))
  TIGHT="crop=${FW}:${FH}:${FX}:${FY}"
  bg() { echo "${TIGHT},split[bg][fg];[bg]scale=$1:$2:force_original_aspect_ratio=increase,crop=$1:$2,gblur=sigma=40[b];[fg]scale=$1:-2:flags=lanczos[f];[b][f]overlay=(W-w)/2:(H-h)/2:format=auto,format=yuv420p" ; }
  VF_SQ="$(bg 1080 1080),fps=30,$T709"
  VF_45="$(bg 1080 1350),fps=30,$T709"
  VF_169="$(bg 1080 640),fps=30,$T709"
  # FRAME=exact: the frame follows the window instead of the other way round —
  # crop to the window plus FULL_MARGIN pt and scale to 1080 wide, no bed, no
  # bands. Measured 05.09.2026: a 4:5 board would have to be 1220 x 1525 pt and
  # would need ~30 cards per column to not read as empty, which contradicts the
  # first design principle. So zero waste beats a nominally ideal ratio.
  EX_H=$(( (1080 * (WIN_H + 2*FM) / (WIN_W + 2*FM) + 1) / 2 * 2 ))
  VF_EX="${TIGHT},scale=1080:${EX_H}:flags=lanczos:out_color_matrix=bt709:out_range=tv,fps=30,format=yuv420p,$T709"
  echo "frame — full window, tight crop ${FW}x${FH}+${FX}+${FY} (margin ${FM} pt), on a blurred wallpaper bed"
else
VF_SQ="crop=${SQ}:${SQ}:${SQ_X}:${SQ_Y},scale=1080:1080:flags=lanczos:out_color_matrix=bt709:out_range=tv,fps=30,format=yuv420p,$T709"
VF_45="crop=${P_W}:${P_H}:${P_X}:${P_Y},scale=1080:1350:flags=lanczos:out_color_matrix=bt709:out_range=tv,fps=30,format=yuv420p,$T709"
echo "crops — 1:1 ${SQ}x${SQ}+${SQ_X}+${SQ_Y}   4:5 ${P_W}x${P_H}+${P_X}+${P_Y}"
fi
# LinkedIn re-encodes on upload: hand it clean BT.709 tags (no colour shift), a
# keyframe every second (clean first-frame thumbnail, clean loop start), High
# profile, 48 kHz AAC. Slightly generous CRF because text edges suffer most.
ENC=(-c:v libx264 -preset slow -profile:v high -level 4.0 -crf 17 -pix_fmt yuv420p -g 30 -keyint_min 30
     -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv
     -movflags +faststart -c:a aac -b:a 128k -ar 48000)

cut_all() {
  local VF=$1 TAG=$2
  # ---- Idea B: 7 s loop --------------------------------------------------------
  # 1. body clip
  ffmpeg -y -ss "$B_HOVER" -to "$B_END" -i "$TAKE" -vf "$VF" -an "$OUT/${TAG}_b_body.mp4"
  # 2. 1 s still of the first frame, for the loop crossfade back to the start
  ffmpeg -y -ss "$B_HOVER" -i "$TAKE" -vf "$VF" -frames:v 1 "$OUT/${TAG}_b_first.png"
  ffmpeg -y -loop 1 -t 1 -i "$OUT/${TAG}_b_first.png" -vf "fps=30,format=yuv420p,$T709" "$OUT/${TAG}_b_still.mp4"
  if [ "${LOOP_XFADE:-1}" = "0" ]; then
    # Hard-cut loop. The 0.6 s crossfade was the source of two defects measured
    # 05.09.2026: it double-exposed every row in Erledigt (two different card
    # lists dissolving into each other reads as a glitch, not a transition), and
    # its segment was BT.601-encoded but BT.709-decoded, so the wallpaper jumped
    # ~9 % in green at the seam — once per loop. A hard cut has neither.
    CHIME_AT_MS=$(echo "($B_DROP - $B_HOVER + $CHIME_OFFSET) * 1000" | bc | cut -d. -f1)
    ffmpeg -y -i "$OUT/${TAG}_b_body.mp4" -i "$CHIME" -f lavfi -i anullsrc=r=48000:cl=stereo \
      -filter_complex "[1:a]adelay=${CHIME_AT_MS}|${CHIME_AT_MS}[c];[2:a][c]amix=inputs=2:duration=first[a]" \
      -map 0:v -map "[a]" -shortest "${ENC[@]}" "$OUT/glass-kanban-one-move-${TAG}.mp4"
    cp "$OUT/${TAG}_b_first.png" "$OUT/glass-kanban-thumbnail-${TAG}.png"
    ffmpeg -y -i "$OUT/glass-kanban-one-move-${TAG}.mp4" -vf "fps=20,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5" \
      -loop 0 "$OUT/glass-kanban-one-move-${TAG}.gif"
    return 0
  fi
  # 3. crossfade body → still (0.6 s), chime at the strike-through
  BODY_LEN=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/${TAG}_b_body.mp4")
  XF_OFFSET=$(echo "$BODY_LEN - 0.6" | bc)
  CHIME_AT_MS=$(echo "($B_DROP - $B_HOVER + $CHIME_OFFSET) * 1000" | bc | cut -d. -f1)
  ffmpeg -y -i "$OUT/${TAG}_b_body.mp4" -i "$OUT/${TAG}_b_still.mp4" -i "$CHIME" -f lavfi -i anullsrc=r=48000:cl=stereo \
    -filter_complex "[0:v][1:v]xfade=transition=fade:duration=0.6:offset=${XF_OFFSET}[v];
                     [2:a]adelay=${CHIME_AT_MS}|${CHIME_AT_MS}[c];[3:a][c]amix=inputs=2:duration=first[a]" \
    -map "[v]" -map "[a]" -shortest "${ENC[@]}" "$OUT/glass-kanban-one-move-${TAG}.mp4"
  # Thumbnail for LinkedIn's custom-thumbnail field = the resting first frame
  cp "$OUT/${TAG}_b_first.png" "$OUT/glass-kanban-thumbnail-${TAG}.png"
  # 4. real GIF for README / messengers (not for LinkedIn)
  ffmpeg -y -i "$OUT/glass-kanban-one-move-${TAG}.mp4" -vf "fps=20,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5" \
    -loop 0 "$OUT/glass-kanban-one-move-${TAG}.gif"

  # ---- Idea A: 12 s, three moves ----------------------------------------------
  # CUT_A=0 skips it — Idea A needs "Als Nachstes" in frame, which the 692 pt
  # crop does not cover (see umsetzungsplan.md, Befund fuer Idee A).
  [ "${CUT_A:-1}" = "1" ] || return 0
  seg() { ffmpeg -y -ss "$1" -to "$2" -i "$TAKE" -vf "$VF" -an "$3"; }
  seg "$A_HOVER"      "$A_M1_START"  "$OUT/${TAG}_a0.mp4"   # rest, will be trimmed to 1 s below
  seg "$A_M1_START"   "$A_M1_END"    "$OUT/${TAG}_a1.mp4"
  seg "$A_M2_START"   "$A_M2_END"    "$OUT/${TAG}_a2.mp4"
  seg "$A_M3_START"   "$A_END"       "$OUT/${TAG}_a3.mp4"
  ffmpeg -y -i "$OUT/${TAG}_a0.mp4" -t 1 -c copy "$OUT/${TAG}_a0t.mp4"
  # 1 s rest between moves = freeze the last frame of the previous segment
  ffmpeg -y -sseof -0.04 -i "$OUT/${TAG}_a1.mp4" -frames:v 1 "$OUT/${TAG}_a1_last.png"
  ffmpeg -y -loop 1 -t 1 -i "$OUT/${TAG}_a1_last.png" -vf "fps=30,format=yuv420p,$T709" "$OUT/${TAG}_a1_rest.mp4"
  ffmpeg -y -sseof -0.04 -i "$OUT/${TAG}_a2.mp4" -frames:v 1 "$OUT/${TAG}_a2_last.png"
  ffmpeg -y -loop 1 -t 1 -i "$OUT/${TAG}_a2_last.png" -vf "fps=30,format=yuv420p,$T709" "$OUT/${TAG}_a2_rest.mp4"
  printf "file '${TAG}_a0t.mp4'\nfile '${TAG}_a1.mp4'\nfile '${TAG}_a1_rest.mp4'\nfile '${TAG}_a2.mp4'\nfile '${TAG}_a2_rest.mp4'\nfile '${TAG}_a3.mp4'\n" > "$OUT/${TAG}_a_list.txt"
  ffmpeg -y -f concat -safe 0 -i "$OUT/${TAG}_a_list.txt" -c copy "$OUT/${TAG}_a_silent.mp4"
  # chime: 1 s + len(a1) + 1 s + len(a2) + 1 s + (drop offset inside a3 = 0 s) + CHIME_OFFSET
  L1=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/${TAG}_a1.mp4")
  L2=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/${TAG}_a2.mp4")
  A_CHIME_MS=$(echo "(3 + $L1 + $L2 + $CHIME_OFFSET) * 1000" | bc | cut -d. -f1)
  ffmpeg -y -i "$OUT/${TAG}_a_silent.mp4" -i "$CHIME" -f lavfi -i anullsrc=r=48000:cl=stereo \
    -filter_complex "[1:a]adelay=${A_CHIME_MS}|${A_CHIME_MS}[c];[2:a][c]amix=inputs=2:duration=first[a]" \
    -map 0:v -map "[a]" -shortest "${ENC[@]}" "$OUT/glass-kanban-three-moves-${TAG}.mp4"

}

if [ "$FRAME" = "native" ]; then cut_all "$VF_SQ" 1x1; else
cut_all "$VF_45" 4x5
cut_all "$VF_SQ" 1x1
fi
# 16:9 only exists to show how little dead space a short format leaves; the
# window spans the full width in every ratio, so this does not enlarge the app.
[ "${FRAME:-half}" = "full" ] && [ "${CUT_169:-0}" = "1" ] && cut_all "$VF_169" 16x9
[ "${FRAME:-half}" = "full" ] && [ "${CUT_EXACT:-0}" = "1" ] && { echo "exact fit — 1080x${EX_H}, window edge to edge"; cut_all "$VF_EX" exact; }

echo "done:"; ls -la "$OUT"/glass-kanban-*
