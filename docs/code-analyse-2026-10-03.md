# Code-analyse Squash Analyzer — 3 oktober 2026

Stand: `main` op `bfd68ec` (branch `claude/squashanalyzer-code-analysis-410c24`). Niets gewijzigd; dit document bevat alleen bevindingen en aanbevelingen. Alle regelnummers zijn van die commit.

## Omvang en gezondheid

| Laag | Regels | Tests |
|---|---|---|
| `Packages/SquashAnalyzerCore` | 5.800 | 108 (ook via Skip/Kotlin) — groen |
| `Packages/SquashAnalyzerUI` | 7.800 | **geen testtarget** |
| iOS-target (`SquashAnalyzer/`) | 10.850 | 79 (`SquashAnalyzerTests`) |
| Android Kotlin (`Android/app/src/main`) | 3.260 | 60 unit — groen, plus 19 instrumented |
| Live-server (`server/live`) | 330 | 8 — groen |

Wat goed zit: de Core/UI/platform-splitsing is consequent doorgevoerd, de SwiftData-migratieketen V0→V7 klopt (elke stap heeft een stage, bevroren kopieën zijn niet aangeraakt), het backupformaat is byte-identiek op beide platforms met een golden test, de live-server draait als non-root met read-only filesystem, en ARCHITECTURE.md plus docs/android-port.md zijn ongewoon volledig. Er is geen CI, geen linter en geen lokalisatiestrategie; de app is de facto Nederlands-only.

## 1. Bugs (op ernst)

### Hoog

1. **Backup "Voeg toe" dupliceert alles, ook gelijke UUID's.** `ExportService.importFullBackup` (`SquashAnalyzer/Services/ExportService.swift:204-238`) voegt elke speler en wedstrijd onvoorwaardelijk toe; `importMatch` (:445) heeft alleen een commentaar "Check for duplicate". Er is nergens `@Attribute(.unique)`, dus een tweede "Voeg toe" geeft twee `SavedPlayer`- en twee `SavedMatch`-rijen met hetzelfde id. Repository en `BadgeAwarder` gebruiken `.first`, dus bewerkingen landen op een willekeurige kopie. Alleen badge-awards worden wél op id gemerged. Geen test dekt import in een niet-lege store.
2. **Scheidsrechterwedstrijden zitten niet in de backup.** `FullBackup` (`Core/Backup.swift:12-30`) heeft geen referee-sectie; export, automatische iCloud-backup en `replaceWithBackup` slaan `SavedRefereeMatch` over. Dit geldt door het gedeelde formaat ook voor Android (`RoomBackupStore`). Na een herstel is de scheidsrechterhistorie weg terwijl de awards die ernaar wijzen blijven staan, waardoor carrièrebadges anders uitpakken. Vraagt een formaatversie 3.
3. **STROKE-banner verschijnt nooit.** `RefereeMatch.callStroke` (`Core/RefereeMatch.swift:195-198`) zet `lastCallText` en roept dan `awardPoint`, dat als laatste regel `lastCallText = nil` doet (:174). Beide platforms tonen dus alleen LET. `ScreenshotScenario.swift:114` zet het zelfs defensief op nil, waardoor het nooit opviel.
4. **Referee-sluitknop sluit vóór het opslaan klaar is.** `RefereeScoringView.close()` (`UI/RefereeScoring.swift:384-387`) roept `onExit()` én `dismiss()`. `onExit` is `RefereeSessionView.persist(exit: true)`, dat na het asynchrone opslaan zélf `dismiss()` doet. Het scherm is dus al weg voordat de save klaar is; de "Even opslaan…"-overlay en de "Opslaan is niet gelukt"-retrykaart kunnen bij Sluiten nooit verschijnen. `CoachScoringView` doet dit wél goed.
5. **Rate-limit van de live-server is te omzeilen.** `clientIp()` (`server/live/server.js:185-189`) neemt het eerste X-Forwarded-For-adres, dat de client zelf kiest. Achter Cloudflare staat het echte IP achteraan. Met 200 POST's met verzonnen XFF-headers zit de server vol (`maxSessions=200`) en krijgt elke coach een 503. De test `server.test.js:164-168` leunt zelfs op dit spoofen.
6. **SSE-kijkers zijn onbegrensd.** Elke `GET /api/live/:id/events` (`server.js:257-275`) voegt een socket plus `setInterval` toe zonder limiet per sessie of globaal.
7. **Kaart-link decomprimeert zonder bovengrens.** `CardSnapshot.inflate` (`Core/CardSnapshot.swift:168-185`, SKIP-tak) inflateert onbeperkt en wordt synchroon op de main thread aangeroepen vanuit de geëxporteerde `MainActivity`. Een kwaadwillende `squashanalyzer://kaart#…`-intent van ~500 KB kan honderden MB opleveren en de app laten crashen. Zelfde patroon in `website/kaart/index.html:98-101` (browser, laag risico).
8. **Kaart-import bij koude start kan stil verdwijnen.** `CardImportPresenter.present` (`SquashAnalyzer/Views/CardSharingViews.swift:262-276`) zoekt via UIKit de key window; bij een koude start vanuit een link kan die nog ontbreken, de guard returnt, `cardInbox.pending` blijft gezet en de `onChange` in ContentView vuurt niet opnieuw. Een SwiftUI `.sheet(item:)` op `pending` lost dit op.

### Middel

9. **Hersteld coachspel verliest de servicebox-afwisseling.** `Game.restoreServiceState()` (`Core/Game.swift:432-435`) zet altijd de hand-out-box, ook als de server zijn eigen rally won en had moeten wisselen. Alle informatie om dit na te spelen staat in `points`; de referee-kant doet dit al goed met `rebuildUndo`.
10. **`Match.currentGame` is een muterende getter** (`Core/Match.swift:73-84`): als `games` leeg is maakt hij een nieuw spel aan. Na `completeResult` (dat een leeg spel laat vallen) kan een afgeronde wedstrijd zo stil een vers spel krijgen en persisteren.
11. **Checksum hangt af van Double-formattering.** De SHA-256 (`Core/Backup.swift:248-253`) loopt over JSON met `duration: Double`. Een heel korte rally (bijv. 0.0004 s) print Swift als `0.0004` en Kotlin als `4.0E-4`, waarna de andere kant `checksumMismatch` geeft. De golden test pint alleen 3.25 en 12. Afronden op export en een klein getal in de golden test opnemen.
12. **`LiveShare.flush` gooit de eindstand weg bij offline.** Als de laatste PUT faalt terwijl `finishing` waar is, wordt toch `reset()` gedaan (`Core/LiveShare.swift:295-311`); kijkers krijgen nooit het eindresultaat en de UI meldt niets.
13. **Carrière-badges eisen exacte tellingen** (`Core/BadgeEngine.swift:384-391`): `tenOutOfTen` vereist precies 9 eerdere winsten, `veteran` precies 24 wedstrijden. Eén verwijderde wedstrijd of een herstel ná de drempel en de badge is nooit meer te halen.
14. **Historieverwijdering kan een open wedstrijd laten herrijzen.** `MatchHistoryView.deleteMatch` (:425-431) verwijdert de `SavedMatch` direct terwijl ContentView het live `Match`-object kan vasthouden; de volgende rally doet `upsert` en maakt hem opnieuw. Verwijderingen gebruiken bovendien `try?` en omzeilen de repository.
15. **Automatische iCloud-backup draait synchroon op de main thread** bij `.background` (`AutomaticBackup.swift:24-37` → `ExportService.saveBackupToiCloud`), zonder `beginBackgroundTask`. `rotateBackups` herimplementeert bovendien Core's `AutoBackupPlan.filesToDelete`.
16. **`APIKeyManager` negeert Keychain-statuscodes** (`APIKeyManager.swift:47,78`): een mislukte save toont toch "Opgeslagen!". `hasOpenAIKey` doet twee Keychain-reads en wordt in view-bodies geëvalueerd.
17. **Referee-callflash gebruikt `.task` zonder `id:`** (`UI/RefereeScoring.swift:60-66`): een nieuwe tekst tijdens een lopende flash herstart de timer niet en wordt nooit gewist. Latent door bug 3.
18. **Server stopt niet netjes.** `server.close()` (`server.js:325-331`) wacht op open SSE-streams, dus SIGTERM van Docker hangt tot de 10 s kill en kijkers krijgen geen `ended`.
19. **Android: Activity-lek** via `ResultImageSharing.share = { … startActivity(…) }` (`MainActivity.kt:105`) in een statische closure; en bitmap-rendering plus PNG-schrijven synchroon in UI-callbacks (`CardImage.kt:32`, `ResultImage.kt:36`).
20. **Android App Links verifiëren niet**: `autoVerify="true"` in het manifest, maar `website/.well-known/assetlinks.json` bestaat niet. `pathPrefix="/kaart"` matcht ook `/kaartjes`. Controleer ook of de AASA als `application/json` wordt geserveerd (nginx geeft bestanden zonder extensie standaard `application/octet-stream`).
21. **Room `exportSchema = false`**: geen schemahistorie, migratietests draaien handmatig terug met `DROP COLUMN`. Migraties 1→9 zijn wel compleet en kloppen met de entities.
22. **Bestandsnamen uit spelersnamen** (`ExportService.swift:283-288`): een "/" in een naam maakt een subpad, de write faalt en `try?` laat de bijlage stil weg.

### Laag (selectie)

- `Game.addLet` heeft geen `!isGameOver`-guard; `Game.undoLastLet` herstelt `lastPointTime` niet (geen aanroepers, dus dood).
- `CoachAdvice.tempoCandidate` rekent mediaan over álle punten maar de percentages over `timedPoints`.
- `AIModelChoice.preferred` zegt "goedkoopst eerst" maar zet `gpt-4o-mini` vóór `gpt-5-nano`; `maxCompletionTokens: 500` is krap voor 8+ Nederlandse zinnen in JSON.
- `RefereeMatch.rebuildUndo` slaat `prevLastPointAt: nil` op voor elke rally.
- `live.html:96` zet het id in een JS-string met een HTML-escaper; gered door de `/^[a-z0-9]{12}$/`-check. `kaart/index.html` is XSS-schoon.
- `Dockerfile` pint `node:22-alpine` niet op digest.
- Toegankelijkheid: nergens in het UI-package `accessibilityHidden`/`accessibilityLabel`; de verborgen `ServiceSideSelector` blijft voor VoiceOver leesbaar; twee identieke "LET CALL"-knoppen en STROKE-knoppen zonder spelersnaam.
- `MatchHistoryView` `#Preview` bouwt een container met 3 van de 8 modellen en crasht.

## 2. Duplicatie en architectuur

**iOS gebruikt zijn eigen oude views naast de gedeelde.** Overlap gemeten als identieke regels van de iOS-view die ook in de gedeelde view staan:

| iOS-view | Gedeelde tegenhanger | Overlap | Nu verwijderbaar? |
|---|---|---|---|
| `ScoreboardView.swift` (286) | `SharedScoreboardView` | 52 % | Ja |
| `ShotTypeSelectorView.swift` (217) | `ShotTypeSelector.swift` | 76 % | Ja; ook de dode gedeelde `ShotTypeSelectorView` (biedt nog `volley`) |
| `PointTypeButton`/`FistIcon` in ContentView | `PointTypeSelector.swift` | ~100 % | Ja |
| `RefereeSetupSheet` in RefereeView (160) | `MatchSetupView` | — | Ja (nul aanroepers) |
| `BadgeCatalogView` | `SharedBadgeCatalogView` | — | Ja |
| `RefereeView.swift` (711) | `RefereeScoring` + `RefereeSessionView` | 27 % | Na een iOS `RefereeMatchStore` |
| `CoachDashboardView.swift` (837) | `SharedCoachDashboard` | 24 % | Bijna gratis: shared neemt al `APIKeyStore` |
| `PlayerBadgesView.swift` (318) | `SharedPlayerBadgesView` | 25 % | Shared mist `highlightMatchId` en de segment-picker |
| `MatchHistoryView.swift` (1140) | `SharedMatchHistoryView` | 11 % | Shared mist losse games, backup-UI, filters |
| `ContentView.swift` (995) | `CoachScoringView` | — | Na een iOS `CoachMatchStore` |

Ongeveer 800 regels zijn vandaag zonder risico weg te halen; met drie SwiftData-adapters voor de Core-protocollen `CoachMatchStore`, `RefereeMatchStore` en `MatchHistoryStore` nog zo'n 4.000 regels. Core definieert die store-grenzen al en Android implementeert ze alle zeven; **iOS implementeert er geen enkele** (alleen `APIKeyStore`).

**"MatchRepository is het enige schrijfpad" klopt niet meer.** Directe `modelContext.insert/delete` buiten de repository in MatchHistoryView, RefereeView, RefereeInProgressStore, PlayerManagementView, PlayerBadgesView, CardStore, ExportService, TeamImportService, SampleDataService.

**Domeinregels staan dubbel in Core:**

- De serviceregel (server wint → box wisselt, anders hand-out naar voorkeursbox) staat in `Game.swift:292-297` én `RefereeMatch.swift:166-171`, met `handOutSide`/`preferredSide`/`overrideSide` in beide. `ScoringEngine` (38 regels) kent alleen tellen en game-over.
- `gamesToWin`/`firstGameNumber`/`isMatchOver`/`matchWinner` drie keer: `Match`, `RefereeMatch`, `MatchHistorySummary.winner`.
- Duurstatistieken (zes functies) kopie in `Game.swift:566-625` en `Match.swift:294-348`; de Match-kopieën hebben geen aanroepers.
- `longestRun` twee keer; vier vormen van "afgerond scheidsrechterspel" (`CompletedRefereeGame`, `RefereeGameSummary`, `RefereeMatchSnapshot.FinishedGame`, `MatchShareReport.Game`).
- "Beste slag/zone" vijf keer met verschillende filters, waardoor heatmap en advies het oneens zijn over of een stroke "in een vak" telt.
- Advies verdeeld over drie verwarrend genoemde bestanden: `CoachAdviceRules.swift` bevat geen regels maar `ZoneProfile`; `AdviceRules.swift` heeft de regels en roept terug in `CoachAdvice.swift` (circulair).
- `SharedMatchBadgesStrip.earnings` herimplementeert `BadgeEngine.earnings` die iOS gebruikt.
- Android: `HttpAICoachTransport.kt` en `HttpLiveTransport.kt` zijn vrijwel identiek; de debug `network_security_config.xml` dupliceert het hele hoofdbestand.

**God-types.** `Game` (631) mengt de scoremachine met UI-selectiestatus (`selectedPlayer`, `ScoringStep`, `goBackStep`) en ~25 analysequeries. `CoachScoringView` is 670 regels met 14 `@State`s; `SharedSettingsView` (410 regels) staat in een bestand dat `SharedLeagueTeamViews.swift` heet. De save-statemachine (busy/saving/saveAgain/exitAfterSave/failed) staat letterlijk twee keer in `CoachSessionView` en `RefereeSessionView`, ongetest; `saveAgain` wordt nergens geconsumeerd.

**Klok en testbaarheid.** `Date()` hard in `Game.addPoint`, `addLet`, `RefereeMatch.awardPoint`; tests asserten daarom ranges. Een injecteerbare `now: () -> Date` maakt dit deterministisch.

## 3. Prestaties

- Beide scoreschermen tikken elke seconde een `@State var now` in het hoofdscherm (`CoachScoring.swift:340-345`, `RefereeScoring.swift:328-333`), waardoor de hele body elke seconde opnieuw rendert, ook als het spel voorbij is. Terwijl de uitslagkaart staat, draait `BadgeEngine().badges(for:)` over de hele wedstrijd twee keer per tik.
- `SharedCoachDashboard.hasKey` leest de Keychain/Keystore bij elke body-evaluatie.
- `PlayerPhotoView` decodeert elke avatar twee keer per render.
- `PlayerDirectory` doet een N+1 await voor badge-tellingen.
- `SwiftDataMatchRepository.upsert` verwijdert en herschrijft alle games/punten/lets bij elke rally (bewust, maar met `BadgeAwarder.syncAwards` en `@Query`s erachter).

## 4. Designsysteem

- `AppColors`/`AppFonts` bestaan alleen in de app; het UI-package herdefinieert dezelfde RGB-literals in **12 private palettes** (83 kleurliterals, 247 `.font(.system(size:))`). Ze zijn gaan afwijken: `textSecondary` 0.70/0.68/0.65 vs 0.75/0.73/0.70, speler-2-blauw 0.35/0.45/0.55 vs 0.45/0.60/0.75, drie verschillende rood- en groentinten.
- De "uppercase + tracking + padding 14 + hoekradius 12 + stroke"-knop is ≥10× met de hand gemaakt; één `ActionButton`-view scheelt ~200 regels.
- Dood in `DesignSystem.swift`: `HardwarePanel`, `LEDDisplayBackground`, `LEDDigit`, `LEDScoreDisplay`, `LEDColon` (~250 regels, alleen in `#Preview`), `CapsuleLabel`, 17 ongebruikte `AppColors`, `AppFonts.button/playerName/mono`; `HardwareButton.colorDark` wordt genegeerd maar op 5 plekken meegegeven. Dit sluit aan bij de gekozen "referee-stijl overal".
- 17 keer rauw `.green/.red/.orange` in app-views; zes handgemaakte sluitknoppen naast de bestaande `CloseButton`.

## 5. Dode code en opruimwerk

- Stubbestanden met alleen commentaar, nog in `project.pbxproj`: `SquashAnalyzer/Models/RefereeMatch.swift`, `SquashAnalyzer/Services/BadgeEngine.swift`.
- Misleidende namen: `Services/OpenAIService.swift` bevat de URLSession-transports (hernoem naar `NetworkTransports.swift`); `Services/CardSnapshot.swift` bevat `CardStore` (hernoem).
- Zonder aanroepers: `RefereeSetupSheet`, `CompactScoreboardView`, `FlowLayout`, `AppIconView.swift` (212 regels, alleen previews), `SavedMatch.from(_:context:)`, `SavedGame.pointsWon(by:with:)`/`totalGameDuration`/`letsRequested`, `Match.mostEffectiveShot`/`bestZone`/`totalPointsWon`/duurblok, `Game.winPercentage`/`shortestPoint`/`undoLastLet`/`reset`/`goBackStep`, `CourtZone.from(x:y:)` (trekt `CoreGraphics` in Core binnen), alle `.shortName`, `RefereeGameSummary`, `LeagueTeamParser.detail`/`LeagueRubber`/`LeagueMatchDetail`, twee `print("Tapped: …")` in `CourtView.swift:334,342`.
- `SavedPlayerCard` en `SavedBadgeAward.cloudSystemFields` moeten blijven tot een schema V8 ze laat vallen.
- Documentatiedrift: ARCHITECTURE.md:19 noemt V4 als huidig schema (is V7); `PrivacyInfo.xcprivacy:18-19` zegt nog dat de store bij migratiefout wordt gewist.

## 6. Tests

- De **kernscoreregels worden niet in het Core-package getest**, alleen in het iOS-target. Ze draaien dus nooit door Skip op Android: `ScoringEngine`, service-afwisseling, hand-out, undo, `restoreServiceState`, `isValidHeadStart`, `completeResult`, `RefereeMatch` (alleen via snapshot-roundtrip), `MatchShareReport`-teksten, `CoachStop`.
- Ontbrekende iOS-tests, op volgorde: import in een gevulde store (vangt bug 1), scheidsrechterhistorie door export→restore (bug 2), kaart-link koude start (bug 8), `RefereeInProgressStore`, `AutomaticBackup`-rotatie, historie-verwijdering, `APIKeyManager`.
- Servertests missen: XFF-afhandeling (nu als feature getest), kijkerslimiet, viewer-cleanup, `ended` bij sweep.
- Geen UI-tests op iOS; Android heeft er 19 maar slechts één Compose-test voor de gedeelde views (`CourtViewTest.kt`).
- Geen CI. Een minimale workflow met `swift test` in beide packages, `xcodebuild test` op het gedeelde scheme, `gradlew testDebugUnitTest` en `node --test` voorkomt dat bovenstaande stil terugkomt.

## 7. Skip-portabiliteit

- Keypath-literals (`\.rallies`, `\.won`, `\.scorer`) en benoemde tuples in publieke API overtreden de eigen regels uit docs/android-port.md, hoewel ze nu transpileren.
- `Image(systemName:)` buiten `AppSymbol` op 8 plekken; "plus" ontbreekt in de materiaalmap.
- Modifiers met onzekere SkipUI-dekking zonder Compose-test: `.grayscale`, `.blur`, `.colorMultiply`, `TextField(axis:)`, `.contextMenu`, `.onDelete`, `Link`.
- `settings.gradle.kts:23-28` draait `swift build` bij elke Gradle-configuratie.
- `AICoachClient.advice(for game: Game)` draagt een niet-Sendable `Game` over een `await`, precies wat het commentaar erboven wil vermijden.

## 8. Privacy en Play/App Store

- iOS: PrivacyInfo, entitlements en netwerkverkeer kloppen met "Data Not Collected"; alleen de live-server (standaard aan sinds `bfd68ec`) hoort expliciet in privacybeleid en App Store-label.
- Android `data-safety.csv`: de OpenAI-transfer (eigen sleutel van de gebruiker) staat niet als "shared" en voornamen vallen eerder onder "Name" dan onder UGC. `allowBackup="true"` zonder `dataExtractionRules` neemt de Room-DB (WAL) en de versleutelde prefs mee.
- `scripts/asc_api.py` heeft key-id en issuer-id als defaults (identifiers, geen geheimen); `urlopen` zonder timeout; `play_upload.py` knipt release-notes stil af op 500 tekens.

## Aanbevolen volgorde

**Sprint 1 — bugs die gebruikersdata of de dienst raken**

1. Idempotente backup-import (dedupe op id) plus test; scheidsrechterwedstrijden in backupformaat v3 (Core + iOS + Room) plus roundtrip-test.
2. `callStroke` fixen en `dismiss()` uit `RefereeScoringView.close()` halen; `.task(id: call)`.
3. Live-server: client-IP uit `CF-Connecting-IP` achter een `TRUST_PROXY`-vlag, globale create-limiet, kijkerslimiet per sessie en globaal, sessies beëindigen vóór `server.close()`; tests erbij.
4. `CardSnapshot.inflate` begrenzen (payload ≤ 64 KB, uitvoer ≤ 256 KB) en decoderen buiten de main thread; kaart-import via `.sheet(item:)`.
5. `assetlinks.json` toevoegen, AASA-contenttype controleren op beide hosts, `/kaart` → `/kaart/`.

**Sprint 2 — Core robuuster**

6. Serviceregel naar `ScoringEngine` (`ServiceState` + `next(after:)`), gebruikt door `Game`, `RefereeMatch` en een gecorrigeerde `restoreServiceState`; iOS-scoretests overzetten naar het package zodat ze door Skip lopen.
7. `Match.currentGame` niet-muterend, injecteerbare klok, `LiveShare.flush` behoudt `pending` bij mislukte eindstand, `duration` afronden in de backup met uitgebreide golden test.
8. Dubbele match/share-types samenvouwen (`MatchStand`, één `longestRun`, structs i.p.v. tuples), dood Core-code verwijderen.

**Sprint 3 — iOS naar de gedeelde views**

9. Opruimronde: de ~800 direct verwijderbare regels, stubs en pbxproj-verwijzingen, LED/HardwarePanel-familie, hernoemingen, docdrift.
10. Drie SwiftData-adapters voor `CoachMatchStore`, `RefereeMatchStore`, `MatchHistoryStore`; één getest `MatchSessionController`; iOS overschakelen naar `CoachSessionView`, `RefereeSessionView`, `SharedCoachDashboardView`, `SharedMatchHistoryView` (na toevoegen van losse games en `highlightMatchId`).
11. Designtokens: één `SharedColors`/`SharedFonts` in het package, `AppColors` als alias, één `ActionButton`; klok in een blad-view zodat het scherm niet elke seconde rendert.

**Doorlopend**

12. CI-workflow met de vier testcommando's; een `Tests/SquashAnalyzerUITests`-target; `exportSchema = true` met `MigrationTestHelper` op Android.
