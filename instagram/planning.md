# Instagram-planning @squashanalyzer

Twee posts per week, dinsdag en zaterdag. Posten in de app (reels kunnen niet
via de website gepland worden); per post staan hier het bestand, het
onderschrift, de eerste reactie en een tip.

Hashtags: Instagram telt er maximaal 5 per post, zet ze onderaan het onderschrift.

| Datum | Soort | Bestand |
|---|---|---|
| zo 25 okt | Carousel, release 3.0 (geplaatst) | `release-3.0/png/` |
| za 31 okt | Reel, scheidsen | `reel-scheidsen/reel-scheidsen.mp4` |
| di 3 nov | Carousel, Coachkaart | `carousel-coachkaart/slide-1..7.png` |
| za 7 nov | Reel, live-stand op het vergrendelscherm | `reel-live/reel-live.mp4` |
| di 10 nov | Carousel, 5 dingen voor de scheids | `carousel-scheids5/slide-1..7.png` |
| za 14 nov | Reel, coachen en Analyse | `reel-coachen/reel-coachen.mp4` |

## za 31 okt · Reel: scheidsen

```
Welk vak serveert ze nu ook alweer? 🤔

Met Squash Analyzer tik je alleen op wie het punt wint. Servicevak, let, stroke en de stand per game houdt de app bij.

Gratis voor iPhone en Android, link in de bio.

#squash #squashnederland #squashreferee #squashscheidsrechter #squashapp
```

Eerste reactie: `Wat vind jij het lastigst als scheids: het servicevak of let en stroke? 👇`
Omslag: het eerste beeld (de vraag staat er al in).

## di 3 nov · Carousel: Coachkaart

```
Je speler verliest game 1. Wat zeg je in de pauze?

De Coachkaart laat per vak zien wie waar wint, met drie coachpunten en wat er beter ging dan in de vorige game.

Swipe voor hoe het werkt 👉

#squash #squashcoach #squashcoaching #squashtraining #squashnederland
```

Eerste reactie: `Coaches: wat zeg jij als eerste tussen twee games? 👇`

## za 7 nov · Reel: live-stand op het vergrendelscherm

```
Telefoon even weggelegd? De stand staat gewoon op je vergrendelscherm 🔒

Tik als scheids door: elke rally komt meteen in beeld. Deel de link en je team volgt mee, in de browser of op hun eigen vergrendelscherm.

#squash #squashnederland #squashcompetitie #squashteam #squashapp
```

Eerste reactie: `Wie uit je team moet dit zien? Tag ze 👇`

## di 10 nov · Carousel: 5 dingen voor de scheids

```
5 dingen die je als scheids niet meer hoeft te onthouden ✅

Wie serveert, uit welk vak, wie elke rally won, de stand in games en hoe lang het al duurt. Jij let op de rally.

Bewaar deze post voor je volgende wedstrijd.

#squash #squashreferee #squashscheidsrechter #squashnederland #squashlife
```

Eerste reactie: `Welke vergeet jij het vaakst, 1 tot en met 5? 👇`

## za 14 nov · Reel: coachen en Analyse

```
‘Speel meer lengte’ is geen coachadvies 🎯

Leg per rally vast wie scoort, hoe, waar en met welke slag. Na de game zie je de heatmap en het tactisch advies, tussen de games laat je de Coachkaart zien.

#squash #squashcoach #squashcoaching #squashtraining #squashapp
```

Eerste reactie: `Coach jij op gevoel of op cijfers? 👇`

## Opnieuw maken

- Reels: `reel-kit/make_reel.sh` (zie de uitleg bovenin het script); de teksten
  per moment staan in `reel-kit/reel.html`. De ruwe simulatoropnames staan in
  `video-raw/` (buiten git, te groot).
- Carousels: `carousel-kit/carousel.html#<naam>:<slide>`, gerenderd met headless
  Chrome op 1080×1350, net als `release-3.0` (zie `README.md`).
- Opnames maken: simulator iPhone 17 Pro Max, `xcrun simctl io booted recordVideo`.
  Tik rustig, één tik per keer, anders zie je de stappen niet. Het vergrendelscherm
  toont de eigen wedstrijd zodra je vergrendelt; ontgrendelen met een veeg omhoog.
