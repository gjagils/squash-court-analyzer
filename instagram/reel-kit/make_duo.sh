#!/bin/bash
# Builds a 1080x1920 reel with two phones side by side (left: referee, right:
# coach), the "duo" layer of reel.html, captions per moment, intro and outro.
# Usage: make_duo.sh <name> <left.mp4> <right.mp4> "<t0 t1 ...>" <out.mp4>
# Both clips are used from the start at speed 1 (cut them first with cut_clip.sh);
# the last caption time is where the outro starts. Dark theme only.
set -euo pipefail
NAME=$1; L=$2; R=$3; read -r -a T <<< "$4"; OUT=$5
KIT=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot() { "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
  --default-background-color=00000000 --window-size=$2 --virtual-time-budget=2000 --screenshot="$TMP/$1.png" "file://$KIT/reel.html#$3" >/dev/null 2>&1; }
shot base 1080,1920 duo; shot mask 414,900 dmask
N=$(( ${#T[@]} - 1 )); DUR=${T[$N]}
for ((i=0;i<N;i++)); do shot cap$i 1080,1920 "cap=$NAME:$i"; done
X1=0.25; X2=0.35
INTRO=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$KIT/intro.mp4")
ARGS=(-loop 1 -t "$DUR" -i "$TMP/base.png" -i "$L" -i "$R" -loop 1 -t "$DUR" -i "$TMP/mask.png")
for ((i=0;i<N;i++)); do ARGS+=(-loop 1 -t "$DUR" -i "$TMP/cap$i.png"); done
ARGS+=(-i "$KIT/intro.mp4" -i "$KIT/outro.mp4")
F="[3:v]scale=414:900,format=gray,split[m1][m2];"
F+="[1:v]fps=30,tpad=stop_mode=clone:stop_duration=$DUR,scale=414:900,format=rgba[l];[l][m1]alphamerge[lm];"
F+="[2:v]fps=30,tpad=stop_mode=clone:stop_duration=$DUR,scale=414:900,format=rgba[r];[r][m2]alphamerge[rm];"
F+="[0:v]fps=30[bg];[bg][lm]overlay=87:703[b1];[b1][rm]overlay=579:703[s0];"
for ((i=0;i<N;i++)); do
  F+="[s$i][$((i+4)):v]overlay=0:0:enable='between(t,${T[$i]},${T[$((i+1))]})'[s$((i+1))];"
done
F+="[s$N]trim=0:$DUR,setpts=PTS-STARTPTS,format=yuv420p,settb=1/30[main];"
F+="[$((N+4)):v]fps=30,format=yuv420p,settb=1/30[intro];[$((N+5)):v]fps=30,format=yuv420p,settb=1/30[outro];"
O1=$(awk "BEGIN{print $INTRO-$X1}"); O2=$(awk "BEGIN{print $INTRO-$X1+$DUR-$X2}")
F+="[intro][main]xfade=transition=fade:duration=$X1:offset=$O1[im];[im][outro]xfade=transition=fade:duration=$X2:offset=$O2[out]"
ffmpeg -v error -y "${ARGS[@]}" -filter_complex "$F" -map "[out]" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$OUT"
