#!/bin/bash
# Joins pieces of simulator recordings, each at its own speed, into one clip.
# Usage: cut_clip.sh <out.mp4> "<file> <start> <end> <speed>" ...
# The result goes to make_reel.sh with speed 1, so caption times are in its seconds.
set -euo pipefail
OUT=$1; shift
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
i=0
for seg in "$@"; do
  read -r f a b s <<< "$seg"
  ffmpeg -v error -y -ss "$a" -to "$b" -i "$f" -vf "setpts=(PTS-STARTPTS)/$s,fps=30,scale=1320:2868" \
    -c:v libx264 -crf 14 -preset fast -an "$TMP/s$i.mp4"
  echo "file '$TMP/s$i.mp4'" >> "$TMP/list.txt"
  echo "piece $i: $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMP/s$i.mp4") s"
  i=$((i+1))
done
ffmpeg -v error -y -f concat -safe 0 -i "$TMP/list.txt" -c copy "$OUT"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT"
