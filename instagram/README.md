# Instagram (@squashanalyzer)

Posts voor het Instagram-account, per post een map met de bron en de beelden.

- `planning.md`: de planning met onderschriften voor de komende posts.
- `release-3.0/`: releasepost van 25 oktober 2026 (carousel van 9 slides).
  - `slides.html`: de bron, in de huisstijl van de website. `#3` toont slide 3
    als post (1080×1350), `#3s` als verhaal (1080×1920).
  - `png/`: de 9 slides voor de post, `story/`: dezelfde 9 als verhaal.
  - `assets/`: de screenshots, het icoon en de badges die de slides gebruiken.
    `lockscreen.png` komt uit de simulator met `-LiveActivityDemo gameball`.

Opnieuw renderen (vanuit de map van de post):

```bash
for i in 1 2 3 4 5 6 7 8 9; do "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files --window-size=1080,1350 --virtual-time-budget=3000 --screenshot="$PWD/png/slide-$i.png" "file://$PWD/slides.html#$i"; done
```

Voor het verhaal: `--window-size=1080,1920`, `story/story-$i.png` en `#${i}s`.
