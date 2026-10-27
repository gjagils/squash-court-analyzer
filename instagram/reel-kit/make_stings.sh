#!/bin/bash
# Renders the reel intro (logo, 1.2 s) and outro (download card, 3 s) from
# sting.html, frame by frame at 30 fps, into intro.mp4 and outro.mp4 next to
# this script. make_reel.sh puts them before and after every reel.
# LIGHT=1 renders the light versions (intro-licht.mp4, outro-licht.mp4).
set -euo pipefail
KIT=$(cd "$(dirname "$0")" && pwd); TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
Q=""; SUF=""
if [ "${LIGHT:-}" = 1 ]; then Q="?light"; SUF="-licht"; fi
render() { # <kind> <seconds>
  local n i t
  n=$(awk "BEGIN{print int($2*30)}")
  for ((i=0;i<n;i++)); do
    t=$(awk "BEGIN{printf \"%.4f\", $i/30}")
    "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
      --window-size=1080,1920 --virtual-time-budget=500 --screenshot="$TMP/$1-$(printf %03d $i).png" \
      "file://$KIT/sting.html$Q#$1:$t" >/dev/null 2>&1
  done
  ffmpeg -v error -y -framerate 30 -i "$TMP/$1-%03d.png" -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p "$KIT/$1$SUF.mp4"
}
render intro 1.2
render outro 3
