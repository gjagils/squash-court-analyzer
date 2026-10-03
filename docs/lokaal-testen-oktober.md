# Lokaal testen: testfeedback oktober 2026

Branch: `claude/tender-rubin-yw2rzz`, gebouwd bovenop `codex/android-phase4`
(de branch van build 16 / Android 0.3). Nog **geen** TestFlight- of
Play-build: eerst lokaal testen.

## Wat is er gebouwd

| Onderdeel | iOS | Android | Waar |
|---|:-:|:-:|---|
| Unforced error: schakelaar DOWN · OUT · SERVICE · GROND, geen vak meer | ✅ | ✅ | `ErrorKind` (Core), `ErrorKindToggle` (UI), `ContentView.scoreTapStage`, `CoachScoring` |
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
- [ ] Tik op een score → Unforced error: boven de knop staat
      DOWN · OUT · SERVICE · GROND
- [ ] Kies er een → tik Unforced error → het punt telt meteen, zonder baan
- [ ] Onder de knoppen: "Naam: Unforced error · Down"
- [ ] SERVICE is grijs als de speler die de fout maakte niet serveerde
- [ ] Niets kiezen werkt ook (soort onbekend)
- [ ] Annuleer zet de keuze terug
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
      "Deel als plaatje" → een PNG zoals het eindvenster (titel, namen, grote
      stand, winnaar, chips per game)
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
