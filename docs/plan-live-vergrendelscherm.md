# Live score op het vergrendelscherm (branch `feature/live-activity`)

**Status 15–16 oktober 2026.** Gebouwd en getest op de branch
`feature/live-activity`, buiten `main` (feature freeze). Gerd-Jan test het eerst
en beslist daarna of het als bonus in 3.0 meegaat. Niets is geüpload; de
productie-Worker (`squash-live-beta`) is niet veranderd.

## Wat het doet

Vooral voor wie **niet** bij de wedstrijd is. De scorer deelt zoals altijd de
live link in de groep. Een toeschouwer met de app opent die link (knop "Volg
op je vergrendelscherm" op de kijkpagina, of plakken in **Wedstrijd volgen** op
het beginscherm) en krijgt de stand op het vergrendelscherm. Na elke rally
stuurt de live-server een push, dus de app hoeft niet open te staan.

- **iPhone**: Live Activity op het vergrendelscherm en in het Dynamic Island
  (compact, minimaal, uitgeklapt), in de stijl van de live-ticker met
  spelersfoto's (zie hieronder). Badges GAMEBAL en MATCHBAL; pauze en uitslag
  staan in de statusregel.
  De uitslag blijft na afloop staan (tot 4 uur, iOS-grens).
- **Android 16+**: Live Update: chip met de stand in de statusbalk, uitgelichte
  melding met een balk per game in de kleur van de winnaar, knop Stoppen. Als
  groot pictogram beide avatars (foto of beginletter) schuin over elkaar.
- **Android 9–15**: doorlopende melding in de stijl van de liveticker op de
  kijkpagina (`live.html`). Uitgeklapt: oranje statusregel ("GAME 3 · BEST OF
  5", "PAUZE · GAME 3 BEGINT ZO", "GERD-JAN WINT 3–1"), per speler een ronde
  avatar met ring in de spelerskleur, de naam (met beker voor de winnaar),
  "serveert rechts" met stip bij de serveerder, de games in een vakje en de
  punten; daaronder de gespeelde games als chips in de kleur van de winnaar
  (meer dan vier: twee rijen) en de laatste rally. Ingeklapt twee rijen met
  stip, naam, games en punten. Kleuren in `res/values(-night)/live_colors.xml`:
  licht de "Warm licht"-kleuren, donker die van de kijkpagina.
- **Eigen wedstrijd (alleen iPhone)**: wie zelf scoort, ziet de eigen stand ook
  op het vergrendelscherm (lokaal bijgewerkt, zonder push). Instelling "Stand op
  vergrendelscherm", standaard aan. Op Android is dit nog niet gebouwd.

Ontwerp: het canvas "Live score op vergrendelscherm" (claude.ai-artifact).

### iPhone: zelfde uiterlijk als de live-ticker (16 oktober 2026)

Op verzoek van Gerd-Jan lijkt de Live Activity nu op de ticker van de kijkpagina
(`server/live-worker/public/live.html`), branch `feature/live-activity-ticker-ios`:

- Per speler een ronde foto (of de eerste letter in een cirkel) met een rand in
  de spelerskleur (speler 1 oranje, speler 2 staalblauw), de naam in die kleur,
  daaronder "serveert rechts/links" met een stipje (alleen bij de serveerder),
  de gewonnen games als getal in een omrand vakje en de punten groot.
- Erboven een rode LIVE-pil (AFGELOPEN, grijs, na afloop) en de statusregel in
  oranje hoofdletters ("GAME 3 · BEST OF 5", "PAUZE", "ANNA WINT 3-1");
  GAMEBAL/MATCHBAL als gouden badge rechts. Eronder de gespeelde games als
  chips in de kleur van de winnaar ("11-7" oranje, "8-11" blauw), bij de eigen
  wedstrijd met de wedstrijdtijd rechts.
- De punten zijn, net als op de website, de stand van de lopende game (in de
  pauze dus 0-0, na afloop de laatste game). Compact Dynamic Island: kleine
  foto's met de punten, in de pauze en na afloop de games.
- Hoogte: de kaart is ongeveer 153 pt (iOS knipt rond 160 pt af), getest met
  vier gamechips.

**Foto's via een App Group.** Een push kan geen afbeelding bevatten. Daarom zet
de app de foto's klein (96 px, JPEG) in de App Group `group.com.squashanalyzer.app`
(`live-photos/<matchId>-1.jpg` en `-2.jpg`, `LiveScorePhotoStore` in
`Shared/LiveScoreAttributes.swift`); de extensie leest ze daar. Bij het volgen
haalt de app `GET /api/live/:id/photo/1` en `/2` op (maximaal 3 seconden
wachten; anders eerst letters en de foto's bij de volgende rally). Bij de eigen
wedstrijd geven het scheidsrechters- en coachscherm de opgeslagen foto's mee
via `LiveShareSync.send(…, photos:)` (hook `localActivityPhotos`, op Android
nil). Opruimen: bij Stoppen, bij wegvegen van een lopende wedstrijd, bij het
sluiten van de eigen wedstrijd en bij elke start van de app of een nieuwe
volg-actie (alles zonder Live Activity gaat weg). Beide targets hebben de
entitlement `com.apple.security.application-groups`
(`SquashLiveActivity/SquashLiveActivity.entitlements` is nieuw).

### Teamwedstrijd op de iPhone (16 oktober 2026)

Branch `feature/live-activity-team-ios`. Een teamlink (`squashanalyzer://volg#team/<id>`,
knop op de teampagina, of `https://…/t/<id>` plakken) geeft een tweede Live Activity
(`TeamScoreAttributes` in `Shared/TeamScoreAttributes.swift`, widget
`SquashLiveActivity/TeamScoreActivityWidget.swift`). De content-state is precies de
teampush van de server (`{home, away, partijen}`).

- Kaart: LIVE-pil, "COMPETITIE" en "2 van 4 klaar"; daaronder de teamregel (thuisteam
  oranje links, de games van beide teams in het midden, uitteam blauw rechts) en vier
  rijen E1–E4: foto of letter, voornaam, games per speler, in het midden "● 7–5"
  (rood, partij bezig), "klaar" of "–". Het vakje van de winnaar krijgt zijn kleur;
  een slot zonder partij staat grijs als "Delft 8 E3". Teamscore en rijmiddens staan
  op dezelfde middenlijn. Alle vier klaar: grijze pil AFGELOPEN en "Uitslag: All Inn 8
  wint 9–8" (partijen, dan volledige opstelling, dan games, dan E1; de melding van de
  server is leidend). Hoogte ongeveer 153 pt.
- Dynamic Island: compact rode stip + games thuis, games uit; minimaal "5·3";
  uitgeklapt LIVE en voortgang, de teamregel en de vier rijen.
- Foto's per partij (`live-photos/<teamId>-<slot>-1|2.jpg` in de App Group): opgehaald
  bij het volgen (`GET /api/team/:id` voor `photos`, dan `/photo/<slot>/<1|2>`), bij de
  start van de app en elke keer dat de app weer op de voorgrond komt. Een push draagt
  geen foto's: een partij of foto die later komt terwijl de app dicht blijft, toont
  tot dan de beginletter. Bewuste vereenvoudiging.
- Instellingen (iPhone, en de gedeelde instellingen van Android): **Melding bij elke
  game**, standaard aan. Wijzigen meldt het opnieuw aan voor de gevolgde wedstrijden
  (`LiveFollow.setAlerts`); bij de start leest de iPhone-app de keuze in.

Bij het scoren voor een partij van een live teamwedstrijd (alle platforms, Core/UI):

- De partij staat meteen op de teampagina zodra het scorescherm verschijnt (stand
  "inspelen"), niet pas na het eerste punt (`LiveShareSync.started`).
- Met **Foto's meesturen** gaan de foto's van beide spelers één keer per koppeling naar
  `PUT /api/team/:id/partij/:slot/photos` (thuisspeler als `p1`); zonder foto's of zonder
  netwerk volgt een nieuwe poging bij het volgende punt (`TeamLive.sendPhotos`).

Getest op 16 oktober in de iPhone 17 Pro Max-simulator tegen de test-Worker: volgen met
foto's voor twee partijen, partij bezig, partij klaar, alle vier klaar, een partij met
foto's die na het volgen kwam (zichtbaar na terug naar de app), compact en uitgeklapt
Dynamic Island, en de melding (geluid, uitgeklapt eiland) bij een gewonnen game van
een losse wedstrijd en bij een beslist partij. Ondertekende build voor een toestel lukt.

## Hoe het werkt

1. App leest de link (`LiveFollowLink.parse` in Core): `https://live.squashanalyzer.com/l/<id>`,
   `squashanalyzer://volg#<id>` of `squashanalyzer://volg#<id>@<host>`. Alleen
   bekende servers: live./beta.squashanalyzer.com en `squash-live-dev.*.workers.dev`.
2. `LiveFollow.follow` haalt de stand op (`GET /api/live/:id`) en laat het platform
   (`LiveFollowPresenter`) de kaart tonen.
3. Het platform geeft zijn push-token door; Core meldt het aan met
   `POST /api/live/:id/followers` (`{platform, token, sandbox}`).
4. De Worker (`server/live-worker/src/push.js`) stuurt na elke `PUT` de hele
   snapshot: APNs `liveactivity`-push (content-state = de snapshot) of een
   FCM-databericht. Bij `finished` of Live stoppen één eindbericht. Dode tokens
   vergeet de server zelf.
5. Stoppen of wegvegen: `DELETE /api/live/:id/followers`.

Zonder geheimen staat pushen uit (`GET /api/push` → false, aanmelden geeft 503):
de huidige API blijft dus werken voor de builds van testers.

### Spelersfoto's op Android

De pushes dragen geen foto's. Bij het volgen (en bij een push als het nog niet
gelukt is) haalt de app ze één keer op: `GET /api/live/:id` (`photos: [true,
false]`) en daarna `GET /api/live/:id/photo/1|2`. Ze worden rond bijgesneden
(112 px) en bewaard in `files/live-photos/<id>-1.png`; een marker
`<id>.checked` voorkomt dat elke rally opnieuw vraagt. Bij Stoppen, wegvegen
of het einde gaan ze weg (een getoonde uitslag houdt zijn eigen kopie). Code:
`LivePhotos.kt`.

## Sleutels (buiten de repo)

| Wat | Waar | Gebruikt door |
|---|---|---|
| APNs-sleutel `AuthKey_8MGUBMNKS7.p8` (Key ID 8MGUBMNKS7, team 65FAHRU88M, Sandbox & Production) | `~/.apple-keys/` | Worker-geheim `APNS_KEY` |
| Firebase-serviceaccount (project `squash-analyzer-18fb3`) | `~/.android-keys/firebase-service-account.json` | Worker-geheim `FCM_SERVICE_ACCOUNT` |
| `google-services.json` | `~/.android-keys/` | Android-build (waarden als BuildConfig; zonder bestand bouwt de app, maar staat volgen uit) |

## Testen

- Test-Worker: `https://squash-live-dev.gerdjanvangils.workers.dev`, met eigen
  Durable Objects en de geheimen. Uitrollen: `cd server/live-worker && npx
  wrangler deploy -c wrangler.dev.toml` (zie de README daar).
- Getest op 15 oktober: iPhone 17 Pro Max-simulator en Android-emulator (API
  36.1 met Play) tegen de test-Worker. Volgen, updates via APNs (sandbox) en FCM,
  gamebal/matchbal, pauze, uitslag, Stoppen. Ook getest: een ondertekende
  Debug-build voor een echt toestel, met `aps-environment`.
- Suites groen: Core (283), iOS-tests, Worker (40), Android unit-tests en
  debug-APK, lint.
- Android-voorbeeldstanden zonder server (alleen debug):
  `adb -s emulator-5554 shell am broadcast -a com.squashanalyzer.android.debug.LIVE_SAMPLE -n com.squashanalyzer.android/.live.LiveScoreSampleReceiver --es state gamebal`
  (spel, gamebal, matchbal, pauze, uitslag, stop). iOS: opstartargument
  `-LiveActivityDemo gameball` (DEBUG).
- De melding van Android 9–15 op de API 36-emulator (alleen debug): voeg
  `--es style ongoing` toe aan die broadcast; dat geldt daarna ook voor echte
  pushes, tot `--es style live`.
- Op 16 oktober tegen de test-Worker getest op de emulator (API 36.1, ook
  360dp breed en licht/donker): volgen met twee, één en geen foto, spel, gamebal,
  pauze, uitslag met vier en vijf games, sessie wissen (melding en foto's weg),
  en de Live Update met avatars (blijft uitgelicht).

## Nog open

- **App Group registreren (16 oktober)**: een ondertekende build voor een
  toestel lukt pas als de App Group `group.com.squashanalyzer.app` bij Apple
  bestaat en aan `com.squashanalyzer.app` en `com.squashanalyzer.app.LiveActivity`
  hangt. Vanaf de command line lukte dat niet: Xcode heeft geen account
  ("No Accounts") en met de API-sleutel AN4XF9Y8MM gaf Xcode "Authentication
  failed" voor ontwikkelprofielen. Gerd-Jan: eenmaal in Xcode inloggen en een
  Debug-build voor de iPhone maken (Automatic signing maakt de groep aan), of
  de groep in het Developer-portaal aanmaken. De simulator werkt al.
- **Foto's bij de eigen wedstrijd** zijn gebouwd maar niet in de simulator
  doorlopen (daarvoor is een wedstrijd met spelersfoto's nodig); het volgen met
  foto's wel.
- **Teamwedstrijd op Android** is nog niet gebouwd (andere branch); de
  iPhone-versie is alleen in de simulator bekeken.
- Een volglink openen terwijl het scherm Wedstrijd volgen al open staat, neemt de
  nieuwe link niet over (eerst Sluiten); gezien op 16 oktober, niet aangepast.
- **Testen op echte toestellen**: iPhone 16 Pro en de A13 (Android 14, dus de
  doorlopende melding). De tickerstijl is alleen op de emulator bekeken (API 36
  met de debugschakelaar); One UI tekent meldingen net anders, vooral de
  hoogte van de ingeklapte melding en de kleuren van het lichte paneel.
- Android: een foto die de coach pas later toevoegt, komt niet meer mee (er
  wordt één keer per wedstrijd gekeken).
- **Naar 3.0 (als Gerd-Jan dat kiest)**:
  - de geheimen op de productie-Worker `squash-live-beta` zetten;
  - de branch naar `main`, wat de Worker automatisch uitrolt;
  - ondertekenen: de Debug-build gebruikt het teamprofiel van de app (met
    `aps-environment`) en voor de extensie het wildcard-teamprofiel; voor een
    archief voor TestFlight moet Xcode de App ID `com.squashanalyzer.app.LiveActivity`
    nog aanmaken (`-allowProvisioningUpdates`), nog niet geprobeerd;
  - voor Play: de release-build leest `~/.android-keys/google-services.json`;
  - de handleiding en releasenotes bijwerken.
- Tot 500 volgers per wedstrijd; elke ronde is één push per volger. Dat past in
  Workers Paid.
- De gedeelde link bevat geen push-info; een oude app zonder deze feature opent
  `squashanalyzer://volg` niet (de kijkpagina blijft gewoon werken).
