# Backlog uit code-analyse — Squash Analyzer (3 oktober 2026)

Bron: `docs/code-analyse-2026-10-03.md`, gebaseerd op `main` = `bfd68ec`. Regelnummers kunnen verschuiven; zoek op symboolnaam.

> **Bijgewerkt na `bfd68ec` (zelfde dag, tot `1a13053`):** unforced error kiest nu
> eerst het punttype en dan de soort (`Game.ScoringStep.selectErrorKind`,
> `ErrorKindPicker`), dus `Game.goBackStep` is niet dood meer (T15). Op iOS staan
> alle sluitknoppen al op `CloseButton`/`CloseToolbarItem` (T17). Live na afloop:
> de app stuurt de eindstand en laat los, de server wist 2 uur later; T13 geldt nog
> (`flush()` doet bij een mislukte eind-PUT nog steeds `reset()`). "Deel score" heeft
> Scorekaart/Verslag/Plaatje (`MatchShareChoice`) en `ResultCard` draagt spelersfoto's.

## Werkafspraken voor wie een ticket oppakt

- Lees eerst `ARCHITECTURE.md`; voor alles onder `Android/` of in `Packages/` ook `docs/android-port.md` (Skip-valkuilen: geen keypath-literals, geen benoemde tuples in publieke API, geen geneste `ForEach`, `#if SKIP` voor Java-interop).
- `Packages/SquashAnalyzerCore` en `Packages/SquashAnalyzerUI` worden met Skip naar Kotlin/Compose getranspileerd. Alleen Foundation in Core; geen SwiftUI, SwiftData of CloudKit.
- SwiftData: nooit een al uitgeleverd `VersionedSchema` (V0–V6) aanpassen. Nieuwe velden = nieuw `SquashAnalyzerSchemaV8` + `MigrationStage` in `SquashAnalyzer/Services/PersistenceSchema.swift`, vorige "current" wordt bevroren kopie.
- Backupformaat (`Core/Backup.swift`) moet byte-identiek blijven op iOS en Android; de golden test in `BackupTests.swift` pint de bytes. Een formaatwijziging = `version` ophogen en oude versies blijven leesbaar.
- Tests draaien per ticket:
  - `cd Packages/SquashAnalyzerCore && swift test` (draait ook de Kotlin-kant via Skip)
  - `xcodebuild test -scheme SquashAnalyzer -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
  - `cd Android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ANDROID_HOME=~/Library/Android/sdk ./gradlew testDebugUnitTest` (nooit connected tests met de fysieke telefoon aangesloten)
  - `cd server/live && node --test`
- Teksten in de app zijn Nederlands. Knoppen in referee-stijl (plat, outlined/getint), geen glossy `HardwareButton`/LED-stijl.
- Eén ticket = één branch/PR; werk de genoemde docs bij als gedrag verandert.

---

## P0 — gebruikersdata of dienst in gevaar

### T1 · Backup "Voeg toe" dupliceert spelers en wedstrijden
**Waar:** `SquashAnalyzer/Services/ExportService.swift` → `importFullBackup` (~:204-238), `importMatch` (~:445, bevat alleen een commentaar "Check for duplicate"), `importGame`. Vergelijk met `importBadgeAwards` dat wél op id merget.
**Probleem:** elke `SavedPlayer`/`SavedMatch`/`SavedGame` wordt onvoorwaardelijk `insert`-ed; geen `@Attribute(.unique)`. Tweede import → dubbele rijen met hetzelfde `id`; `SwiftDataMatchRepository.upsert` en `BadgeAwarder.cardId(forPlayer:)` gebruiken `.first`.
**Doen:** per speler/wedstrijd/game eerst op `id` fetchen; bestaat → velden bijwerken (of overslaan), anders invoegen. Child-records (games/punten/lets) van een bestaande wedstrijd vervangen i.p.v. toevoegen.
**Klaar wanneer:** test in `SquashAnalyzerTests/ScoringAndPersistenceTests.swift` die dezelfde backup twee keer in een gevulde store importeert en gelijke aantallen ziet; bestaande roundtrip-tests groen.

### T2 · Scheidsrechterwedstrijden ontbreken in de backup (iOS én Android)
**Waar:** `Packages/SquashAnalyzerCore/Sources/SquashAnalyzerCore/Backup.swift` (`FullBackup`, geen referee-sectie), `SquashAnalyzer/Services/ExportService.swift` (`exportFullBackup`, `replaceWithBackup`), `SquashAnalyzer/Services/AutomaticBackup.swift`, `Android/.../data/RoomBackupStore.kt`.
**Probleem:** `SavedRefereeMatch`/`RefereeMatchEntity` worden niet geëxporteerd of hersteld; na een restore is de scheidsrechterhistorie weg terwijl badge-awards die ernaar wijzen blijven (carrièrebadges via `BadgeAwarder.history` wijken dan af).
**Doen:** `FullBackup.version` → 3 met optioneel veld `refereeMatches: [RefereeMatchExportData]?` (hergebruik waar mogelijk `RefereeMatchSnapshot`); encoder sorted keys + ISO 8601 behouden; v2-bestanden blijven leesbaar; export/import/replace op beide platforms; `AutoBackup` meenemen.
**Klaar wanneer:** golden test in `BackupTests.swift` uitgebreid; roundtrip-test iOS (export → `replaceWithBackup` → referee-wedstrijd terug) en Android (`RoomBackupStoreTest.kt`); `Android/app/src/test/resources/ios-backup.json` bijgewerkt of een v3-variant erbij.

### T3 · STROKE-banner verschijnt nooit
**Waar:** `Core/RefereeMatch.swift` → `callStroke(to:)` zet `lastCallText = "STROKE -> …"` en roept dan `awardPoint`, dat eindigt met `lastCallText = nil`.
**Doen:** tekst ná `awardPoint` zetten (of het wissen uit `awardPoint` halen). Verwijder het defensieve `match.lastCallText = nil` in `SquashAnalyzer/Services/ScreenshotScenario.swift` (~:114) als het niet meer nodig is.
**Klaar wanneer:** nieuwe `RefereeMatchTests` in het Core-package (niet alleen iOS) met test op `callStroke` → `lastCallText` bevat "STROKE" en spelersnaam; `callLet` → "LET"; op iOS en Android zichtbaar geflasht.

### T4 · Referee-sluiten sluit het scherm vóór het opslaan klaar is
**Waar:** `Packages/SquashAnalyzerUI/Sources/SquashAnalyzerUI/RefereeScoring.swift` → `close()` roept `onExit()` én `dismiss()`; `RefereeSessionView.swift` → `persist(_, exit: true)` doet na de save zelf `close()` → `dismiss()`.
**Probleem:** scherm al weg voor de save; "Even opslaan…" en de retrykaart "Opslaan is niet gelukt" kunnen bij Sluiten nooit tonen; dubbele `dismiss`. `CoachScoringView` doet dit goed (geen eigen dismiss).
**Doen:** `dismiss()` uit `RefereeScoringView.close()` halen. Meteen meenemen: de callflash in dezelfde file gebruikt `.task` zonder `id:` → `.task(id: call)`; en `hiddenResult`/`resultKey` neemt `pointHistory.count` mee zodat undo + opnieuw hetzelfde punt de kaart weer toont.
**Klaar wanneer:** op Android-emulator en iOS-simulator: Sluiten tijdens een trage save toont de overlay; mislukte save toont de retrykaart.

### T5 · Live-server: rate-limit omzeilbaar, kijkers onbegrensd, geen nette shutdown
**Waar:** `server/live/server.js` → `clientIp()` (~:185), SSE-handler `GET /api/live/:id/events` (~:257-275), shutdown (~:325-331); `server/live/test/server.test.js` (~:164-168 test spoofing nu als feature); `server/live/docker-compose.yml`.
**Doen:**
1. Client-IP uit `CF-Connecting-IP` (of laatste XFF-hop) alleen als env `TRUST_PROXY=1`; anders `socket.remoteAddress`. Compose zet de vlag.
2. Globale limiet op creates/minuut naast de per-IP limiet.
3. Kijkerslimiet per sessie (bv. 200) en globaal (bv. 2000); daarboven 503.
4. Bij SIGTERM: alle sessies `ended` sturen en viewers sluiten (`server.closeAllConnections()`) vóór `server.close()`.
5. Klein: `live.html` zet het id met `JSON.stringify` i.p.v. HTML-escape in een JS-string; `Dockerfile` base image op digest pinnen.
**Klaar wanneer:** tests voor XFF-gedrag met en zonder `TRUST_PROXY`, kijkerslimiet, shutdown stuurt `ended`; `node --test` groen; `server/live/README.md` noemt de env-vars. Deploy: Portainer-stack 109.

### T6 · Kaart-link decomprimeert zonder bovengrens (DoS op Android)
**Waar:** `Core/CardSnapshot.swift` → `inflate` (SKIP-tak met `java.util.zip.Inflater`, ~:168-185) en `CardSnapshot(url:)`; aangeroepen synchroon vanuit `Android/.../MainActivity.kt` (~:131-135) → `CardInbox.receive`. Browserkant: `website/kaart/index.html` (~:98-101, `DecompressionStream`).
**Doen:** payload-lengte begrenzen (bv. 64 KB base64) vóór decoderen; uitvoer begrenzen (bv. 256 KB) in de inflate-lus en bij overschrijding `CardSnapshotError.unreadable`; op Android decoderen buiten de main thread; zelfde limiet in `kaart/index.html`.
**Klaar wanneer:** Core-test met een "zip bomb"-payload die netjes faalt; bestaande golden vectors in `CardSnapshotTests` ongewijzigd groen (iOS én Kotlin).

### T7 · Kaart-import op iOS kan bij koude start stil verdwijnen
**Waar:** `SquashAnalyzer/Views/ContentView.swift` (`.onOpenURL` → `cardInbox.receive`, `.onChange(of: cardInbox.pending)`), `SquashAnalyzer/Views/CardSharingViews.swift` → `CardImportPresenter.present` (guard op `UIApplication.shared.connectedScenes…keyWindow?.rootViewController`).
**Probleem:** geen key window bij koude start → guard returnt, `pending` blijft staan, `onChange` vuurt niet opnieuw.
**Doen:** `CardImportPresenter` vervangen door SwiftUI `.sheet(item: $cardInbox.pending)` op root-niveau met de bestaande `CardImportSheet` (`interactiveDismissDisabled`), of hertriggeren bij `scenePhase == .active`.
**Klaar wanneer:** app geforceerd gesloten, link `squashanalyzer://kaart#…` geopend via `xcrun simctl openurl` → importsheet verschijnt.

### T8 · Deep links: Android App Links verifiëren niet, AASA-contenttype onzeker
**Waar:** `Android/app/src/main/AndroidManifest.xml` (`autoVerify="true"`, `pathPrefix="/kaart"`), `website/.well-known/` (alleen `apple-app-site-association`, geen `assetlinks.json`; zie `docs/google-play.md` ~:202), `Core/CardSnapshot.swift` (`hasPrefix("/kaart")`).
**Doen:** `website/.well-known/assetlinks.json` met package `com.squashanalyzer.android` en de SHA-256 van upload- én Play-signing-key; `pathPrefix` en `hasPrefix` naar `/kaart/` (controleer dat de gedeelde links `/kaart/#…` of `/kaart#…` zijn en pas consistent aan); controleren dat beide hosts (apex en www) `apple-app-site-association` én `assetlinks.json` als `application/json` serveren (nginx-config in Portainer-stack 85).
**Klaar wanneer:** `curl -sI https://squashanalyzer.com/.well-known/apple-app-site-association` toont `application/json`; `adb shell pm get-app-links com.squashanalyzer.android` toont `verified`.

---

## P1 — Core robuuster en correct

### T9 · Hersteld coachspel verliest de servicebox-afwisseling
**Waar:** `Core/Game.swift` → `restoreServiceState()` zet altijd `handOutSide(for:)`; aangeroepen vanuit `SquashAnalyzer/Models/SavedGame.swift` (~:158), `Android/.../RoomCoachMatchStore.kt` (~:131) en als undo-fallback in `Game.swift` (~:324).
**Doen:** server en box naspelen uit `points` (`server`/`scorer` per punt plus voorkeursboxen), zoals `RefereeMatch.rebuildUndo` al doet. Combineer met T10.
**Klaar wanneer:** Core-test: spel met server die twee rallies wint → na restore staat de box op de gewisselde kant.

### T10 · Serviceregel naar `ScoringEngine`, scoretests naar het Core-package
**Waar:** `Core/ScoringEngine.swift` (38 regels, alleen tellen/game-over), `Core/Game.swift` (~:292-297, `handOutSide`, `preferredSide`, `overrideSide`), `Core/RefereeMatch.swift` (~:154-185) — dezelfde regel twee keer. Scoretests staan alleen in `SquashAnalyzerTests/` (iOS) en draaien dus nooit door Skip.
**Doen:** `ServiceState { server, side }` + `ScoringEngine.next(after scorer:, state:, preferredSides:)`; `Game` en `RefereeMatch` delegeren; `gamesToWin`/`firstGameNumber`/`isMatchOver`/`matchWinner` één keer (bv. `MatchStand`) gebruikt door `Match`, `RefereeMatch` en `MatchHistorySummary.winner`. Scoring-, service- en head-start-tests uit `ScoringAndPersistenceTests.swift` en `RefereeMatchTests.swift` overzetten (of kopiëren) naar `Packages/SquashAnalyzerCore/Tests`.
**Klaar wanneer:** `swift test` in Core draait de regels op Swift én Kotlin; iOS-tests nog groen; geen gedragswijziging.

### T11 · `Match.currentGame` muteert in een getter
**Waar:** `Core/Match.swift` (~:73-84): maakt een `Game` aan als `games` leeg is; `completeResult` (~:178-180) kan `games` leegmaken; daarna lezen `resumeMessage` (`CoachStop.swift`), `liveSnapshot` (`LiveShare.swift`), `badgeInput` een vers spel in een `.completed` wedstrijd.
**Doen:** eerste spel in `init`/`startNewGame` maken; `completeResult` laat `games` nooit leeg; getter wordt puur. Meteen: injecteerbare klok `now: () -> Date` in `Game` en `RefereeMatch` (nu `Date()` hard in `addPoint`, `addLet`, `awardPoint`, `confirmNextGame`) zodat duurtests exact kunnen asserten.
**Klaar wanneer:** test dat `completeResult` op een wedstrijd met leeg laatste spel geen nieuw spel oplevert; duurtests gebruiken een vaste klok.

### T12 · Backup-checksum kan breken op Double-formattering tussen Swift en Kotlin
**Waar:** `Core/Backup.swift` → `BackupCodec.canonicalData` hasht JSON met `PointExportData.duration: Double`; golden test pint alleen `3.25` en `12`. Een duur als `0.0004` print Swift als `0.0004`, Kotlin als `4.0E-4` → `checksumMismatch` op de andere kant.
**Doen:** `duration` bij export afronden (bv. 3 decimalen) en/of als geheel aantal milliseconden opslaan (let op compatibiliteit met v2-bestanden); golden test uitbreiden met een heel kleine en een niet-ronde duur.
**Klaar wanneer:** `swift test` groen op beide kanten met de nieuwe golden waarden.

### T13 · `LiveShare.flush` gooit de eindstand weg bij offline
**Waar:** `Core/LiveShare.swift` → `flush()` (~:295-311): als `put` faalt en `finishing` waar is, toch `reset()` (wist ook `pending` en `offline`).
**Doen:** bij mislukte eind-PUT `pending` en `finishing` bewaren en bij volgende gelegenheid (app actief, volgende `send`) opnieuw proberen; UI-indicatie via `offline`.
**Klaar wanneer:** `LiveShareTests`: transport faalt bij finish → `pending` blijft, tweede poging slaagt en reset.

### T14 · Carrièrebadges eisen exacte tellingen
**Waar:** `Core/BadgeEngine.swift` → `careerBadges` (~:384-391): `tenOutOfTen` vereist `winsBefore == 9`, `veteran` `before.count == 24`, `nemesis` precies 4 eerdere winsten.
**Doen:** `>=` gebruiken; `isOnce`/`earnedElsewhere` voorkomt al dubbele uitreiking.
**Klaar wanneer:** `BadgeEngineTests`: speler met 12 winsten zonder badge krijgt `tenOutOfTen` alsnog; speler die hem al heeft, niet opnieuw.

### T15 · Kleine Core-fouten en dood domeincode
**Waar/doen:**
- `Game.addLet` krijgt een `!isGameOver`-guard; `Game.undoLastLet`, `Game.reset`, `goBackStep`, `winPercentage`, `shortestPoint` verwijderen (geen aanroepers).
- `Match`: `mostEffectiveShot`, `bestZone`, `totalPointsWon(...)`, `points(forGame:)`, `allLets`, `gamesWon(by:)`, `coachingNotes(for:)` en het hele duurblok (~:291-348, kopie van `Game`) verwijderen.
- `RefereeGameSummary` en de tweede `longestRun` vervangen door `MatchShareReport.Game`.
- `CourtZone.from(x:y:)` + `import CoreGraphics` verwijderen uit Core.
- `CoachAdvice.tempoCandidate`: mediaan en tellingen over `timedPoints`, zoals de percentages.
- `RefereeMatch.rebuildUndo`: `prevLastPointAt` vullen uit de timeline.
- `AIModelChoice.preferred`: volgorde controleren tegen actuele prijzen; `maxCompletionTokens` 500 → ~900.
- Bestandsnamen: `CoachAdviceRules.swift` bevat `ZoneProfile` (geen regels) en `AdviceRules.swift` roept terug in `CoachAdvice.swift`; hernoem naar `ZoneProfile.swift` en haal de cirkel eruit.
- Publieke tuples (`RefereeMatch.swift`, `MatchShareReport.swift`, `LeagueTeam.swift`) → kleine structs; keypath-literals (`\.rallies`, `\.won`, `\.scorer`, `\.isStroke`, `\.longestRun`) → closures (eigen Skip-regel).
**Klaar wanneer:** Core-tests groen op beide kanten; Android bouwt.

---

## P2 — iOS en Android opruimen

### T16 · Verwijderbare iOS-duplicaten (~800 regels, geen gedragsverandering)
**Waar:** `SquashAnalyzer/Views/ScoreboardView.swift` (→ gedeelde `SharedScoreboardView`; `PlayerAvatar` meegeven via `photos:`), `SquashAnalyzer/Views/ShotTypeSelectorView.swift` (→ `ShotTypeSelector.swift`), `PointTypeButton`/`FistIcon` in `ContentView.swift` (→ `PointTypeSelector.swift`), `RefereeSetupSheet` in `RefereeView.swift` (nul aanroepers), `BadgeCatalogView` in `PlayerBadgesView.swift` (→ `SharedBadgeCatalogView`), `CompactScoreboardView`, `FlowLayout` (`PlayerManagementView.swift`), `CapsuleLabel`, `AppIconView.swift`; in het UI-package de dode `ShotTypeSelectorView` (biedt nog `ShotType.volley`). Stubs met alleen commentaar: `SquashAnalyzer/Models/RefereeMatch.swift`, `SquashAnalyzer/Services/BadgeEngine.swift` (+ verwijzingen in `project.pbxproj`). Twee `print("Tapped: …")` in `UI/CourtView.swift`.
**Hernoemen:** `Services/OpenAIService.swift` → `NetworkTransports.swift` (bevat de URLSession-transports); `Services/CardSnapshot.swift` → `CardStore.swift`.
**Docdrift:** `ARCHITECTURE.md` noemt V4 als huidig schema (is V7); `PrivacyInfo.xcprivacy` zegt dat de store bij migratiefout wordt gewist (klopt niet meer).
**Klaar wanneer:** Xcode-build en alle tests groen; screenshots via `scripts/screenshots.sh` ongewijzigd.
**Stand (3 okt):** dode code (nul aanroepers), stubs, prints, hernoemingen en docdrift gedaan; ook weg: `SavedMatch.from`, `SavedGame.totalGameDuration`/`letsRequested(by:)`, `shortName` in Core, `LeagueRubber`/`LeagueMatchDetail`/`detail`. Nog open, bewust naar de designronde (samen met T17/T20): de vier view-wissels `ScoreboardView`, `ShotTypeSelectorView`, `PointTypeButton`/`FistIcon` en `BadgeCatalogView` naar de gedeelde schermen.

### T17 · Dode designsystem-onderdelen weg, tokens gedeeld
**Waar:** `SquashAnalyzer/DesignSystem.swift`: `HardwarePanel`, `LEDDisplayBackground`, `LEDDigit`, `LEDScoreDisplay`, `LEDColon` (alleen in `#Preview`), 17 ongebruikte `AppColors`, `AppFonts.button/playerName/mono`, genegeerde parameter `HardwareButton.colorDark` (5 aanroepers). UI-package: 12 private palettes (`CoachPalette`, `ScoreboardPalette`, `CourtPalette`, `DashboardPalette`, `HistoryPalette`, `LeaguePalette`, `BadgePalette`, `StripPalette`, `ShotPalette`, `SetupPalette`, `HomePalette`, `PlayerStyle`) met afwijkende waarden (`textSecondary` 0.70/0.68/0.65 vs 0.75/0.73/0.70; speler-2-blauw 0.35/0.45/0.55 vs 0.45/0.60/0.75).
**Doen:** één `public enum SharedColors` / `SharedFonts` in `SquashAnalyzerUI`; palettes ernaar laten verwijzen en daarna verwijderen; `AppColors` op iOS wordt alias. Eén `ActionButton(title, style: .filled/.outlined/.gold/.text, color:)` view (geen `ButtonStyle`, SkipUI ondersteunt dat niet betrouwbaar) voor de ≥10 handgemaakte knopvarianten (`MatchResultOverlay`, `ResumePromptCard`, `CoachScoring`, `RefereeScoring`, `SharedCoachDashboard`, `SharedMatchShareView`, `SharedPlayerBadgesView`, `SharedTeamImportView`, `MatchSetupView`). Zes handgemaakte sluitknoppen → bestaande `CloseButton`.
**Klaar wanneer:** geen `Color(red:green:blue:)`-literals meer buiten `SharedColors`; schermen visueel gelijk (screenshots vergelijken).

**Stand (3 okt):** `SharedColors` in het UI-package is de enige bron; alle twaalf lokale paletten zijn weg, en er staan geen `Color(red:…)`-literals meer buiten `SharedColors` (ook niet in de iOS-app). `AppColors` verwijst ernaar. Weg: `HardwarePanel`, de LED-onderdelen, ongebruikte `AppColors`/`AppFonts` en de genegeerde parameter `colorDark`. Kleine verschuivingen: het blauw op het dashboard is nu `steelBlueLight`, en gedempte tekst is overal 0.50/0.48/0.45. **Niet gedaan:** één `ActionButton` voor alle knopvarianten; de stijlafspraak (docs/style/BACKLOG.md) houdt de knoppen zoals ze zijn, dus die gaat mee in de designronde.

### T18 · Scoreschermen renderen elke seconde volledig opnieuw
**Waar:** `UI/CoachScoring.swift` (~:340-345) en `UI/RefereeScoring.swift` (~:328-333): `@State var now` tikt in het hoofdscherm; `badgeEarnings` draait `BadgeEngine().badges(for:)` twee keer per tik zodra de uitslagkaart staat. `SharedCoachDashboard.hasKey` leest Keychain/Keystore per body-evaluatie; `PlayerPhotoView` decodeert elke avatar twee keer per render; `PlayerDirectory` N+1 await voor badge-tellingen.
**Doen:** klok in een blad-view `RallyClock` met eigen `@State`, stoppen bij `isGameOver`; earnings één keer berekenen (`.task(id: isMatchOver)`); `hasKey` één keer in `@State`; foto's één keer decoderen; bulk-API `badges(forPlayers:)` op `PlayerBadgeSummaryStore`.
**Klaar wanneer:** Instruments/Layout Inspector toont geen body-herrender van het hoofdscherm per seconde.

### T19 · Eén geteste `MatchSessionController`
**Waar:** `UI/CoachSessionView.swift` en `UI/RefereeSessionView.swift`: identieke statemachine busy/saving/saveAgain/exitAfterSave/failed; `saveAgain` wordt nergens geconsumeerd; `finish()`/`startOver()` wachten niet op een lopende save; `CoachScoringView`/`RefereeScoringView` houden het `@Observable` model in `@State` (moet `let`).
**Doen:** `@Observable MatchSessionController<Store>` met de serialisatie, gebruikt door beide sessieviews; `let match` in de scoringviews; nieuw testtarget `Packages/SquashAnalyzerUI/Tests` met tests voor de controller plus `MatchResult.*Text`, `WhatsAppPreview.blocks` en `SharedMatchBadgesStrip.earnings` (of deze laatste drie naar Core verplaatsen en daar testen).
**Klaar wanneer:** Android-flows (resume, startFresh, exit tijdens save) werken als nu; tests groen.

### T20 · iOS over op de gedeelde schermen via Core-store-protocollen
**Waar:** Core definieert `CoachMatchStore`, `RefereeMatchStore`, `MatchHistoryStore`, `BackupStore`, `AutoBackupControl`, `CardImportStore`, `PlayerBadgeSummaryStore`; Android implementeert ze alle zeven, iOS geen enkele. iOS-views die dan weg kunnen: `ContentView.swift` (995), `MatchHistoryView.swift` (1140), `RefereeView.swift` (711), `CoachDashboardView.swift` (837), `PlayerBadgesView.swift` (318), setupviews in `HomeView.swift` (~420 regels), `RefereeInProgressStore.swift`.
**Doen (in stappen, elk een eigen PR):**
1. `SwiftDataRefereeMatchStore: RefereeMatchStore` → iOS gebruikt `RefereeSessionView` + `MatchSetupView`; `RefereeInProgressStore` weg.
2. `SwiftDataCoachMatchStore: CoachMatchStore` over `SwiftDataMatchRepository` → iOS gebruikt `CoachSessionView`; `ContentView` krimpt tot host.
3. `APIKeyManager` al `APIKeyStore` → `CoachDashboardView` vervangen door `SharedCoachDashboardView`.
4. `SharedPlayerBadgesView` uitbreiden met `highlightMatchId` ("NIEUW IN DEZE WEDSTRIJD") en de twee-spelers-picker → `PlayerBadgesView` weg.
5. `SharedMatchHistoryView` uitbreiden met losse games (`SavedGame.match == nil`), filters, tap-through en de backup-UI (Android heeft die in `SharedSettingsView`) + `SwiftDataMatchHistoryStore` → `MatchHistoryView` weg. Verwijderen gaat dan via de store i.p.v. direct `modelContext.delete` (lost ook het "herrijzen" van een open wedstrijd op).
**Klaar wanneer:** per stap: screenshots-scenario's draaien, handleiding (`website/handleiding/iphone.html`) klopt, tests groen.

### T21 · Overige iOS-fixes (klein)
- `AutomaticBackup.runIfDue` niet synchroon op de main thread bij `.background`; `beginBackgroundTask` eromheen; `rotateBackups` vervangen door Core `AutoBackupPlan.filesToDelete`.
- `APIKeyManager`: statuscodes van `SecItemAdd`/`SecItemDelete` controleren en fout tonen i.p.v. "Opgeslagen!"; `hasOpenAIKey` cachen.
- `ExportService.writeToTempFile`: spelersnaam saneren (geen `/`, `:`).
- `ContentView` rally-klok `Timer.scheduledTimer` → `TimelineView` (zoals `RefereeView`).
- `HomeView` "Nieuwe wedstrijd" `try?` → fout tonen zoals `ContentView`.
- `MatchHistoryView` `#Preview` met alle 8 modellen.
- `RefereeInProgressStore.load()` wist een beschadigd bestand.
- Toegankelijkheid in het UI-package: `.accessibilityHidden(!isServing)` op de verborgen `ServiceSideSelector`; `accessibilityLabel("Stroke voor \(naam)")` op STROKE-knoppen; gecombineerd label op de twee grote scores in `MatchResultOverlay`; glyphs "▾/✕/▴" vervangen door `AppSymbol`.

### T22 · Android-robuustheid
**Waar/doen:**
- `MainActivity.kt` (~:105): `ResultImageSharing.share` lambda vangt de Activity in een statische → `applicationContext` + `FLAG_ACTIVITY_NEW_TASK`, of wissen in `onDestroy`.
- `CardImage.kt`, `ResultImage.kt`: bitmap renderen + PNG schrijven naar `Dispatchers.IO`.
- `KeystoreAPIKeyStore.kt`: `write()` vangt Keystore-fouten zoals `read()`; `synchronized` op een companion-lock i.p.v. `this`; unit-test toevoegen.
- `AppDatabase.kt`: `exportSchema = true` + `room.schemaLocation` + `MigrationTestHelper`; migratietests niet meer met handmatige `DROP COLUMN`.
- `RoomCoachMatchStore.kt`/`RoomRefereeMatchStore.kt`: match-upsert en `syncAwards` in één transactie.
- `HttpAICoachTransport.kt` en `HttpLiveTransport.kt` → één helper.
- `network_security_config.xml`: debug-variant vervangen door `<debug-overrides>` in het hoofdbestand; `cleartextTrafficPermitted` alleen in een `<domain-config>` voor lokaal testen.
- `AndroidManifest.xml`: `dataExtractionRules` die de versleutelde prefs en `cache/` uitsluiten.
- `settings.gradle.kts`: `swift build` niet bij elke Gradle-configuratie (eigen task of alleen als bron veranderd).
- Play Console data-safety: OpenAI-transfer (eigen sleutel gebruiker) en "Name" voor spelersvoornamen controleren; iOS privacybeleid en App Store-label noemen de live-server (sinds `bfd68ec` standaard aan).

---

## P3 — doorlopend

### T23 · CI
**Doen:** GitHub Actions (of gelijkwaardig) op macOS-runner: `swift test` in beide packages, `xcodebuild test` op scheme `SquashAnalyzer`, `gradlew testDebugUnitTest`, `node --test` in `server/live`. Daarna een lint-stap: verbied bare `Image(systemName:)` in `Packages/SquashAnalyzerUI` (alles via `AppSymbol`; voeg `plus`, `gearshape`, `person.crop.circle`, `pencil`, `trash`, `xmark`, `chevron.right`, `chevron.left` toe aan de materiaalmap), `Color(red:…)` buiten `SharedColors`, keypath-literals in Core.

### T24 · Lokalisatiebesluit
`Packages/SquashAnalyzerUI/Package.swift` declareert `defaultLocalization: "nl"` zonder `.xcstrings`; 105 `Text("…")`-literals plus Engelse restjes ("rallies", "Heatmap", "Winners", "Undo"). Kies: Nederlands-only (verwijder `defaultLocalization`, vervang Engelse woorden) óf één `Localizable.xcstrings` (Skip ondersteunt dit).

### T25 · Testdekking-achterstand (na T10)
Nog ontbrekend: `MatchShareReport` drie teksten en ≥60-min-tak; `CoachStop.stopAction`; `BadgeInput`-mapping; `BadgeEngine.perfectTen` over spellen heen; `AICoach` fallback-takken; `LiveShare` tweede wedstrijd/`update` vóór `start`; `RefereeInProgressStore` roundtrip; `PersistenceRecovery.preserveStoreFiles`; `importFromJSON` losse wedstrijd; servertests voor viewer-cleanup en `ended` bij sweep.
