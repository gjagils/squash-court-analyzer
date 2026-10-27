#!/bin/bash
# Builds a 1080x1920 reel: the logo intro, the app recording in a phone frame
# with a caption per moment, and the download outro. Usage:
#   make_reel.sh <name> <recording.mp4> <trim-end-s> <speed> "<t0 t1 t2 ...>" <out.mp4>
# The caption times are in seconds of the recording part (after the speed-up):
# caption n shows from t(n) to t(n+1); the last time is where the outro starts.
# Captions live in reel.html (CAPS); intro.mp4 and outro.mp4 come from make_stings.sh.
# PAD=<s> holds the last frame of the recording that long (before the speed-up).
# LIGHT=1 uses the light frame, captions, intro and outro (record the app in light too).
# SWITCH=<s> starts light and turns dark at that second (light intro, dark outro),
# for a recording in which the app itself switches from light to dark.
set -euo pipefail
NAME=$1; REC=$2; TRIM=$3; SPEED=$4; read -r -a T <<< "$5"; OUT=$6
KIT=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SW=${SWITCH:-}
shot() { # <file> <size> <hash> [light]
  local q=""; [ "${4:-}" = light ] && q="?light"
  "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --default-background-color=00000000 --window-size=$2 --virtual-time-budget=2000 --screenshot="$TMP/$1.png" "file://$KIT/reel.html$q#$3" >/dev/null 2>&1
}
N=$(( ${#T[@]} - 1 ))
DUR=${T[$N]}
if [ -n "$SW" ]; then
  # Before the switch: light; after: dark
  shot base 1080,1920 base; shot base-l 1080,1920 base light
  for ((i=0;i<N;i++)); do
    if awk "BEGIN{exit !(${T[$i]} < $SW)}"; then shot cap$i 1080,1920 "cap=$NAME:$i" light; else shot cap$i 1080,1920 "cap=$NAME:$i"; fi
  done
  IN="intro-licht"; OUTRO="outro"
elif [ "${LIGHT:-}" = 1 ]; then
  shot base 1080,1920 base light
  for ((i=0;i<N;i++)); do shot cap$i 1080,1920 "cap=$NAME:$i" light; done
  IN="intro-licht"; OUTRO="outro-licht"
else
  shot base 1080,1920 base
  for ((i=0;i<N;i++)); do shot cap$i 1080,1920 "cap=$NAME:$i"; done
  IN="intro"; OUTRO="outro"
fi
shot mask 532,1156 mask
# Cross-fades: intro -> recording 0.25 s, recording -> outro 0.35 s
X1=0.25; X2=0.35
INTRO=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$KIT/$IN.mp4")
ARGS=(-loop 1 -t "$DUR" -i "$TMP/base.png" -i "$REC" -loop 1 -t "$DUR" -i "$TMP/mask.png")
for ((i=0;i<N;i++)); do ARGS+=(-loop 1 -t "$DUR" -i "$TMP/cap$i.png"); done
ARGS+=(-i "$KIT/$IN.mp4" -i "$KIT/$OUTRO.mp4")
F="[1:v]trim=0:$TRIM,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=${PAD:-0},setpts=PTS/$SPEED,fps=30,scale=532:1156,format=rgba[v];"
F+="[2:v]scale=532:1156,format=gray[m];[v][m]alphamerge[vm];"
if [ -n "$SW" ]; then
  ARGS+=(-loop 1 -t "$DUR" -i "$TMP/base-l.png")
  F+="[0:v]fps=30[bgd];[bgd][$((N+5)):v]overlay=0:0:enable='lt(t,$SW)'[bg];"
else
  F+="[0:v]fps=30[bg];"
fi
F+="[bg][vm]overlay=275:597:eof_action=repeat[s0];"
for ((i=0;i<N;i++)); do
  F+="[s$i][$((i+3)):v]overlay=0:0:enable='between(t,${T[$i]},${T[$((i+1))]})'[s$((i+1))];"
done
F+="[s$N]trim=0:$DUR,setpts=PTS-STARTPTS,format=yuv420p,settb=1/30[main];"
F+="[$((N+3)):v]fps=30,format=yuv420p,settb=1/30[intro];[$((N+4)):v]fps=30,format=yuv420p,settb=1/30[outro];"
O1=$(awk "BEGIN{print $INTRO-$X1}"); O2=$(awk "BEGIN{print $INTRO-$X1+$DUR-$X2}")
F+="[intro][main]xfade=transition=fade:duration=$X1:offset=$O1[im];[im][outro]xfade=transition=fade:duration=$X2:offset=$O2[out]"
ffmpeg -v error -y "${ARGS[@]}" -filter_complex "$F" -map "[out]" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$OUT"
