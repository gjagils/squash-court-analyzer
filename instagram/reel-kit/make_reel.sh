#!/bin/bash
# Builds a 1080x1920 reel: the app recording in a phone frame, a caption per
# moment, and an end card. Usage:
#   make_reel.sh <name> <recording.mp4> <trim-end-s> <speed> "<t0 t1 t2 ...>" <out.mp4>
# The caption times are in output seconds: caption n shows from t(n) to t(n+1);
# the last time is where the end card (3 s) starts. Captions live in reel.html (CAPS).
# PAD=<s> holds the last frame of the recording that long (before the speed-up).
set -euo pipefail
NAME=$1; REC=$2; TRIM=$3; SPEED=$4; read -r -a T <<< "$5"; OUT=$6
KIT=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot() { "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
  --default-background-color=00000000 --window-size=$2 --virtual-time-budget=2000 --screenshot="$TMP/$1.png" "file://$KIT/reel.html#$3" >/dev/null 2>&1; }
shot base 1080,1920 base; shot end 1080,1920 end; shot mask 532,1156 mask
N=$(( ${#T[@]} - 1 ))
for ((i=0;i<N;i++)); do shot cap$i 1080,1920 "cap=$NAME:$i"; done
DUR=${T[$N]}
ARGS=(-loop 1 -t "$DUR" -i "$TMP/base.png" -i "$REC" -loop 1 -t "$DUR" -i "$TMP/mask.png")
for ((i=0;i<N;i++)); do ARGS+=(-loop 1 -t "$DUR" -i "$TMP/cap$i.png"); done
ARGS+=(-loop 1 -t 3 -i "$TMP/end.png")
F="[1:v]trim=0:$TRIM,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=${PAD:-0},setpts=PTS/$SPEED,fps=30,scale=532:1156,format=rgba[v];"
F+="[2:v]scale=532:1156,format=gray[m];[v][m]alphamerge[vm];"
F+="[0:v]fps=30[bg];[bg][vm]overlay=275:597:eof_action=repeat[s0];"
for ((i=0;i<N;i++)); do
  F+="[s$i][$((i+3)):v]overlay=0:0:enable='between(t,${T[$i]},${T[$((i+1))]})'[s$((i+1))];"
done
F+="[s$N]trim=0:$DUR,setpts=PTS-STARTPTS,format=yuv420p[main];"
F+="[$((N+3)):v]fps=30,format=yuv420p,fade=t=in:st=0:d=0.4[endc];[main][endc]concat=n=2:v=1:a=0[out]"
ffmpeg -v error -y "${ARGS[@]}" -filter_complex "$F" -map "[out]" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$OUT"
