#!/bin/bash
# Renders the release 3.2 carousel (slide-1..7) and the story (story-1..7) from
# carousel-kit/carousel.html (#release32). Screens in assets/: 3.2 (4) on the
# iPhone 17 Pro Max simulator, 9 November 2026, sample names only.
cd "$(dirname "$0")"
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
K="file://$(cd ../carousel-kit && pwd)/carousel.html"
for i in 1 2 3 4 5 6 7; do
  "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --window-size=1080,1350 --virtual-time-budget=3000 --screenshot="$PWD/slide-$i.png" "$K#release32:$i" 2>/dev/null
  "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files \
    --window-size=1080,1920 --virtual-time-budget=3000 --screenshot="$PWD/story-$i.png" "$K#release32:$i:story" 2>/dev/null
done
