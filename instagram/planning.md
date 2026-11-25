# Instagram-planning @squashanalyzer

Op 23 november 2026 is de planning leeggemaakt (Gerd-Jan: alles mag weg); de reels van
vóór 4.0 zijn vervallen en hun geplande taken verwijderd. Eerder was het twee posts per week, dinsdag en zaterdag. Posten in de app (reels kunnen niet
via de website gepland worden); per post staan hier het bestand, het
onderschrift, de eerste reactie en een tip.

Hashtags: Instagram telt er maximaal 5 per post, zet ze onderaan het onderschrift.

| Datum | Soort | Bestand |
|---|---|---|
| zo 25 okt | Carousel, release 3.0 (geplaatst) | `release-3.0/png/` |
| di 27 okt | Carousel, Competitie-vrijdag (geplaatst, verhaal in de app) | `competitie-vrijdag/slide-1..3.png`, `story-1..3.png` |
| vr 30 okt | Carousel, je teamgenoot coachen (geplaatst, verhaal in de app) | `teamcoach/slide-1..5.png`, `story-1..5.png` |
| di 3 nov | Carousel, Coachkaart (geplaatst) | `carousel-coachkaart/slide-1..7.png` |
| ma 9 nov | Carousel, release 3.2 (geplaatst, verhaal in de app) | `release-3.2/slide-1..7.png`, `story-1..7.png` |
| 25 nov 2026, geplaatst | Reel, 3 hoogtepunten van 4.0 (account, vanzelf in je app, meedoen) | `reel-release40/reel-release40.mp4` |

## di 27 okt · Carousel: Competitie-vrijdag (geplaatst)

```
Vrijdag competitie? 🏆

Geen papiertje of discussie over de stand: met Squash Analyzer tel je de wedstrijd op je telefoon. Jij tikt wie het punt wint, de app houdt serve, vak en stand bij.

Download hem nu, dan sta je vrijdag klaar. Gratis voor iPhone en Android, link in de bio.

#squash #squashnederland #squashcompetitie #squashlife #squashapp
```

Eerste reactie: `Op welke avond speel jij competitie? 👇`
Verhaal (in de app): `story-1..3.png`, op slide 1 een linksticker "Download de app" naar squashanalyzer.com op de plek van de oranje tekst onderin. Leuk als vaste vrijdagstory, met een poll "Speel jij vanavond?".

## vr 30 okt · Carousel: je teamgenoot coachen (geplaatst)

```
Je teamgenoot helpen winnen? 💪

Sta je langs de baan bij een competitiewedstrijd? Coach dan met Squash Analyzer. Tik per rally waar het punt viel, en in de pauze heb je de coachkaart: drie concrete punten en wat er al beter gaat.

Gratis voor iPhone en Android, link in de bio.

#squash #squashnederland #squashcompetitie #squashcoach #squashapp
```

Eerste reactie: `Wie is jouw vaste coach langs de baan? Tag ze 👇`
Verhaal (in de app): `story-1..5.png`, linksticker op de oranje tekst onderin.

## di 3 nov · Carousel: Coachkaart

```
Je speler verliest game 1. Wat zeg je in de pauze?

De Coachkaart laat per vak zien wie waar wint, met drie coachpunten en wat er beter ging dan in de vorige game.

Swipe voor hoe het werkt 👉

#squash #squashcoach #squashcoaching #squashtraining #squashnederland
```

Eerste reactie: `Coaches: wat zeg jij als eerste tussen twee games? 👇`

## ma 9 nov · Carousel: release 3.2 (geplaatst)

3.2 staat sinds 8 november in de App Store en Google Play. De schermen komen uit 3.2 (4) op de
simulator, met voorbeeldnamen (Gerard, Thijs, Sanne, Mila); alleen de teamnamen op slide 2
(All Inn Squash 7, Squash Utrecht 10) zijn echt, uit de SBN-stand. Opnieuw renderen: `release-3.2/render.sh`.

```
Squash Analyzer 3.2 is er 🎉

🏆 Je teamwedstrijd op je beginscherm, met de stand en E1 t/m E4
⏱️ Officiële timers voor de scheids: inspelen, start en pauze, en je telefoon trilt
👀 Niet gezien bij het coachen: de score loopt gewoon door
📊 Ken je tegenstander: de onderlinge stand bij Kies speler

En sinds 3.1: Mijn team zonder link, eenvoudig coachen en de oefenpartij.

Update in de App Store of Google Play, of download hem gratis via de link in de bio.

#squash #squashnederland #squashcompetitie #squashcoach #squashapp
```

Eerste reactie: `Welke probeer jij als eerste? 👇`
Verhaal (in de app): `story-1..7.png`, op slide 7 een linksticker "Download de app" naar squashanalyzer.com op de oranje tekst onderin.

## Reel: 3 hoogtepunten van 4.0 (geplaatst 25 november 2026, eerste reactie nog niet)

4.0 staat sinds 23 november 2026 in de App Store en Google Play. De reel (25 s) toont,
op aanwijzing van Gerd-Jan (24 november): 1) een account maken, niet verplicht maar de
grootste verandering; 2) met een account komen je wedstrijden vanzelf in je app (de
teamwedstrijd) en eindelijk je eigen badges; 3) makkelijker meedoen aan een teamwedstrijd (titel: "Meedoen aan een teamwedstrijd is makkelijker")
als scheidsrechter en coach (de vraag "Tel je een partij van deze teamwedstrijd? Tik op de
partij" en de spelers staan al ingevuld). Opgenomen op iPhone 17 Pro Max met de schermen uit
`-screenshot team-match` (die slaat de teamwedstrijd nu ook op, zodat de setup de vraag stelt)
en `-screenshot home`. De teamstand op het vergrendelscherm is niet te simuleren zonder echte
pushmeldingen, die zit er dus niet in.

```
4.0 is er 🏆

Maak een account (niet verplicht, wel de grootste verandering) en je wedstrijden komen vanzelf in je app, met de teamstand op je vergrendelscherm. Eindelijk je eigen badges!

En meedoen aan een teamwedstrijd als scheidsrechter of coach gaat nu met één tik op de partij.

Gratis voor iPhone en Android, link in de bio.

#squash #squashnederland #squashcompetitie #squashteam #squashapp
```

Eerste reactie: `Welke badge wil jij als eerste? Teamspeler of Matchwinnaar? 👇`

## Opnieuw maken

- Reels: `reel-kit/make_reel.sh` (zie de uitleg bovenin het script); de teksten
  per moment staan in `reel-kit/reel.html`. Elke reel begint met de logo-intro en
  eindigt met de download-outro (`intro.mp4`, `outro.mp4`, gemaakt met
  `make_stings.sh` uit `sting.html`). Stukken uit opnames, elk met een eigen
  snelheid, plak je aan elkaar met `cut_clip.sh`. De ruwe simulatoropnames staan
  in `video-raw/` (buiten git, te groot).
- De gebruikte knippen: scheidsen = `referee.mp4` 0.5–10 (1,8×), 13,4–15,6 en
  23,4–25,8 (let, stroke), 29,4–33,8 (1,6×, undo) + `vak-vastzetten.mp4` 12,3–15,3
  en 25,2–28,2; live = `lockscreen.mp4` 0–11 (1,3×), 11–25,5 (2,2×), 25,5–37,5 (1,3×);
  coachen = `coach-cut.mp4` op 1,7×.
- Licht: `LIGHT=1 make_reel.sh …` (lichte intro, outro, kader en teksten).
  `SWITCH=<s>` begint licht en wordt donker op die seconde (Team Licht/Donker).
  Twee telefoons naast elkaar: `make_duo.sh` (Team Scheids/Coach).
- Stilstaande stukken in een opname worden te lang geknipt, omdat de simulator
  dan weinig beelden schrijft. Zet zo'n opname eerst om naar vaste 30 fps
  (`ffmpeg -i x.mp4 -vf fps=30 x-cfr.mp4`) en knip dan.
- Simulator: blijft het scherm na ontgrendelen gedimd, herstart de simulator.
- Carousels: `carousel-kit/carousel.html#<naam>:<slide>`, gerenderd met headless
  Chrome op 1080×1350, net als `release-3.0` (zie `README.md`).
- Opnames maken: simulator iPhone 17 Pro Max, `xcrun simctl io booted recordVideo`.
  Tik rustig, één tik per keer, anders zie je de stappen niet. Het vergrendelscherm
  toont de eigen wedstrijd zodra je vergrendelt; ontgrendelen met een veeg omhoog.
