#!/bin/bash
# Renders the Competitie-vrijdag carousel (slide-1..3) and the story (story-1..3).
cd "$(dirname "$0")"
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
K="file://$(cd ../carousel-kit && pwd)/carousel.html"
for i in 1 2 3; do
  "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --window-size=1080,1350 --virtual-time-budget=3000 --screenshot="$PWD/slide-$i.png" "$K#competitie:$i" 2>/dev/null
  "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --window-size=1080,1920 --virtual-time-budget=3000 --screenshot="$PWD/story-$i.png" "$K#competitie:$i:story" 2>/dev/null
done
