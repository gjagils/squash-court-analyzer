> **Historisch testverslag van 2–3 oktober 2026.** De hier gebouwde functies zijn met build 17 uitgeleverd. Open punten uit het oorspronkelijke plan kunnen inmiddels zijn opgelost. Voor de actuele stand: [wijzigingen per build](../wijzigingen-builds.md) en [opleveren en hosting](../opleveren-en-hosting.md).

# Lokaal testen: testfeedback oktober 2026

Branch: `claude/tender-rubin-yw2rzz`, gebouwd bovenop `codex/android-phase4`
(de branch van build 16 / Android 0.3). Nog **geen** TestFlight- of
Play-build: eerst lokaal testen.

## Wat is er gebouwd

| Onderdeel | iOS | Android | Waar |
|---|:-:|:-:|---|
| Unforced error: daarna kiezen uit DOWN · OUT · SERVICE · GROND (of Weet niet), geen vak meer | ✅ | ✅ | `ErrorKind`, `Game.selectErrorKind` (Core), `ErrorKindPicker` (UI), `ContentView.scoreTapStage`, `CoachScoring` |
| Soort fout in analyse, lokaal advies, AI-prompt, gametekst | ✅ | ✅ | `Game.errorKindCounts`, `AdviceRules`, dashboards |
| START GAME per game; zonder Start telt de eerste rally niet mee | ✅ | ✅ | `Game.start()`, `Point.isTimed` |
| Opslag van de soort fout | SwiftData V7 | Room 9 | `PersistenceSchema`, `AppDatabase.MIGRATION_8_9` |
| Back-up met de soort fout (oud ↔ nieuw, iPhone ↔ Android) | ✅ | ✅ | `PointExportData.errorKind` (optioneel) |
| Live meekijken: knop LIVE bij Coach en Scheidsrechter | ✅ | ✅ | `LiveShare` (Core), `LiveShareButton` (UI) |
| Live-server in Docker | n.v.t. | n.v.t. | `server/live` |
| Sluitknop op elk scherm | ✅ | ✅ | zie commit "fix: sluitknop op elk scherm" |

## Wat al getest is (in de cloud, zonder Mac)

- **Core**: 103 tests op Linux, waarvan de nieuwe: `ErrorKindAndStartTests`
  (14) en `LiveShareTests` (7). De 6 die daar falen (`CardImport`,
  `CardSnapshot`, `LeagueTeam`) falen alleen omdat zlib-compressie en
  CryptoKit op Linux zijn nagebootst; ze raken niets van deze wijzigingen.
- **Live-server**: `npm test` in `server/live`, 8 tests groen. De kijkpagina
  is in een browser gecontroleerd (tijdens de wedstrijd en na afloop).

## Wat NIET getest kon worden: graag morgen doen

Er was geen Mac (Xcode, Skip) en geen Docker beschikbaar. Dus:

1. **iOS bouwen en testen**
   ```bash
   xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer \
     -destination 'platform=iOS Simulator,name=iPhone 16' -skipPackagePluginValidation
   ```
   Let op de nieuwe tests `testStoreFromVersion6MigratesToErrorKind` en
   `testUnforcedErrorKindSurvivesPersistence`.
2. **Skip/Android**: `skip test --project Packages/SquashAnalyzerCore` en de
   app bouwen (`cd Android && ./gradlew testDebugUnitTest assembleDebug`).
   Nieuw in de gedeelde UI-code (hier zit het grootste Skip-risico):
   - `ErrorKindToggle.swift`, `LiveShareButton.swift` (met `.alert`)
   - `CoachScoring.swift`: startknop, schakelaar, `matchChanged()`
   - `RefereeScoring.swift`: LIVE-knop in de kop
   - `AppSymbol`: nieuw icoon `play.fill` → `Icons.Filled.PlayArrow`
   - Core: `LiveShare` is `@MainActor @Observable` met `static let shared`
   Bij vreemde Kotlin-fouten in code die niet geraakt is: eerst
   `rm -rf Packages/SquashAnalyzerUI/.build/plugins/outputs/squashanalyzerui`
   (zie `docs/android-port.md`).
3. **Migraties op echte data**: open de nieuwe build over build 16 heen
   (iPhone) en over 0.3 heen (Android) en kijk of oude wedstrijden er nog
   zijn. Maak eerst een back-up.

## Testlijst

**Unforced error**
- [ ] Tik op een score → Unforced error → "Wat voor fout was het?" met vier
      tegels DOWN · OUT · SERVICE · GROND en "Weet niet" (sinds 3 oktober;
      eerst stond er een schakelaar boven de knop)
- [ ] Kies er een → het punt telt meteen, zonder baan
- [ ] Onder de knoppen: "Naam: Unforced error · Down"
- [ ] SERVICE ("Servicefout tegenstander") is grijs als de speler die de fout
      maakte niet serveerde
- [ ] "Weet niet" telt het punt zonder soort
- [ ] Annuleer gaat terug zonder punt
- [ ] Analyse: "Eigen fouten: Down 2 · Out 1"; na 2+ keer dezelfde fout
      een advies ("…× in de tin: mik iets hoger…")

**Start**
- [ ] Nieuwe wedstrijd: grote knop START GAME 1, rallyklok staat op 00:00
- [ ] Na START loopt de klok; eerste rally krijgt een tijd
- [ ] Zonder START een punt invoeren: telt wel, maar de eerste rally zonder tijd
- [ ] Volgende game: opnieuw START GAME 2 (pauze telt niet mee)
- [ ] Wedstrijd bewaren en later hervatten: geen START nodig als er al punten zijn

**Live meekijken**: eerst de server draaien
- Lokaal: `cd server/live && node server.js` (Mac) en in
  `LiveShare.defaultBaseURL` (`Packages/SquashAnalyzerCore/Sources/SquashAnalyzerCore/LiveShare.swift`)
  tijdelijk `http://<ip-van-de-mac>:8080` zetten. Android alleen met een
  debug-build.
- Of op de Docker-host via Portainer: zie `server/live/README.md`.
- [ ] Tik LIVE → deelmenu met "Volg Jan – Piet live: <link>"
- [ ] Link openen op een andere telefoon: stand ververst na elk punt
- [ ] Undo en let: de livestand volgt
- [ ] LIVE opnieuw: "Link opnieuw delen" / "Live stoppen"
- [ ] Wedstrijd uit: kijkers zien de eindstand en "afgelopen"; de link later
      openen = "afgelopen"
- [ ] Scheidsrechter: hetzelfde
- [ ] Vliegtuigmodus tijdens een rally: na herstel gaat de stand weer mee

**Deel als plaatje**
- [ ] Coach en scheidsrechter: na een game en na de wedstrijd → Deel score →
      tabs Scorekaart · Verslag · Plaatje (Kort is weg) → bij Plaatje een
      voorbeeld zoals het eindvenster, met de foto's van gekozen spelers →
      één knop Delen
- [ ] Ook tijdens een game (titel "TUSSENSTAND")
- [ ] Lange namen ("Niels van Sevenhoven") passen
- iOS: `ResultCardImage.swift` (nieuw bestand, ook in het Xcode-project gezet).
  Android: `ResultImage.kt` (Canvas), aangezet in `MainActivity` via
  `ResultImageSharing.share`.

**Sluitknoppen**
- [ ] iOS: Home → badges: knop Sluiten
- [ ] iOS: Mijn team-kaart → detail: knop Sluiten
- [ ] Android: Afgeronde wedstrijden → Speler-filter: knop Sluiten

## Open punten / keuzes voor later

- **Domein** voor de live-server: nu `https://live.squashanalyzer.com` in
  `LiveShare.defaultBaseURL`. DNS en de reverse proxy moeten nog worden
  ingericht.
- "Laatste punt tonen aan kijkers" staat **uit** (de coach deelt geen
  analyse met de tegenpartij). Aanzetten kan met
  `match.liveSnapshot(showLastPoint: true)` in `CoachScoring` / `ContentView`;
  een instelling ervoor is nog niet gebouwd.
- Wie de wedstrijd bewaart om later verder te gaan, laat de livesessie staan;
  de server ruimt hem na 2 uur zonder updates op.
- Start-tik van een game zonder punten wordt niet opgeslagen: na hervatten
  verschijnt START opnieuw.
- `website/privacy.html` heeft een alinea "Live meekijken" gekregen; nalezen
  en publiceren vóór een externe build.

## Resultaat lokale run (3 oktober 2026, Mac, Claude)

Alles is op de Mac gebouwd en getest. Geen TestFlight- of Play-upload, geen
versienummers opgehoogd, niets op een echt toestel gezet (alleen de
iOS-simulator en de Android-emulator).

| Stap | Resultaat | Toelichting |
|---|:-:|---|
| 1. Core (`swift test`, `skip test`) | 🟢 | Eerst rood: 4 Skip/Kotlin-fouten. Nu 107/107 op macOS én in Kotlin (Robolectric) |
| 2. iOS (`xcodebuild test`) | 🟢 | Meteen groen; nu 78 tests, waaronder `testStoreFromVersion6MigratesToErrorKind` en `testUnforcedErrorKindSurvivesPersistence`. Geen concurrency-waarschuwingen in de nieuwe code |
| 3. Android (`testDebugUnitTest assembleDebug`) | 🟢 | Meteen groen; 60 tests (1 nieuw: Room 8→9-migratie) |
| 4. Live-server (`npm test`) | 🟢 | 8/8 (Node via Homebrew op de Mac gezet) |
| 5. Visueel | 🟢 | Screenshots hieronder; 4 opmaakfouten hersteld |
| 6. Live meekijken echt | 🟢 | iOS-simulator én Android-emulator tegen `server/live` lokaal; URL daarna teruggezet |

### Hersteld

- `330288e` **Core door Skip/Kotlin**
  - `ErrorKind.out` heet nu `outOfCourt`: `out` is een Kotlin-sleutelwoord
    (syntaxfout). De opgeslagen waarde blijft `"Out"`, dus geen migratie.
  - **Echte bug in `LiveShare`**: in Kotlin verborg het parameterlabel
    `matchId` de property, waardoor `guard matchId == id` altijd waar was. Een
    update van een andere wedstrijd zou zijn verstuurd. Nu `self.matchId`.
  - `Character.isLetter` bestaat niet in Skip (voornaam inkorten).
  - Een async-test wachtte op het verkeerde moment.
- `d69676c` **Test voor Room 8→9**: punten uit 0.3 openen met soort onbekend.
- `f1de87e` **Deelplaatje iOS** had boven en onder een doorzichtige rand (in
  WhatsApp een zwarte of witte balk); nu ondoorzichtig, met een test die het
  plaatje rendert (ook met lange namen). **Schakelaar**: het SERVICE-label
  stond lager dan de andere drie.
- `b74dbed` **Live meekijken werkte op Android helemaal niet**: Kotlin
  initialiseert statics van boven naar beneden, waardoor
  `LiveShare.shared.baseURL` `null` was (elk verzoek naar `null/api/live`).
  Met een test die dit vangt. Verder: de foutmelding toonde op Android twee
  keer **OK**, en de titel brak af als **"SCHEIDSRECHTE / R"** naast de
  LIVE-knop.
- Nieuwe Skip-valkuilen staan in `docs/android-port.md` (punten 1 t/m 10
  onder "Lokale run op de Mac").

### Live meekijken: wat er echt getest is

- iOS coach: LIVE → deelmenu "Volg Jan – Niels live: …"; elk punt komt als
  PUT op de server; undo volgt; de kijkpagina in Safari toont de stand en
  ververst via Server-Sent Events (3–0 → 3–1 meteen binnen); LIVE opnieuw →
  "Link opnieuw delen / Live stoppen"; stoppen = sessie weg (link geeft
  "Afgelopen"). Alleen voornamen op de server ("Niels", niet "van
  Sevenhoven").
- iOS scheidsrechter: LIVE → deelmenu met link.
- Android scheidsrechter (na de fix): POST, PUT per punt, DELETE bij stoppen.
- Niet in de app getest: het automatisch verwijderen na de laatste rally van
  de wedstrijd (wel gedekt door `testStartUpdateFinishDeletesTheSession`) en
  vliegtuigmodus.

### Screenshots (`docs/screenshots-oktober/`)

| Wat | iOS | Android |
|---|---|---|
| START GAME + LIVE-knop (coach) | `ios-coach-start-game-live.png` | `android-coach-start-game-live.png` |
| DOWN · OUT · SERVICE · GROND | `ios-coach-unforced-error-soort.png`, `ios-coach-unforced-error-uitgelijnd.png` | `android-coach-unforced-error-soort.png` |
| Dashboard "Eigen fouten: …" + advies | `ios-dashboard-eigen-fouten.png`, `ios-dashboard-advies.png` | `android-dashboard-eigen-fouten.png` |
| Deel als plaatje | `ios-deel-als-plaatje-wedstrijd.png`, `ios-deel-als-plaatje-tussenstand.png` | `android-deel-als-plaatje-game.png` |
| LIVE scheidsrechter | `ios-scheidsrechter-live.png` | `android-scheidsrechter-live.png` (vóór de fix: `android-scheidsrechter-titel-voor.png`) |
| Live delen / menu | `ios-live-delen.png`, `ios-live-menu.png` | `android-live-delen.png`, `android-live-menu.png` |
| Kijkpagina in de browser | `live-kijkpagina.png` | |

### Nog open

- **Migratie op echte data** (build 16 op de iPhone, 0.3 op de A13): niet
  gedaan, want niets op echte toestellen. In de tests werken V6→V7 en Room 8→9.
- ~~Domein live-server~~ *(sinds 5 oktober draait dit op Cloudflare, zie `docs/opleveren-en-hosting.md`)* **staat live sinds 3 oktober**: Portainer-stack
  `squash-live` (id 109, NAS, poort 3002, branch `main`)
  achter de Cloudflare Tunnel (`live.squashanalyzer.com` →
  `http://192.168.68.120:3002`). Getest: `/health`, aanmaken, live-updates via
  Cloudflare (binnen 2 s bij de kijker), verwijderen, en de iOS-app in de
  simulator tegen de echte server (link, stand per punt, kijkpagina, stoppen;
  screenshot `live-kijkpagina-productie.png`).
- **Verschil Android ↔ iOS** (bestond al, niet van deze branch): een lopende
  coachwedstrijd staat op iOS als INCOMPLEET in Afgeronde wedstrijden, op
  Android niet.
- **Bestaand, niet van deze branch**: een hervatte scheidsrechterswedstrijd
  van 1 oktober toonde op iOS een wedstrijdklok van "2247:12" (de klok telt
  vanaf de start, ook over dagen heen).
- De "Deel als plaatje"-knop op iOS is via een test gerenderd, niet in de app
  doorgetikt (op Android wel, tot en met het deelmenu).
