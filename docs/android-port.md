# Android port (one Swift codebase, via Skip)

**Status: Fase 0 t/m 4 afgerond; fase 5 Spelers, `CourtView`, coach-modus
scoren, scheidsrechtermodus (beide ínclusief opslag/hervatten), de
badges-catalogus, "Kies speler" bij nieuwe wedstrijden, echte badge-awards
inclusief career-badges (berekenen, opslaan, tonen in Spelers, én een
"Badges verdiend"-strip op het match-einde-scherm), en een
geschiedenisoverzicht van afgeronde wedstrijden zijn afgerond
(2026-09-27).** Alle badges-substappen zijn hiermee compleet. Android heeft
nu een echt startscherm, een
werkend spelersbeheer-scherm, een volledig werkende coach-scoreflow (tik
score → puntsoort → zone → slag, undo, game/match-einde) en een werkende
scheidsrechtermodus (punten, LET, STROKE, undo, game-wissel) — beide met
automatische opslag/hervatten via Room, een "Kies speler"-stap vóór een
nieuwe wedstrijd start (`MatchSetupView`, gedeeld), automatische
badge-berekening bij elke opslag (`BadgeAwardStore`, Room-schema 5) die
zichtbaar is via een badge-aantal per speler in het Spelers-scherm (met een
tik-door naar hun verdiende badges, `SharedPlayerBadgesView`) én direct op
het match-einde-scherm (`SharedMatchBadgesStrip`) — plus een vijfde
starttegel "Badges" met de volledige badge-catalogus, en een echte
"Afgeronde wedstrijden"-tegel die coach- en scheidsrechterwedstrijden samen
toont (`SharedMatchHistoryView`). Allemaal test-gedekt en (waar praktisch
haalbaar) handmatig op de emulator geverifieerd. `Game`, `Match`, `Point`,
`LetCall`, `ServerSide`, `MatchStatus`, `RefereeMatch` en `Match`/
`RefereeMatch`'s `badgeInput`/`rallyWinners` zijn gedeeld via
`SquashAnalyzerCore`, met een `CoachMatchStore`-, een `RefereeMatchStore`-,
een `PlayerBadgeSummaryStore`- en een `MatchHistoryStore`-protocol ernaast.
Regressie bij de laatste stap: `:app:testDebugUnitTest` groen,
`:app:connectedDebugAndroidTest` (13/13), `swift test`/`skip test` groen,
volledige iOS-testsuite (`xcodebuild test -skipPackagePluginValidation`)
**TEST SUCCEEDED**. De Badges-tegel verscheen bij een eerdere stap ook op
iOS' eigen homescherm, zie Fase 5 hieronder. Geen TestFlight-upload.

Eén echte fout gevonden en gefixt tijdens deze regressierun:
`PlayerScreenTest.createEditReopenAndDeletePlayer` riep `.performScrollTo()`
aan op de naam-/notitievelden, maar Skip's `ScrollView`-implementatie op
Android hangt (nog) geen Compose scroll-semantics-actie aan zijn kinderen
("Semantic Node has no parent layout with a Scroll SemanticsAction"). Dat is
een SkipUI-beperking, geen app-bug: het formulier past ruim op het
testtoestel zonder te hoeven scrollen. Fix: de `.performScrollTo()`-aanroepen
uit de test verwijderd; als het spelersformulier ooit te lang wordt voor een
klein scherm, moet scrollen op Android apart geverifieerd worden zodra
SkipUI die semantics wel blootgeeft.

Dit document is het naslagwerk voor de Android-port. Werk je hieraan verder,
houd dit bestand bij: fase-status, nieuwe transpile-eigenaardigheden en
beslissingen. Volgende: **fase 5, opslag voor scheidsrechterwedstrijden
(dezelfde `MatchStore`-koppeling als coach-modus), daarna badges-UI en
wedstrijdgeschiedenis**.

## Doel en harde eisen (van Gerd-Jan, 2026-09-26/27)

- **Eén Swift-codebase**, geen aparte Kotlin-herschrijving.
- **Geen functieverlies op iOS** tijdens de hele operatie.
- **Stap voor stap**: per stap één stuk functionaliteit "ontsluiten" op
  Android, nooit in één keer alles.
- **Beide testsets moeten na elke stap groen zijn**: de bestaande
  `xcodebuild test` (iOS/XCTest) én, zodra die er is, de Android-kant
  (dezelfde tests, getranspileerd, als JUnit).
- **iOS blijft tijdens deze hele operatie op lokale builds** (via `xcodebuild`
  + `devicectl` naar Gerd-Jans iPhone), **geen TestFlight-uploads**, tot een
  afgesproken Android-mijlpaal is bereikt. TestFlight-cadans hervatten is een
  expliciete latere beslissing, niet vanzelfsprekend.
- Losse, per-platform code mag, voor een enkele functionaliteit die zich er
  niet voor leent (bijvoorbeeld: CloudKit-delen blijft iOS-only, opslag wordt
  per platform geïmplementeerd achter hetzelfde protocol).

## De gekozen aanpak: Skip

[Skip](https://skip.tools) transpileert Swift/SwiftUI naar Kotlin/Jetpack
Compose. Je blijft dus in Swift schrijven; Skip genereert er een Android-app
naast. Alternatieven (volledige Kotlin-herschrijving, Flutter/React Native)
zijn expliciet afgewezen omdat ze een tweede codebase betekenen.

### Wat al op Gerd-Jans Mac staat (gecontroleerd 2026-09-27)

- **Android Studio** stond al geïnstalleerd, met een complete SDK op
  `~/Library/Android/sdk` (platform-tools, emulator, system-images) én een
  werkende AVD: `Medium_Phone_API_36.1`.
- **Skip is geïnstalleerd** via `brew install skiptools/skip/skip` (tap
  `skiptools/skip`), versie 1.9.11. Dit trok ~33 dependencies mee (gradle,
  openjdk, android-commandlinetools, swiftly, …).
- `skip doctor` is volledig groen: Xcode 27.0, Swift 6.4, Gradle 9.7.1, Java
  27, Android SDK 37.0.0 — Skip gebruikt de **bestaande** Android Studio-SDK,
  niet een eigen kopie.
- Er is **geen fysiek Android-toestel nodig om te beginnen**; de gratis
  emulator is genoeg tot en met fase 3. Vanaf fase 4 (eerste echte scherm) is
  een los Android-toestel (middenklasse Samsung/Pixel volstaat) nuttig voor
  een echte aanraaktest naast de emulator.

### Nuttige commando's

```bash
# Emulator starten (duurt ~10-60s om te booten)
~/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_36.1 -no-snapshot -no-boot-anim &
~/Library/Android/sdk/platform-tools/adb devices     # moet 'emulator-5554 device' tonen

# Skip's eigen diagnose
skip doctor
skip devices          # toont zowel iOS-simulators als Android-emulators/toestellen

# In een Skip-package: transpileert naar Kotlin, bouwt met Gradle, draait als
# JUnit/Robolectric-tests op de lokale JVM — GEEN emulator nodig, dit is de
# snelle iteratielus voor de logica-laag
cd Packages/SquashAnalyzerCore && swift test

# Side-by-side rapport: dezelfde tests op Darwin (XCTest) én Android
# (Robolectric/JUnit), met per-test pass/fail en timing naast elkaar
skip test --project Packages/SquashAnalyzerCore

# iOS-app bouwen/testen vanaf de CLI: NU verplicht met deze vlag, want Xcode
# vraagt anders interactief om het "skipstone" build-tool-plugin te
# vertrouwen (de eerste keer dat je het project in de Xcode-GUI opent krijg
# je diezelfde vraag als eenmalig klikbaar dialoogvenster — dat is normaal)
xcodebuild build -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer \
  -destination 'platform=iOS Simulator,id=<UDID>' -skipPackagePluginValidation
xcodebuild test  -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer \
  -destination 'platform=iOS Simulator,id=<UDID>' -skipPackagePluginValidation
```

`skip android test` / `skip android sdk install` is een **ander** spoor (Swift
native gecompileerd vóór Android, niet transpiled-naar-Kotlin) en is niet wat
wij gebruiken — niet per ongeluk installeren, dat is een aparte, zware SDK die
voor onze aanpak niet nodig is.

## Fase 0 — Haalbaarheid (AFGEROND, 2026-09-27)

Doel: bewijzen dat de toolchain werkt vóórdat we iets aan de echte app
veranderen. Aanpak: een wegwerp-project (`skip init --transpiled-model`,
**niet** in deze repo, in een scratch-map) met een letterlijke kopie van een
klein stukje echte logica.

**Resultaat: geslaagd.** Een kopie van `Player` (enum) en de "5 op rij"-regel
uit `BadgeEngine.swift`, met dezelfde asserts als de echte
`BadgeEngineTests.swift`, transpileert naar Kotlin en draait als JUnit-tests
via `swift test` — én op de gewone iOS/XCTest-kant. Beide kanten groen.

**Twee concrete transpile-eigenaardigheden gevonden** (belangrijk voor fase 1,
want onze *echte* `BadgeEngineTests.swift` bevat dit exacte patroon):

1. **`.foo`-shorthand in een dictionary-subscript zonder tweede context faalt.**
   `XCTAssertNil(five[.player2])` gaf `Unresolved reference 'player2'` in de
   gegenereerde Kotlin. `XCTAssertEqual(five[.player1], [...])` (met een
   tweede argument dat het type wél verankert) werkte prima. **Fix:** schrijf
   het type voluit: `XCTAssertNil(five[Player.player2])`.
2. **`.foo`-shorthand als tweede operand van `+` tussen twee gelijksoortige
   generieke aanroepen verliest zijn type.** `Array(repeating: Player.player1,
   count: 5) + Array(repeating: .player2, count: 6)` transpileerde de tweede
   helft naar `Array(repeating = Any.player2, count = 6)` — dus `Any` in
   plaats van `Player`. **Fix:** ook hier het type voluit schrijven:
   `Array(repeating: Player.player2, count: 6)`.

   Deze exacte regel staat letterlijk in
   [`SquashAnalyzerTests/BadgeEngineTests.swift`](../SquashAnalyzerTests/BadgeEngineTests.swift)
   (`testBothPlayersCanEarnTheBadge`). Bij het overzetten van de tests in fase
   1/2 moet deze regel dus worden aangepast (of alleen voor de Android-run een
   afwijkende variant hebben) — puur cosmetisch, verandert niets aan het
   gedrag.

**Vuistregel voor de rest van de poort:** vermijd `.shorthand`-enum-syntax in
een context waar Skip's type-inferentie het moet "raden" via een operator of
een subscript zonder tweede context. Schrijf het type voluit zodra een
transpile-fout een `Unresolved reference` of een verdachte `Any` in de
gegenereerde Kotlin toont.

## Fase 1 — Pure logica loskoppelen (AFGEROND, 2026-09-27)

Doel: `ScoringEngine`, `BadgeEngine`, `MatchShareReport`, `CardSnapshot`, de
teamlink-parser (`LeagueTeamParser`/`LeagueTeamService`), en de simpele
modelwaarden (`Player`, `PointType`, `ShotType`, `CourtZone`) verhuizen naar
een Swift Package **binnen deze repo** (`Packages/SquashAnalyzerCore/`).

### Wat er staat

Het package [`Packages/SquashAnalyzerCore`](../Packages/SquashAnalyzerCore)
bestaat en bevat `Player`, `PointType`, `ShotType`, `CourtZone`,
`ScoringEngine`/`SquashScore`, `MatchShareReport`/`MatchShareStyle`, en de
volledige pure kant van `BadgeEngine` (`BadgeKind`, `BadgeRally`, `BadgeGame`,
`BadgeMatchInput`, `BadgeEngine`, `MatchBadgeEarning`), allemaal met `public`
API. Alle types kregen expliciete `public init(...)` waar nodig, want SPM's
automatische memberwise-init is nooit `public`.

Het package is nu **echt aan de app gekoppeld** via Xcode's eigen
Package Dependencies-mechanisme (zie "De hobbel" hieronder voor hoe dat is
gelukt), en de app gebruikt het ook echt:

- `Game.swift` bevat de `Player`-enum niet meer, en importeert
  `SquashAnalyzerCore` in plaats daarvan.
- `Services/BadgeEngine.swift` in de app bevat alleen nog de
  `Match`/`RefereeMatch`-extensies (`badgeInput`, `rallyWinners`) plus
  `MatchBadgeEarning`/`earnings(for:playerIds:names:)` — de pure badge-regels
  zelf komen uit het package.
- `Models/CourtZone.swift`, `Models/PointType.swift`, `Models/ShotType.swift`,
  `Services/ScoringEngine.swift` en `Services/MatchShareReport.swift` zijn uit
  de app verwijderd (zowel van schijf als uit `project.pbxproj`) — die typen
  bestaan alleen nog in het package.
- Alle overige app-bestanden die deze typen gebruiken hebben een
  `import SquashAnalyzerCore` gekregen (32 bestanden in `SquashAnalyzer/`,
  plus 4 testbestanden in `SquashAnalyzerTests/` die de typen rechtstreeks
  gebruiken: `@testable import SquashAnalyzer` geeft namelijk geen toegang tot
  de publieke API van een ander module — die moet je apart importeren).

`Packages/SquashAnalyzerCore/Tests` bevat een overgezette, groene versie van
`BadgeEngineTests` (15 tests, `swift test` binnen de package-map): draai het
zelf met

```bash
cd Packages/SquashAnalyzerCore && swift test
```

Twee tests bleven bewust in de app achter, want die raken `Match`/
`RefereeMatch` (die niet mee verhuizen): `testRefereeRunCarriesOverIntoTheNextGame`
en `testCoachMatchRallyWinnersFollowPlayOrder`.

Geverifieerd: `xcodebuild test` op het bestaande iOS-schema **en**
`swift test` in de package zijn allebei groen.

### De hobbel: het package aan het Xcode-project koppelen

Eerste poging: `Packages/SquashAnalyzerCore` als lokale Swift Package
dependency in `SquashAnalyzer.xcodeproj/project.pbxproj` verbinden door het
projectbestand direct te bewerken (dit project gebruikt het oude,
handgeschreven pbxproj-formaat, geen `PBXFileSystemSynchronizedRootGroup`).
Dat hand-edit (een `XCLocalSwiftPackageReference`, `XCSwiftPackageProductDependency`,
`packageReferences`, `packageProductDependencies`, `PBXBuildFile`) resulteerde
in een geldig maar **niet werkend** projectbestand: zolang niets het package
importeerde bouwde de app foutloos, maar zodra `import SquashAnalyzerCore`
ergens werd toegevoegd, gaf de build `error: Unable to resolve module
dependency: 'SquashAnalyzerCore'`. `xcodebuild -resolvePackageDependencies`
bleef leeg, en `-verbose` builds toonden `Target dependency graph (1 target)`
— Xcode's buildsysteem nam het package dus nooit echt op in de
dependency-graph van het target, ondanks syntactisch correcte pbxproj-secties.

**Fix: laat Xcode zelf de pbxproj schrijven, via de GUI.** Dit bleek in twee
stappen te zitten, en de eerste stap alleen is niet genoeg:

1. Project selecteren in de Project Navigator → tab **Package Dependencies**
   → **+** → **Add Local...** → map `Packages/SquashAnalyzerCore` kiezen.
   Dit registreert het package alleen op **project**-niveau
   (`XCLocalSwiftPackageReference` in `packageReferences`) — **niet genoeg**,
   er is dan nog geen enkel target dat het product daadwerkelijk linkt.
2. **Target** `SquashAnalyzer` selecteren (niet het project!) → tab
   **General** → sectie **Frameworks, Libraries, and Embedded Content** →
   **+** → `SquashAnalyzerCore` kiezen. Pas deze stap schrijft
   `packageProductDependencies` op het target, een
   `XCSwiftPackageProductDependency`-object, én een `PBXBuildFile` met
   `productRef` in de Frameworks-buildfase — dat is wat de build daadwerkelijk
   nodig heeft.

**Vuistregel voor Fase 2 e.v.:** een lokaal Swift-package koppelen aan een
Xcode-target is altijd twee stappen — project-niveau (package registreren) én
target-niveau (product linken via Frameworks/Libraries/Embedded Content).
Alleen de eerste stap doen lijkt te werken (het project blijft geldig, bouwt
zelfs) maar breekt zodra je het package echt importeert.

Regels voor de rest van deze fase:

- **Eén bestand per keer.** Na elke verplaatsing: `xcodebuild test` op het
  bestaande iOS-schema moet exact hetzelfde resultaat geven als ervoor. Geen
  gedragsverandering, puur een herstructurering.
- **Mag direct naar `main`.** Dit is onzichtbaar voor gebruikers en zonder
  risico voor de TestFlight-app (die sowieso stilligt tijdens deze operatie).
- Zodra een bestand in het package staat: kopieer de bijbehorende tests naar
  het package en run ze ook via `swift test` binnen dat package, met de
  vuistregel van fase 0 toegepast waar nodig.
- CryptoKit (`SavedBadgeAward.awardId`'s SHA-256) en Foundation's
  `NSRegularExpression`/`NSData`-compressie (`CardSnapshot`, `LeagueTeamParser`)
  zijn nog niet los getest op Skip — dat is onderdeel van deze fase, niet van
  fase 0. Als die niet 1-op-1 transpileren, is een kleine
  platform-specifieke vervanging acceptabel (net als bij opslag), zolang het
  gedrag (dezelfde output) identiek getest blijft.

## Fase 2 — Android-kant van dat package (AFGEROND, 2026-09-27)

Doel: `Packages/SquashAnalyzerCore` daadwerkelijk door Skip laten
transpileren naar Kotlin en de bestaande tests als JUnit op de JVM draaien
(via Robolectric, geen emulator nodig) — het vangnet dat meteen faalt zodra
Android ooit van iOS afwijkt.

### Wat er is gedaan

`Package.swift` is omgezet naar een echt Skip-package: `swift-tools-version:
6.1`, `dependencies` op `skiptools/skip` en `skiptools/skip-foundation`, het
`SquashAnalyzerCore`-target krijgt `SkipFoundation` als dependency en het
`skipstone`-buildplugin, en het testtarget krijgt daarnaast `SkipTest`. Het
library-product staat op `type: .dynamic` (net als Skip's eigen
`skip init --transpiled-model` template dat genereert). Er zijn ook
`Sources/SquashAnalyzerCore/Skip/skip.yml` en
`Tests/SquashAnalyzerCoreTests/Skip/skip.yml` bijgekomen (grotendeels lege
placeholders — hier komen ooit Gradle-dependencies als Android dat nodig
heeft).

`swift build`/`swift test` transpileert nu automatisch naar Kotlin, genereert
een volledig Gradle-project onder `.build/plugins/outputs/.../skipstone/`, en
draait de tests via Robolectric. `skip test --project
Packages/SquashAnalyzerCore` geeft een side-by-side rapport: **15/15 tests
groen op zowel Darwin (XCTest) als Android (Robolectric/JUnit)**.

### Nieuwe Skip-eigenaardigheden (naast de twee uit fase 0)

Bij het echt transpileren naar Kotlin (in plaats van alleen `swift build`
zonder plugin) kwamen deze concrete problemen naar boven — allemaal in échte
productiecode/tests, niet verzonnen:

1. **`Date.FormatStyle` bestaat niet in SkipFoundation.** Er is geen Kotlin-
   equivalent voor de hele `.formatted(.dateTime.weekday(...)...)`-API.
   `MatchShareReport.shortDateText`/`longDateText` gebruikten dit voor de
   Nederlandse datumtekst in de share-berichten. Fix: overgezet naar
   `DateFormatter` met een vast `dateFormat`-patroon (`"EEE d MMM"` /
   `"EEEE d MMMM yyyy"`) plus `locale`, want `DateFormatter` transpileert wél
   (naar `java.text.SimpleDateFormat`). Geen zichtbare gedragsverandering op
   iOS; geen test controleerde de exacte opgemaakte string.
2. **Een gebonden method reference als eerste-klas waarde (`kinds.contains`,
   `front.contains`) transpileert niet betrouwbaar.** `BadgeKind.allCases
   .filter(kinds.contains)` en `$0.zone.map(front.contains)` gaven in Kotlin
   "Function invocation 'contains(...)' expected" / een type-inferentiefout.
   Fix: altijd een expliciete closure schrijven — `.filter { kinds.contains($0) }`,
   `.map { front.contains($0) }` — nooit een kale method reference doorgeven.
3. **Een geheel getal-literal in een `Double`/`TimeInterval`-context verliest
   zijn type als de aanroep niet direct een `Double`-parameter raakt.**
   Naast het eerder gevonden `Array(repeating:count:)`-geval (fase 0) ook
   gezien bij: `($0.duration ?? 0)` (moet `?? 0.0` zijn), `60 * 60` toegekend
   aan een `TimeInterval`-`static let` (moet `60.0 * 60.0`), en
   `match.duration = 61 * 60` in een test (idem). **Vuistregel: bij twijfel,
   schrijf het decimaalteken erbij.**
4. **Een testbestand dat `Foundation`-types gebruikt (`UUID`, `Date`,
   `TimeInterval`) maar zelf geen `import Foundation` heeft, laat Skip de
   `import skip.foundation.*` in de gegenereerde Kotlin-file weglaten** — ook
   al compileert het gewoon in Swift dankzij `@testable import
   SquashAnalyzerCore`, dat die types al importeert. Fix: importeer
   `Foundation` expliciet in elk testbestand dat die types noemt.
5. **Een trailing closure met impliciete `$0` die zelf weer een initializer
   met meerdere labeled arguments aanroept (`.map { .init(matchId: UUID(),
   date: Date(timeIntervalSince1970: TimeInterval($0.offset)), ...) }`) kan
   de Kotlin-transpiler in de war brengen** — het gaf volledig onbegrijpelijke
   fouten ("Unresolved reference 'UUID'" middenin een regel die overduidelijk
   `UUID` aanroept). Fix: geef de closure-parameter een expliciete naam
   (`{ entry in ... }` / `{ i in ... }`) in plaats van `$0`, vooral zodra de
   closure-body een initializer met meerdere labeled args bevat.

### Xcode-kant: twee dingen om te weten

- **`xcodebuild`/Xcode-GUI vraagt nu om het `skipstone`-buildplugin te
  vertrouwen** zodra het project een Skip-package als dependency heeft. In de
  Xcode-GUI is dat een eenmalig klikbaar "Trust & Enable"-dialoogvenster. Voor
  `xcodebuild` vanaf de command line is de vlag `-skipPackagePluginValidation`
  nu **verplicht** bij elke `build`/`test`-aanroep op dit project (zie
  "Nuttige commando's" hierboven) — zonder die vlag faalt de build met
  "Validate plug-in 'skipstone' in package 'skip'".
- **Het package-product moest ook los aan het `SquashAnalyzerTests`-target
  gekoppeld worden**, niet alleen aan `SquashAnalyzer`: fase 1 linkte het
  product alleen aan het app-target (via de Xcode-GUI), maar
  `SquashAnalyzerTests` gebruikt `import SquashAnalyzerCore` ook rechtstreeks
  in vier testbestanden. Zolang het package een automatisch/statisch product
  was liep dat toevallig goed (de symbolen kwamen mee via de host-app), maar
  na de omzetting naar `type: .dynamic` (nodig voor Skip) faalde het linken
  met "symbol(s) not found for architecture arm64" voor `PointType`/
  `ScoringEngine`-symbolen. Ditmaal loste een handmatige `project.pbxproj`-
  edit dit wél op (in tegenstelling tot fase 1's mislukte hand-edit): de
  project-brede package-registratie stond al vast te werken (bewezen door het
  app-target), dus alleen de tweede laag — een nieuwe `PBXBuildFile` met
  dezelfde `productRef`, toegevoegd aan `SquashAnalyzerTests`'
  Frameworks-fase en `packageProductDependencies` — moest nog bij. Zie de git-
  geschiedenis van `project.pbxproj` voor de exacte diff als referentie voor
  een volgend target dat het package ooit nodig heeft.

Geverifieerd: `xcodebuild test -skipPackagePluginValidation` op het
bestaande iOS-schema is groen, en `skip test` geeft 15/15 op zowel Darwin als
Android.

## Fase 3 — Opslag-abstractie (AFGEROND, 2026-09-27)

`MatchRepository`-protocol bestaat al op iOS
([`MatchRepository.swift`](../SquashAnalyzer/Services/MatchRepository.swift),
geïmplementeerd door `SwiftDataMatchRepository`). Voor Android komt een tweede
implementatie van datzelfde protocol op SQLite/Room. Dit is het stuk waarvoor
Gerd-Jan al vooraf akkoord gaf dat er losse code per platform mag komen.

### Waarom dit geen Swift/Skip-code is

`SwiftDataMatchRepository` leunt volledig op SwiftData (`ModelContext`,
`@Model`, `#Predicate`) — dat transpileert niet naar Android en zal dat ook
nooit doen. Er is dus geen gedeeld Swift-protocol dat naar Kotlin overgaat
zoals bij `SquashAnalyzerCore`; Android krijgt een **losstaande, met de hand
geschreven Kotlin-implementatie** die dezelfde vier bewerkingen aanbiedt
(`upsert`, `mostRecentInProgressMatch`, `markAbandoned`, `delete`) op
dezelfde manier (kind-records altijd volledig vervangen, niet diffen). Alleen
het *concept* is gedeeld, niet de code.

### Waarom er eerst een kaal Android-app-project bij kwam

Zonder een echte Android-`application`-module kan Kotlin/Room-code wel
geschreven, maar niet gebouwd of getest worden — `swift test`/`skip test`
draaien alleen de Swift-getranspileerde package, niet met de hand geschreven
Kotlin. Gerd-Jan koos ervoor dit kale app-projectje nu al op te zetten (een
klein stukje van fase 4 naar voren getrokken) zodat de opslaglaag hieronder
ook echt getest kon worden, in plaats van blind Kotlin te schrijven.

### Wat er staat

Nieuwe map **[`Android/`](../Android)** in de repo-root: een eigen, met de
hand opgezet Gradle-project (bewust NIET gegenereerd via `skip init
--transpiled-app`, want dat genereert er ook een eigen Xcode-project bij —
dat zou een tweede, parallelle iOS-app naast `SquashAnalyzer.xcodeproj`
betekenen, wat haaks staat op "één codebase"). Dit raakt
`SquashAnalyzer.xcodeproj` en `Packages/SquashAnalyzerCore` op geen enkele
manier — geverifieerd met `git status` en een schone `xcodebuild
test -skipPackagePluginValidation` na afloop.

- **`Android/app`**: één Android-`application`-module.
  - `MainActivity.kt`: een kale placeholder (`TextView` met "Squash Analyzer
    — Android (fase 3: opslag)"). Geen echt scherm — dat is fase 4.
  - `data/MatchEntities.kt`: Room-`@Entity`-tabellen `matches`/`games`/
    `points`/`lets`, met foreign keys (`onDelete = CASCADE`) die de
    SwiftData-relaties (`SavedMatch` → `SavedGame` → `SavedPoint`/`SavedLet`)
    spiegelen. Elk enum-veld (Player, PointType, ShotType, CourtZone,
    MatchStatus) staat als de rauwe string-waarde erin, exact zoals SwiftData
    dat ook al deed — zodat een record er op beide platforms hetzelfde
    uitziet, mocht er ooit synchronisatie komen.
  - `data/MatchRecord.kt`: platte, Room-onafhankelijke `MatchRecord`/
    `GameRecord`/`PointRecord`/`LetRecord` — de Kotlin-tegenhanger van
    `Match`/`Game`/`Point`/`LetCall`. `MatchStore` neemt en geeft altijd
    deze, nooit de Room-entities rechtstreeks (dezelfde reden waarom
    `MatchRepository` op iOS `Match` neemt, niet `SavedMatch`).
  - `data/MatchDao.kt` + `AppDatabase.kt`: Room-boilerplate. De
    `@Transaction upsertMatchWithChildren` vervangt alle kind-records in één
    transactie — dezelfde aanpak als `SwiftDataMatchRepository.upsert`
    ("A match contains few records...").
  - `data/MatchStore.kt`: de vier `MatchRepository`-bewerkingen, met
    JSON-encoding voor de `coachingFocus`-stringlijsten (`org.json`, net als
    Foundation's `JSONEncoder` op iOS voor vergelijkbare velden).
  - `data/MatchStoreTest.kt`: 6 Robolectric-tests op een in-memory
    Room-database — round-trip van match+games+points+lets, "replace niet
    accumuleren" bij een tweede upsert, `mostRecentInProgressMatch` die
    completed/abandoned negeert en de laatste op `updatedAt` pakt,
    `markAbandoned`, en cascade-delete. **Alle 6 groen.**
- **Alleen coach-matches (`Match`/`Game`/`Point`/`Let`)** zijn overgezet.
  `SavedPlayer`, `SavedBadgeAward` en `SavedRefereeMatch` zijn nog niet in
  Android-vorm gegoten — dat komt bij de features die ze nodig hebben in
  fase 5 (Spelers, badges, scheidsrechter).

### Draaien

```bash
cd Android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew testDebugUnitTest   # Room/Robolectric-tests, geen emulator nodig
./gradlew assembleDebug       # bouwt de kale placeholder-app
```

**Gebruik expliciet de Android Studio JBR (JDK 21) als `JAVA_HOME`, niet het
systeem-Homebrew-openjdk (27).** Met JDK 27 compileert alles nog wel, maar
Robolectric's ASM-versie in 4.16.1 kan de resulterende classfiles niet lezen
(`java.lang.IllegalArgumentException` in `ClassReader`) — dat is puur een
tool-compatibiliteitsprobleem met een hele nieuwe JDK, niet iets in onze
code. `local.properties` (Android-SDK-pad) is machine-specifiek en bewust
niet gecommit (zie `Android/.gitignore`).

### Twee Gradle/Kotlin-eigenaardigheden voor de volgende keer

1. **AGP 9's ingebouwde Kotlin-ondersteuning (`android.builtInKotlin=true`,
   de default) is nog niet compatibel met KSP.** Room heeft KSP nodig voor
   zijn annotation processor. `Android/gradle.properties` zet daarom
   `android.builtInKotlin=false` én `android.newDsl=false` (die twee horen
   bij elkaar) en het app-module past de klassieke
   `org.jetbrains.kotlin.android`-plugin toe. Zodra KSP dit ondersteunt, is
   dit een opruimtaak (en dan kan `kotlinOptions { jvmTarget = ... }` ook
   weer terug, zie hieronder).
2. **De verouderde `android.kotlinOptions { jvmTarget = ... }`-DSL is nu een
   harde compile-fout, geen waarschuwing meer.** Vervangen door een
   `tasks.withType<KotlinJvmCompile>().configureEach { compilerOptions { ... } }`-
   blok in `app/build.gradle.kts` (dezelfde vorm die Skip's eigen
   gegenereerde `build.gradle.kts` voor `SquashAnalyzerCore` ook gebruikt).

## Fase 4 — Eerste echte scherm (AFGEROND, 2026-09-27)

Gekozen: het **startscherm met de vier tegels**. De Android-placeholder is
vervangen door een SwiftUI-scherm dat via Skip naar Compose transpileert.

### Gedeelde UI, bestaande iOS-acties

- Nieuw lokaal package `Packages/SquashAnalyzerUI`, met `skip-ui` en het
  `skipstone`-plugin. `HomeMenuHeader` en `HomeMenuTiles` zijn de gezamenlijke
  SwiftUI-componenten voor iOS én Android. De warme kleuren, afgeronde tegels,
  typografie en labels volgen het bestaande iOS-startscherm.
- Het bestaande iOS-`HomeView` gebruikt deze componenten. De Mijn team-kaart,
  coach- en scheidsrechtersetup, geschiedenis, spelersbeheer en instellingen
  blijven aan dezelfde iOS-acties gekoppeld. Het package is op projectniveau
  geregistreerd en expliciet aan app én testtarget gelinkt.
- `AndroidHomeView` is de Android-compositie in datzelfde Swift-package:
  donkere achtergrond, kop met instellingen, vier tegels en een korte melding
  over de functies die nog volgen. Elke tegel en de instellingenknop opent
  een sluitbare beschikbaarheidsmelding. Er wordt nog geen wedstrijd gestart.
- Mijn team en de echte bestemmingen volgen in fase 5. Dit is dus een werkend
  startscherm, nog geen volledige Android-versie van de app.
- De Android-`MainActivity` bevat alleen de lifecycle/Compose-host;
  `SquashApplication` initialiseert SkipFoundation. Er is geen tweede
  handgeschreven Kotlin-versie van het startscherm.

### Bouwkoppeling en aandachtspunten

`Android/settings.gradle.kts` voert eerst `swift build` uit voor het UI-package
(incrementeel), en neemt de door Skip gegenereerde Gradle-build op als
composite build. `app` gebruikt `squash.analyzer.ui:SquashAnalyzerUI` als
library. Dit werkt met het bestaande Xcode-project; er is geen tweede
Xcode-project of nieuw iOS-app-target aangemaakt.

- Ook de opgenomen Gradle-build moet het Android-SDK-pad kennen. De lokale,
  niet-gecommitte `Android/local.properties` wordt daarom naar zijn tijdelijke
  buildmap gekopieerd. Als alternatief kan `ANDROID_HOME` worden ingesteld.
- Blijf **Android Studio JBR / JDK 21** gebruiken voor Gradle en Room-tests.
  De Skip-modules gebruiken hun gegenereerde AGP-configuratie; de bestaande
  KSP-uitzondering blijft beperkt tot de Android-host.
- Skip heeft geen standaardmapping voor `hand.raised.fill`,
  `clock.arrow.circlepath` en `person.2.fill`. Kleine eigen SwiftUI-vectorpaden
  leveren de Android-symbolen onder `#if SKIP`; iOS behoudt SF Symbols.
- De Android-host gebruikt Skip `PresentationRoot` en saveable state voor
  correcte safe areas, dialogs en hercreatie van de activity.
- De instrumentatietests gebruiken expliciet Espresso 3.7.0: de oudere
  transitieve versie gebruikt een verwijderde `InputManager.getInstance`-API
  op Android 16. Zie de [AndroidX Test release notes](https://developer.android.com/jetpack/androidx/releases/test#espresso-3.7.0).
- Skip exporteert ook AndroidX-testbibliotheken transitief. De app-dependency
  sluit de groepen `androidx.test`, `androidx.test.ext` en
  `androidx.test.espresso` uit; tests krijgen hun eigen expliciete dependencies.
  Anders ontbreken klassen in het aparte ActivityScenario-bootstrapproces,
  ondanks geslaagde tests, met crashes en lange wachttijden als gevolg.
- De nieuwe package en Xcode dependency lockfiles worden bijgehouden;
  `.build` en gegenereerde Kotlin blijven buiten git.

### Verificatie / lokaal draaien

```bash
cd Android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :app:assembleDebug :app:testDebugUnitTest
# Met een draaiende emulator of verbonden Android-toestel:
./gradlew :app:connectedDebugAndroidTest
./gradlew :app:installDebug
~/Library/Android/sdk/platform-tools/adb shell am start -n com.squashanalyzer.android/.MainActivity
```

`HomeScreenTest` test de getranspileerde UI; de tegel Spelers opent de echte
directory. `PlayerScreenTest` maakt een speler aan, bewaart focus en notities,
herstart de activity, bewerkt en verwijdert de speler. De opslagtests testen
Room-migratie, sortering, dubbele namen, blanco namen en het bewaren van
wedstrijdhistorie.

Volledig geverifieerd op 2026-09-27 met Android Studio JBR (JDK 21) als
`JAVA_HOME`: `:app:assembleDebug` groen, `:app:testDebugUnitTest` 11/11 groen,
`:app:connectedDebugAndroidTest` 3/3 groen op een lokale emulator
(`Medium_Phone_API_36.1`). Zie de status bovenaan dit document voor de ene
echte fout die daarbij naar boven kwam (Skip's `ScrollView` mist
scroll-semantics voor Compose UI-tests) en de fix.

## Fase 5 — Spelers (AFGEROND EN GEVERIFIEERD, 2026-09-27)

`SquashAnalyzerCore` bevat `PlayerProfile`, coachingfocus-tags en het async
`PlayerProfileStore`-protocol. `SquashAnalyzerUI` bevat de gedeelde directory,
editor en velden voor naam, coachingfocus en notities. Via Skip wordt dit naar
Kotlin/Compose vertaald. iOS gebruikt dezelfde velden en behoudt foto-, badge-
en teamimport.

Android gebruikt een Room `players`-tabel met databaseversie 2 en een expliciete
1→2-migratie. `RoomPlayerStore` is de Android-opslagimplementatie. IDs blijven
stabiel, sortering is op naam, aanpassen bewaart bestaande metadata, verwijderen
laat wedstrijdhistorie intact en lege namen worden geweigerd. Foto's,
badgecatalogus en teamimport volgen later.

## Fase 5 — `CourtView` gedeeld en geverifieerd (AFGEROND, 2026-09-27)

`CourtView` (coach-modus' interactieve baandiagram — het stuk met eigen
`Path`-tekenwerk, gradients en een tap-gesture, al vanaf fase 0 aangemerkt als
het hoogste transpile-risico in de app) is overgezet naar
`Packages/SquashAnalyzerUI` en getranspileerd naar Compose. **Drie echte
Skip-bugs gevonden en gefixt** — geen van drie was zichtbaar in `swift build`
alleen, pas bij het Kotlin-compileren en/of écht draaien op de emulator:

1. **Skip's gesynthetiseerde memberwise-init nam een `@State`-property mee
   als constructor-argument**, iets wat Swift's eigen memberwise-init altijd
   uitsluit. `ZoneTapArea(zone:playerColor:onTap:)` kreeg er zo een vierde,
   verplichte `isPressed: Boolean`-parameter bij in de Kotlin-constructor,
   waardoor een trailing closure op de aanroepplek (bedoeld voor `onTap`)
   per ongeluk op `isPressed` terechtkwam
   ("Argument type mismatch: actual type is 'Function0<Unit?>', but
   'Boolean' was expected"). **Fix:** een expliciete `init` op elke SwiftUI-
   struct met een `@State`-property zodra die struct ook door iets anders
   dan zichzelf geïnstantieerd wordt met een trailing closure — laat Skip
   nooit de memberwise-init synthetiseren voor zo'n type.
2. **Een tap-closure die een `let` uit een geneste `ForEach`-loop
   vastlegt, gaf op Android de verkeerde waarde terug** (elke tik meldde
   dezelfde — verkeerde — zone, ongeacht welke cel was aangeraakt).
   **Fix:** geef de callback het getikte item als parameter mee
   (`onTap: (CourtZone) -> Void`) zodat de kindview zijn EIGEN, altijd
   correcte, opgeslagen property doorgeeft (`onTap(zone)` met `self.zone`)
   in plaats van dat de aanroeper een lus-lokale `let` laat vastleggen in de
   closure. Vuistregel: geef bij herhaalde child-views (ForEach) de waarde
   altijd terug via een closure-parameter, nooit via capture van de
   loop-variabele.
3. **Modifier-volgorde bepaalt of `.accessibilityLabel(...)` de juiste
   (kleine, per-cel) bounds krijgt, of de bounds van een voorouder-container
   overneemt.** Met `.frame().position().accessibilityLabel()` rapporteerde
   Compose voor ALLE negen zones exact dezelfde (te grote) bounds — zichtbaar
   via `compose.onRoot().printToLog(...)`, waar elk "Zone X"-node dezelfde
   `(26,104)-(1054,1669)`-bounds had terwijl zijn kind-node wél de juiste
   per-cel bounds toonde. Omdat Compose UI Testing's `performClick()` het
   midden van de gerapporteerde bounds gebruikt, tikte de test altijd op het
   midden van de hele 3×3-grid (dat toevallig binnen de Midden-Midden-cel
   viel), ongeacht welke zone was opgevraagd. De echte layout/rendering was
   dus altijd correct — dit trof alleen semantics/toegankelijkheid (en
   daarmee ook UI-tests en TalkBack). **Fix:** `.accessibilityLabel(...)`
   vóór `.frame()`/`.position()` zetten. Vuistregel: zet
   `.accessibilityLabel` direct op de view zelf, niet na frame/position-
   modifiers, zeker bij absoluut gepositioneerde grid-cellen.

`CourtView` is verplaatst zonder dat het van `Game` (app-only, `@Observable`)
afhangt: de publieke API is teruggebracht tot `isInteractive: Bool` en
`selectedPlayer: Player?` (beide al puur/gedeeld), dus geen omweg nodig om
`Game` zelf ook maar deels te delen. `ContentView.swift` roept `CourtView`
nu aan met `isInteractive: currentGame.scoringStep == .selectZone,
selectedPlayer: currentGame.selectedPlayer` in plaats van `game: currentGame`.

**`CourtViewTest.kt`** (nieuw, `Android/app/src/androidTest`) monteert
`CourtView` los van `MainActivity`/`AndroidHomeView` (coach-modus heeft nog
geen eigen Android-scherm — dat is de volgende stap), via `createComposeRule()`
+ hetzelfde `PresentationRoot`/`ComposeContext`-patroon als `MainActivity`.
Dit vereiste ook `debugImplementation("androidx.compose.ui:ui-test-manifest")`
in `app/build.gradle.kts` (zonder die dependency heeft `createComposeRule()`
geen host-`ComponentActivity` om in te starten: "Unable to resolve activity
for ... ComponentActivity"). Test dekt: negen zones renderen en tikbaar zijn,
tik meldt de juiste zone terug, en niet-interactieve modus toont geen zones/
instructietekst.

Geverifieerd: `swift build`/Kotlin-compile van het package groen,
`:app:testDebugUnitTest` (11/11) en `:app:connectedDebugAndroidTest` (5/5,
incl. de 2 nieuwe CourtView-tests) groen op de emulator, `skip test` 15/15
op Darwin en Android, en de volledige iOS-testsuite
(`xcodebuild test -skipPackagePluginValidation`) groen — `CourtView` is uit
de app verwijderd en volledig vervangen door de gedeelde versie, geen
gedragsverandering op iOS.

## Fase 5 — Coach-modus scoren (AFGEROND, 2026-09-27)

Coach-modus' volledige score-tap-flow (het standaard invoerpatroon — zie de
memory-notitie "coach default is 'Tik op de score'") draait nu écht op
Android: speler kiezen (tik op score) → puntsoort → zone (`CourtView`) →
slag, met undo en game/match-einde. Bewust een kleinere set dan iOS'
`ContentView.swift`: geen quick-entry, geen lets, geen coachingnotities,
badges, vorige-game-analyse of share sheet — dezelfde soort scope-cut als
Spelers zonder foto's/badges/team-import in fase 5.

### Wat er gedeeld is

- **`Game`, `Match`, `Point`, `LetCall`, `ServerSide`, `MatchStatus`**
  verhuisd naar `SquashAnalyzerCore` (waren app-only in `SquashAnalyzer/Models`).
  Alle drie waren al 100% puur (`Foundation` + eigen Core-types, geen
  SwiftData/UIKit), dus dit was een rechttoe-rechtaan Fase-1-achtige
  verplaatsing: `public` overal, expliciete inits waar nodig, dubbels uit de
  app verwijderd (`Game.swift`, `Match.swift`, `Point.swift`, `Let.swift`),
  `import SquashAnalyzerCore` toegevoegd waar het ontbrak
  (`MatchRepository.swift`, `PersistenceSchema.swift`). `~34` app-bestanden
  hadden het al via eerdere fases.
- **`ServiceSideSelector`, `ServerIndicator`** verhuisd naar
  `SquashAnalyzerUI` (waren resp. in `RefereeView.swift` en
  `DesignSystem.swift`) — nu de ENIGE versie, ook door iOS' referee- en
  coachscherm gebruikt (geen duplicaat meer op geen van beide platforms).
  **`PlayerAvatarPlaceholder`** (nieuw, gedeeld): het "geen foto"-pad van
  iOS' `PlayerAvatarImage`, want de echte `PlayerAvatar` leunt op een
  SwiftData `@Query` en kan niet mee — zelfde foto-scope-cut als Spelers.
- **`PointTypeButton`/`FistIcon`, `ShotTypeSelectorView`/`ShotTypeButton`**
  (nieuw, gedeeld): net als bij `CourtView` moesten de drie custom
  slag-iconen (Drive/Lob/Boast) van `Canvas` naar `Path` + `.stroke()` —
  Skip heeft geen `Canvas` (zie Fase 4). Dezelfde coördinaten, alleen
  declaratief in plaats van imperatief getekend.
- **`SharedScoreboardView`, `CoachScoringView`** (nieuw, gedeeld): de
  orchestratie van de score-tap-flow, zie hierboven.

### Drie nieuwe, echte Skip-bugs (bovenop de drie uit de `CourtView`-stap)

1. **`SquashAnalyzerCore` had geen `skip-model`-dependency.** Zolang niets in
   het package `@Observable` gebruikte kwam dit niet aan het licht (`Game`
   en `Match` waren de eersten). Zonder de dependency resolveert
   `import skip.model.*` in de gegenereerde Kotlin naar niets
   ("Unresolved reference 'model'"/'wrappedValue'"), specifiek in de
   `SquashAnalyzerCoreTests`-Gradle-aggregatie (de losse `swift build`-variant
   miste 'm ook stil, zonder het meteen te melden). **Fix:**
   `.package(url: ".../skip-model.git", ...)` + `.product(name: "SkipModel", ...)`
   toegevoegd aan `Package.swift`.
2. **Een `@Observable`-klasse heeft `import Observation` nodig in het
   bestand zelf**, ook al compileert het zonder in Swift (via impliciete
   beschikbaarheid). Zonder die import genereert Skip voor DIE klasse een
   ander (ouder?) backing-mechanisme (`skip.model.Observed<T>` met expliciete
   property-wrappers) in plaats van het gebruikelijke
   `androidx.compose.runtime.mutableStateOf`-pad, en dat eerste pad mist dan
   zelf weer de juiste `import skip.model.*`-regel in zijn eigen
   gegenereerde bestand. **Vuistregel: zet `import Observation` in elk
   bestand met een `@Observable`-klasse, punt uit.**
3. **Een property en een gelijknamige methode botsen op JVM-niveau.**
   `Game.startingServer: Player` (property) en `Game.setStartingServer(_:)`
   (methode) transpileerden allebei naar een JVM-signatuur
   `setStartingServer(Player)V` — Kotlin's automatische bean-setter voor de
   property botst met de expliciete methode ("Platform declaration clash").
   Dit bestond al vóór de verhuizing maar kwam pas aan het licht zodra `Game`
   getranspileerd werd. **Fix:** de methode hernoemd naar
   `assignStartingServer(_:)`. **Vuistregel: op Kotlin/JVM mag een methode
   nooit `set<PropertyName>` heten als er ook een property `<propertyName>`
   bestaat.**

Daarnaast, in de nieuwe gedeelde UI zelf:

4. **Ternaire expressies met integer-literals in beide takken verliezen hun
   `Double`-type**, zelfs waar een los literal op dezelfde plek wél goed
   zou gaan. `.font(.system(size: compact ? 8 : 9, ...))` gaf
   "Argument type mismatch: actual type is 'Int', but 'Double' was
   expected" — de conditie zelf (niet de context) breekt de
   type-doorgifte. Trof zeven plekken in de nieuwe bestanden (padding,
   spacing, lineWidth, opacity). **Vuistregel: schrijf bij een ternaire
   `Double`/`CGFloat`-waarde ALTIJD `.0` op beide takken, ook als een van de
   twee al een expliciet decimaal getal is** (`isScoring ? 0.7 : 0` faalde
   ook, ondanks dat Swift dit zelf al als `Double` unificeert vóór transpile).
5. **Een `Button` binnen een `if let optionalClosure { Button(...) } else { column }`-
   vertakking kreeg een geldig ogende semantics-node (`OnClick` stond in de
   boom) waarvan de klik-actie nooit de echte handler aanriep** — noch via
   Compose's `performClick()`, noch via `performTouchInput { click() }` op
   diezelfde node of op exact dezelfde coördinaat via `onRoot()`. Een
   handmatige tik op precies dezelfde plek op het draaiende toestel werkte
   wél. **Fix:** zoals bij `CourtView`'s `onTap: onZoneTapped ?? { _ in }` —
   nooit een Button conditioneel tussen twee takken opsplitsen; altijd één
   vaste `Button` met een optioneel aangeroepen closure
   (`onSelectPlayer?(player)` / `guard let onSelectPlayer else { return }`).
   De scorekolommen in `SharedScoreboardView` zijn daarna nog verder
   vereenvoudigd: de spelerkolom bevat nu alleen een score-`Button`, en de
   servicekant-selector is geen geneste knop meer. Daarmee is ook de
   geautomatiseerde scoreklik betrouwbaar geworden.

### Handmatig geverifieerd op de emulator (Medium_Phone_API_36.1)

Volledige flow met screenshots gecontroleerd: Home → Coach → tik score
Speler 1 → puntsoort WINNER → zone (via `CourtView`, correct herkend als
"Voor Links") → slag DRIVE → score wordt 1–0, service wisselt correct naar
"Links". `PointTypeButton`'s Path-iconen (WINNER=ster, STROKE=vuist) en
`ShotTypeButton`'s Path-iconen (Drive/Lob/Boast) renderen allemaal correct.

**Drie SF Symbols vallen terug op een generiek waarschuwingsdriehoekje**
(niet leeg, wel niet het bedoelde icoon): `arrow.triangle.2.circlepath`
(Forced error), `xmark.circle` (Unforced error), `figure.tennis`
(Servicepunt) — én, onverwacht, ook een paar simpele shot-iconen:
`arrow.left.and.right` (Cross), `bolt.fill` (Volley),
`arrow.down.to.line` (Drop). Skip's ingebouwde SF Symbol-dekking is dus
kleiner dan voorheen aangenomen. Puur cosmetisch (de tekstlabel blijft
duidelijk leesbaar, niets is onklikbaar) — bij gelegenheid eigen
`Path`-iconen toevoegen voor deze zes, net als eerder gedaan voor
`hand.raised.fill`/`clock.arrow.circlepath`/`person.2.fill` in
`HomeMenu.swift`.

### Teststatus van de scoreklik

De scoreklik is inmiddels wel automatisch gedekt. `CoachPersistenceTest`
gebruikt `androidx.compose.ui.test.junit4.v2.createAndroidComposeRule`, opent
Coach, hervat een opgeslagen wedstrijd, scoort via **Punt voor CoachTest** en
**SERVICEPUNT**, sluit met **Bewaar & sluit**, herstart de Activity, hervat
opnieuw en controleert dat undo ook duurzaam is.

### Geverifieerd

`:app:testDebugUnitTest` (11/11), `:app:connectedDebugAndroidTest` (5/5,
`CourtViewTest` blijft de automatische dekking voor het risicovolste
tekenwerk), `skip test` (15/15 op Darwin en Android), volledige iOS-testsuite
(`xcodebuild test -skipPackagePluginValidation`) — allemaal groen. Geen
gedragsverandering op iOS; `Game`/`Match`/`Point`/`LetCall` heten en werken
overal exact hetzelfde, nu vanuit een ander (gedeeld) module.

## Fase 5 — Coachwedstrijden opslaan en hervatten (2026-09-27)

De Coach-tegel opent nu `CoachSessionView`. Die zoekt eerst een lopende wedstrijd.
Bij een gevonden wedstrijd kies je **Hervatten** of **Nieuwe wedstrijd**.
Een nieuwe wedstrijd beginnen vereist bevestiging: de vorige blijft als
afgebroken wedstrijd bewaard. Zonder lopende wedstrijd wordt een nieuwe aangemaakt
en direct opgeslagen. **Bewaar & sluit** bewaart de huidige stand en keert terug
naar home. Een afgeronde wedstrijd blijft opgeslagen, maar wordt niet meer als
lopend aangeboden. Het terugkijken van die wedstrijden volgt met de geschiedenis.

- Gedeeld Swift-protocol `CoachMatchStore`, met laden, opslaan en afbreken.
- Android `RoomCoachMatchStore` vertaalt de gedeelde `Match`/`Game`/`Point`/
  `LetCall` naar de al bestaande `MatchStore`; er is geen tweede wedstrijdopslag.
- Elk punt, undo, servicekant-aanpassing en overgang naar de volgende game wordt
  opgeslagen. De UI wacht op een afgeronde opslagactie voordat er verder gescoord
  kan worden. Bij een fout blijft de stand zichtbaar en kun je opnieuw proberen.
- Room versie **3**, expliciete migratie **2→3** naast **1→2**. Eén optioneel
  `serviceState`-veld per game bewaart Links/Rechts en hand-outvoorkeuren.
  Oudere games zonder dit veld gebruiken de bestaande serviceherstelregel.
- Wedstrijd-, game-, punt- en speler-IDs blijven behouden. `savedAt` blijft de
  oorspronkelijke datum; `updatedAt` verandert bij opslaan. Geen duplicaten na
  herhaald opslaan. Tijd terwijl de app gesloten is telt niet als rallyduur.
- Hervatten herstelt de laatste game, ook als die net afgelopen is; de volgende
  game wordt pas aangemaakt via **VOLGENDE GAME**. Afgeronde en afgebroken
  wedstrijden worden niet opnieuw aangeboden voor hervatten.

De nieuwe `CoachMatchStoreTest` verifieert een echte database-close/reopen, scores,
IDs, metadata, servicevoorkeuren, undo na hervatten, gamegrenzen, completed/
abandoned-status en migratie met bestaande spelers en wedstrijden. De bestaande
speler-migratietest verifieert nu ook de volledige 1→2→3-route.

Actuele verificatie:

- `:app:testDebugUnitTest`: 15/15 groen.
- `:app:connectedDebugAndroidTest`: 6/6 groen, inclusief de nieuwe
  `CoachPersistenceTest`.
- `skip test --project Packages/SquashAnalyzerCore`: 15/15 groen op Darwin en
  15/15 groen op Android.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: 72/72 groen.

## Fase 5 — Scheidsrechtermodus (AFGEROND, 2026-09-27)

De Scheidsrechter-tegel opent nu `RefereeScoringView`, een gedeeld
SwiftUI-scherm in `SquashAnalyzerUI` (net als `CoachScoringView` hergebruikt
het `ServiceSideSelector`, `ServerIndicator` en `PlayerAvatarPlaceholder`).
De scoringlogica zit in het nieuwe `RefereeMatch` in `SquashAnalyzerCore`
(`@Observable`, met dezelfde `undoStack`-aanpak als `Match`/`Game`): punt
toekennen per tik op een spelerscore, LET (geen puntwijziging, alleen een
tijdelijke call-melding), STROKE (telt wel als punt, met call-melding),
volledige undo, servicekant-override, en game-wissel via **VOLGENDE GAME**.

- Android-test `RefereeScreenTest` dekt de hoofdflow: punt scoren, undo, LET
  aanroepen, en teruggaan naar home. Er zijn twee "LET"-knoppen zichtbaar (één
  per speler/kant); de test gebruikt `onAllNodesWithText("LET").onFirst()`
  omdat een simpele `onNodeWithText` faalt zodra meerdere nodes matchen.
- Geen nieuwe Skip-transpile-bugs gevonden tijdens deze stap — `RefereeMatch`
  volgt hetzelfde `@Observable`/`import Observation`-patroon dat al eerder is
  vastgesteld voor `Game`/`Match`, en de UI hergebruikt bestaande, al
  gevalideerde gedeelde componenten.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen.
- `:app:connectedDebugAndroidTest`: 7/7 groen, inclusief de nieuwe
  `RefereeScreenTest`.
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen (badges-suite via Gradle).
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED**.

## Fase 5 — Scheidsrechterwedstrijden opslaan en hervatten (AFGEROND, 2026-09-27)

Zelfde patroon als coach-modus' opslagstap: een nieuw `RefereeMatchStore`-
protocol in `SquashAnalyzerCore` (`loadInProgress`/`save`/`abandon`, exact
dezelfde vorm als `CoachMatchStore`), een nieuwe gedeelde `RefereeSessionView`
in `SquashAnalyzerUI` (kopie van `CoachSessionView`'s hervatten/nieuwe-
wedstrijd/busy/failed-logica, nu over `RefereeMatch`), en op Android een
`RoomRefereeMatchStore` die het protocol implementeert bovenop een eigen,
kleinere Room-laag (`RefereeMatchEntity`/`RefereeGameEntity`/
`RefereePointEntity`/`RefereeCurrentPointEntity`, Room-schema **4**, migratie
**3→4**). Simpeler dan de coach-tabellen: geen puntsoort/zone/slag-kolommen,
alleen wie scoorde, de servicekant en of de rally een stroke was
(`RefereePointEntry`'s daadwerkelijke velden). De Scheidsrechter-tegel opent
nu `RefereeSessionView(store: refereeMatchStore, ...)` in plaats van steeds
een losse `RefereeMatch()` te maken; `RefereeScoringView` kreeg er een
`onMatchChanged`-callback bij (zelfde rol als `CoachScoringView`'s) om na elke
mutatie een save te triggeren.

- **Bekende beperking, geaccepteerd**: `RefereeMatch.undo()` pop't een
  privé, alleen-in-memory undo-stack (in tegenstelling tot `Game`/`Match`,
  waar undo altijd herberekent vanuit de opgeslagen puntenlijst). Die stack
  wordt niet meegepersisteerd. Een hervatte wedstrijd kan dus alleen punten
  ongedaan maken die in de huidige, live sessie zijn gescoord — niet iets van
  vóór een herstart (`canUndo` is dan simpelweg `false`, de Undo-knop is
  uitgeschakeld). Dit is een bestaande eigenschap van `RefereeMatch`, niet
  iets dat deze opslagstap heeft geïntroduceerd; `RefereeMatchStoreTest`
  documenteert dit expliciet in plaats van een verkeerde verwachting te
  testen.
- Nieuwe tests: `RefereeMatchStoreTest` (Robolectric, mirroring
  `CoachMatchStoreTest`: resume na her-openen db, servicekant/voorkeuren,
  game-grens via `confirmNextGame()`, completed/abandoned nooit hervatbaar,
  en de 3→4-migratie), `RefereePersistenceTest` (instrumented, mirroring
  `CoachPersistenceTest`: score overleeft een `activityRule.scenario.recreate()`,
  en een aparte test dat undo binnen dezelfde sessie wél persisteert).
  `RefereeScreenTest` kreeg een opruimstap (`refereeMatchDao().deleteAll()`
  voor/na) omdat een leftover wedstrijd anders het hervat-scherm toont in
  plaats van direct te scoren.
- Handmatig geverifieerd op de emulator: punt scoren → Sluiten → app killen
  → herstarten → Scheidsrechter-tegel toont "Wedstrijd hervatten" met de
  juiste stand (`Game 1 · 1 – 0`) → Hervatten laadt de score correct terug.
- Geen nieuwe Skip-transpile-bugs; wel één Kotlin-valkuil (geen Skip-bug):
  `match.completedGames.map { ... }` (zonder index) resolvet naar
  `skip.lib.Array`'s eigen `map`, niet Kotlin's `Iterable.map`, en levert dus
  geen `List` op waar een Room-DTO dat verwacht ("Argument type mismatch").
  `.mapIndexed { _, item -> ... }` (zoals de bestaande coach-code al overal
  gebruikte) roept wél de Kotlin-stdlib-variant aan. **Vuistregel**: gebruik
  op een getranspileerde Swift-`Array` altijd `.mapIndexed` in plaats van
  `.map`, ook als de index niet nodig is.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen, inclusief nieuwe `RefereeMatchStoreTest`
  en (na een fix) de bestaande `CoachMatchStoreTest`/`PlayerStoreTest` — die
  moesten ook `MIGRATION_3_4` in hun `addMigrations(...)` krijgen, anders
  faalt hun handmatige downgrade-naar-v2-migratietest met "A migration from
  2 to 4 was required but not found" nu de db-versie 4 is.
- `:app:connectedDebugAndroidTest`: 9/9 groen, inclusief `RefereePersistenceTest`.
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED**.

## Fase 5 — Badges-UI: alleen de catalogus (AFGEROND, 2026-09-27)

Kleinste zinnige eerste plak van "badges-UI", zelfde aanpak als coach-/
scheidsrechtermodus: eerst het stuk zonder afhankelijkheden bouwen, daarna
pas de kant met echte spelersdata. `BadgeEngine`/`BadgeKind` stonden al
100% puur in `SquashAnalyzerCore` en draaiden al via `skip test` (15/15) —
daar is niets aan veranderd. Wat wél nieuw is:

- **`Match.badgeInput`/`rallyWinners` en `RefereeMatch.badgeInput`/
  `rallyWinners`** verhuisd van `SquashAnalyzer/Services/BadgeEngine.swift`
  (app-only) naar `Packages/SquashAnalyzerCore/Sources/SquashAnalyzerCore/BadgeInput.swift`
  — waren al 100% puur, dus een rechttoe-rechtaan verplaatsing (net als
  `Game`/`Match`/`Point`/`LetCall` eerder). De app-file is nu een verwijzende
  stub, zelfde patroon als `RefereeMatch.swift`.
- **`BadgeMedallion`** (nieuw, gedeeld, in `SquashAnalyzerUI`): vervangt
  iOS' `BadgeView` voor Android — Android heeft geen badge-artwork (geen
  `UIImage(named:)`-pad), dus dit rendert altijd het gouden medaillon met
  een SF Symbol-fallback. Zelfde scope-cut als `PlayerAvatarPlaceholder`
  voor spelersfoto's.
- **`SharedBadgeCatalogView`** (nieuw, gedeeld): de volledige badge-catalogus
  (alle 31 badges, geen speler- of award-data nodig, dus zonder enige setup
  bereikbaar). Bewust **niet** `BadgeCatalogView` genoemd: de iOS-app heeft
  al een eigen `BadgeCatalogView` met echte artwork-pogingen
  (`SquashAnalyzer/Views/PlayerBadgesView.swift:325`), en beide types zouden
  botsen zodra `SquashAnalyzerUI` en dat app-bestand allebei in scope zijn.
- **`HomeMenuTiles` kreeg een vijfde tegel ("Badges")** — dit component is
  al gedeeld tussen iOS' `HomeView` en Android's `AndroidHomeView`, dus de
  tegel verschijnt nu op **beide platforms**. Op Android opent hij de nieuwe
  `SharedBadgeCatalogView`; op iOS opent hij de bestaande, eigen
  `BadgeCatalogView` in een sheet (`HomeView.swift`) — een kleine, bewuste
  toevoeging aan iOS, geen functieverlies.
- Twee nieuwe, echte Skip-bugs gevonden en gefixt:
  1. **Geneste closures met `$0`/keypath-shorthand transpileren verkeerd.**
     `games.map { $0.points.map { BadgeRally(winner: $0.scorer, ...) } }`
     (twee geneste `map`-closures die allebei `$0` gebruiken) gaf in de
     gegenereerde Kotlin `Unresolved reference 'shotType'`/`'zone'`,
     `None of the following candidates is applicable: val String.count`
     en een `Tuple2<E0,E1>.element: it is internal`-fout bij een
     `.map(\.scorer)`-keypath. Fix: named closure-parameters overal in plaats
     van `$0` zodra een closure een andere closure bevat die ook `$0`
     gebruikt (`game.points.map { point in ... }` i.p.v. `game.points.map { ... $0 ... }`),
     en keypaths (`\.scorer`) vervangen door `{ point in point.scorer }`.
     **Vuistregel**: gebruik nooit `$0` in een closure die genest zit in een
     andere closure die ook `$0` gebruikt — expliciete parameter­namen altijd.
  2. **Bekende ternary/literal-gotcha (#4 uit eerdere fases) opnieuw
     geraakt**, ditmaal gekopieerd uit iOS' eigen `BadgeView.swift`:
     `.grayscale(isLocked ? 1 : 0)` en `.opacity(isLocked ? 0.35 : 1)` gaven
     "Argument type mismatch: actual type is 'Int', but 'Double' was
     expected" — gefixt met `1.0 : 0.0` en `0.35 : 1.0`. Ook een `CGFloat`
     property-default (`var size: CGFloat = 64`) moest naar `64.0`.
- Handmatig geverifieerd op de emulator: Badges-tegel op home → catalogus
  toont alle categorieën/badges met Coach/Eén-keer-labels → terug-knop keert
  terug naar home. `medal.fill` valt (zoals eerder gedocumenteerd voor andere
  SF Symbols) terug op het generieke waarschuwingsdriehoekje, dat wél
  netjes binnen het zelfgetekende gouden cirkel-medaillon verschijnt.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen.
- `:app:connectedDebugAndroidTest`: 10/10 groen, inclusief de nieuwe
  `BadgeCatalogScreenTest`.
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED** (ook na de nieuwe
  Badges-tegel op iOS' eigen homescherm).

## Fase 5 — "Kies speler" bij nieuwe wedstrijden (AFGEROND, 2026-09-27)

Voorwaarde voor echte badge-awards (Slice B uit de vorige stap): zonder een
gekozen speler-id verdient geen enkele Android-wedstrijd ooit een badge,
ongeacht hoeveel award-opslag er zou zijn. Android's coach-/scheidsrechter-
setup had helemaal geen "Kies speler"-stap — een tegel tikken maakte altijd
direct een `Match()`/`RefereeMatch()` met de hardcoded namen "Speler 1"/
"Speler 2" en `nil` speler-ids.

- **Nieuw, gedeeld `MatchSetupView`** in `SquashAnalyzerUI`: een sterk
  verkleinde versie van iOS' volledige `MatchStartView` — alleen twee
  naamvelden met een "Kies speler"-knop die een lijst van bestaande spelers
  toont (uit `playerStore.loadPlayers()`), geen "Later instappen"/head-start,
  geen coaching-focus/notities overnemen. Zelfde regel als iOS' `PickedPlayer`:
  een gekozen speler-id telt alleen mee zolang de naam nadien niet is
  aangepast (`pickedId(_:currentName:)` vergelijkt de huidige tekst met de
  naam op het moment van kiezen).
- **`CoachSessionView`/`RefereeSessionView` kregen een nieuwe `showingSetup`-
  stap**: als er niets te hervatten is, tonen ze nu eerst `MatchSetupView` in
  plaats van meteen een lege wedstrijd aan te maken en op te slaan. Pas na
  "Start" wordt de match aangemaakt (`Match().setupMatch(...)` resp.
  `RefereeMatch(player1Name:player2Name:...)`) met de opgeloste namen en
  (indien gekozen) speler-ids, en pas dan opgeslagen. Beide views kregen
  daarvoor een nieuwe `playerStore: any PlayerProfileStore`-parameter,
  doorgegeven vanuit `AndroidHomeView` (die de store al had voor het
  Spelers-scherm).
- **`PlayerProfile.id` (`String`) → `Match`/`RefereeMatch.player1Id`/
  `player2Id` (`UUID?`) bridging**: gebeurt met `UUID(uuidString:)` op het
  punt waar de wedstrijd wordt aangemaakt. Geen Core-typewijziging nodig
  (`PlayerProfile.id` is altijd een `UUID().uuidString`-vormige string, dus
  dit slaagt altijd voor spelers aangemaakt via de normale editor).
- Bewust **niet** `PlayerDirectoryView` (het bestaande Spelers-scherm)
  hergebruikt met een "pick mode" erbij — dat zou een al geverifieerd,
  gedeeld scherm aanraken voor functionaliteit die de setup-stap niet nodig
  heeft (add/edit/delete). Een nieuw, klein component is hier de veiligere
  keuze, zelfde afweging als eerder bij `PlayerAvatarPlaceholder` en
  `SharedBadgeCatalogView`.
- `RefereeScreenTest` moest een `Start`-tik krijgen vóór het scherm scoort
  (de setup-stap zit er nu tussen); `CoachPersistenceTest`/
  `RefereePersistenceTest` bleven ongewijzigd omdat die altijd een
  wedstrijd vooraf zaaien, dus meteen het hervat-scherm zien.
- Nieuwe test **`MatchSetupTest`**: zaait een echte speler in Room, doorloopt
  de UI (tegel → Kies speler → speler selecteren → Start), en verifieert via
  `RoomRefereeMatchStore.loadInProgress()` dat de opgeslagen wedstrijd zowel
  de juiste naam als de juiste (naar UUID gebridgede) speler-id heeft — het
  eerste echte bewijs dat een Android-wedstrijd voortaan badge-waardig kan
  worden aangemaakt.
- Geen nieuwe Skip-transpile-bugs.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen.
- `:app:connectedDebugAndroidTest`: 11/11 groen, inclusief de nieuwe
  `MatchSetupTest`.
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED** (`MatchSetupView` wordt
  alleen door Android's sessieviews gebruikt; iOS behoudt zijn eigen, rijkere
  `MatchStartView`).

## Fase 5 — Echte badge-awards: berekenen en opslaan (AFGEROND, 2026-09-27)

Bewust in twee stukken geknipt, net als eerdere fases: eerst opslag +
berekening (deze stap, volledig test-gedekt zonder UI, zoals `BadgeEngine`
zelf ook zonder UI getest wordt), UI om verdiende badges te *tonen* is de
volgende stap. Career-badges (`BadgeKind.isCareer`: hat trick, off the mark,
centurion, ten out of ten, nemesis, veteran) zijn bewust **buiten scope**:
die hebben wedstrijdgeschiedenis nodig (`BadgeEngine.careerBadges(in:history:...)`),
en de geschiedenisbrowser op Android bestaat nog niet — dat komt in de
volgende backlogstap.

- **Nieuwe Room-tabel `badge_awards`** (schema 5, migratie 4→5):
  `BadgeAwardEntity`/`Record`/`Dao`/`BadgeAwardStore`, zelfde
  Entity/Record/Dao/Store-patroon als coach- en scheidsrechteropslag.
  Kleiner dan iOS' `SavedBadgeAward`: geen `cardId`/`awardedBy`/
  `cloudSystemFields` (CloudKit-only, Android deelt geen kaarten), een award
  hangt direct aan een `PlayerProfile.id`. De primary key is simpelweg de
  samengestelde string `"<playerId>:<badge>:<matchId>"` — geen
  SHA-256-afgeleide UUID nodig zoals iOS' `awardId(cardId:badge:matchId:)`,
  want dit id hoeft nooit als CloudKit-recordnaam te dienen.
- **`BadgeAwardStore.syncAwards(matchId, players, input)`**: Kotlin-
  herimplementatie van `BadgeAwarder.syncAwards`'s diff-logica zonder
  CloudKit. Roept de gedeelde, pure `BadgeEngine().badges(input)` aan
  (transpileert naar `badges(for_: ...)` — Skip hangt een underscore achter
  Swift-parameterlabels die Kotlin-keywords zijn) en vervangt de
  award-rijen van die wedstrijd met precies de nu-verdiende set: nieuw
  verdiende badges worden ingevoegd/hersteld (`OnConflictStrategy.REPLACE`
  wist een eerdere `deletedAt` als een badge na undo-dan-opnieuw weer wordt
  verdiend), niet langer verdiende badges worden zacht verwijderd
  (`deletedAt` gezet) — zelfde "een teruggedraaide rally trekt de badge in"
  als op iOS.
- **Aangeroepen vanuit `RoomCoachMatchStore`/`RoomRefereeMatchStore`**, bij
  zowel `save()` als `abandon()`, na de wedstrijd-upsert. Beide stores kregen
  een verplichte `BadgeAwardStore`-parameter; `MainActivity.kt` maakt er nu
  één centrale instantie van en geeft die aan beide door.
- **Alleen spelers met een echte id verdienen iets**: `syncAwards` slaat
  meteen over (`return`) als geen van beide spelers een `player1Id`/
  `player2Id` heeft — een getypte naam zonder "Kies speler" levert nooit een
  rij op, exact de regel uit ARCHITECTURE.md.
- Nieuwe test **`BadgeAwardStoreTest`** (Robolectric, 3 tests): een
  gekozen speler verdient "5 punten op rij" bij het opslaan; een getypte
  naam (geen id) verdient nooit iets; een undo van de winnende rally trekt
  de badge weer in. Bestaande `CoachMatchStoreTest`/`RefereeMatchStoreTest`/
  `PlayerStoreTest` kregen `MIGRATION_4_5` in hun `addMigrations(...)` en een
  `BadgeAwardStore`-instantie in hun `Room*MatchStore`-constructor.
- Geen nieuwe Skip-transpile-bugs; wel de `for_`-parameterbenaming
  hierboven genoteerd als iets om op te letten bij het aanroepen van
  Swift-methodes met een `for`-labeled parameter vanuit handgeschreven
  Kotlin.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen, inclusief de nieuwe `BadgeAwardStoreTest`.
- `:app:connectedDebugAndroidTest`: 11/11 groen (geen nieuwe UI in deze
  stap, dus geen nieuwe instrumented test nodig — de bestaande dekking
  bevestigt dat niets is gebroken).
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED** (Android-only wijziging,
  geen Swift/Core/UI-bestanden aangeraakt).

## Fase 5 — Badges tonen: spelerslijst + spelerscherm (AFGEROND, 2026-09-27)

Het zichtbare vervolg op de vorige stap: badges worden nu ook getoond, niet
alleen berekend en opgeslagen.

- **Nieuw, gedeeld `PlayerBadgeSummaryStore`-protocol** in `SquashAnalyzerCore`
  (`badges(forPlayer:) -> [BadgeKind]`) — een klein, alleen-lezen venster op
  een speler's verdiende badges. Android's `BadgeAwardStore` implementeert
  dit protocol nu ook (naast zijn bestaande rol als schrijfkant voor
  `syncAwards`): `badges(forPlayer:)` haalt de actieve awards op, filtert op
  unieke badge-soorten, en zet elke raw value om naar een `BadgeKind` (skip
  Skip's parametronderscore-conventie: `func badges(forPlayer playerId:
  String)` transpileert naar `fun badges(forPlayer: String)`, dus geen
  losstaand `_`-achtervoegsel deze keer omdat er geen Kotlin-keyword-botsing
  is).
- **`PlayerDirectoryView` (het Spelers-scherm) kreeg een tweede,
  verplichte `badgeStore`-parameter**, laadt bij elke `reload()` het
  badge-aantal per speler erbij, en toont — alleen als een speler minstens
  één badge heeft — een gouden pilletje met medaille-icoon en aantal naast
  hun naam. Tikken erop navigeert naar de nieuwe wedstrijd-onafhankelijke
  weergave.
- **Nieuw, gedeeld `SharedPlayerBadgesView`**: een grid van `BadgeMedallion`s
  voor alle badges die een speler heeft verdiend, of een lege-staat-uitleg
  ("Kies \(naam) via 'Kies speler'...") als er nog niets is. Bewust **niet**
  `PlayerBadgesView` genoemd — dezelfde naamsbotsing-reden als
  `SharedBadgeCatalogView`: de iOS-app heeft al een eigen, rijkere
  `PlayerBadgesView` (verdienmomenten, kaart delen) in
  `SquashAnalyzer/Views/PlayerBadgesView.swift`.
- Geen "Badges verdiend"-strip op het game/match-einde-scherm in deze stap
  — dat raakt `CoachScoringView`/`RefereeScoringView`'s bestaande
  banners en is een aparte, iets invasievere vervolgstap; badges zijn nu wel
  overal zichtbaar waar spelers worden beheerd.
- Career-badges (hat trick, off the mark, centurion, ten out of ten,
  nemesis, veteran) worden hier bewust nog niet getoond — die hebben
  wedstrijdgeschiedenis nodig, wat de volgende backlogstap is.
- `.navigationDestination(item:)` bleek niet bruikbaar voor `PlayerProfile`
  (niet `Hashable`); opgelost met dezelfde `.navigationDestination(isPresented:
  Binding(get:set:))`-omweg die `MatchSetupView`'s speler-picker al gebruikte.
  Geen Skip-transpile-bug, gewoon een gewone SwiftUI-typebeperking.
- Nieuwe instrumented test **`PlayerBadgesScreenTest`**: zaait een speler
  plus een badge-award rechtstreeks in Room (de berekening zelf is al
  gedekt door `BadgeAwardStoreTest`), navigeert naar Spelers, verifieert het
  pilletje "1 badges van ...", tikt erop, verifieert dat de badge-titel
  ("5 points in a row") verschijnt, en gaat terug.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen.
- `:app:connectedDebugAndroidTest`: 12/12 groen, inclusief de nieuwe
  `PlayerBadgesScreenTest`.
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED**.

## Fase 5 — Geschiedenis: overzicht van afgeronde wedstrijden (AFGEROND, 2026-09-27)

De "Afgeronde wedstrijden"-tegel opent nu een echt scherm in plaats van de
placeholder-melding. Sterk verkleind t.o.v. iOS' volledige
`MatchHistoryView` (1132 regels: import/export, backup, filters, een
incomplete wedstrijd aanvullen) — alleen een lijst, geen tap-through-detail.

- **Nieuw, gedeeld `MatchHistoryStore`-protocol** in `SquashAnalyzerCore`
  (`loadHistory() -> [MatchHistorySummary]`) met een klein, platte
  `MatchHistorySummary`-record (naam, aantal games, status, datum) — geen
  volledige punt-voor-punt data, dat is bewust te veel voor een lijst.
- **`RoomMatchHistoryStore`** (Android) voegt coach- en
  scheidsrechterwedstrijden samen tot één, op datum gesorteerde lijst.
  Alleen voltooide/afgebroken wedstrijden (`status IN ('completed',
  'abandoned')`, nieuwe DAO-query op beide tabellen); lopende wedstrijden
  blijven uitgesloten. Games-gewonnen-aantallen komen rechtstreeks uit elke
  record z'n eigen gamelijst (`GameRecord.winner`/`CompletedRefereeGame.winner`),
  niet via het herstellen van een levend `Match`/`RefereeMatch`-object — een
  bewuste vereenvoudiging die head-start-games (`player1GamesBefore`) niet
  meetelt.
- **Nieuw, gedeeld `SharedMatchHistoryView`** (weer met `Shared...`-prefix,
  zelfde botsingsreden als de andere gedeelde schermen: iOS heeft al een
  eigen `MatchHistoryView`): een simpele kaartenlijst met spelernamen,
  COACH/SCHEIDSRECHTER-label, AFGEBROKEN-label waar van toepassing, datum en
  eindstand.
- **Bekende Skip-gotcha (opnieuw) vermeden, niet opnieuw geraakt**: datum-
  weergave gebruikt `DateFormatter` met een vast patroon, niet
  `Date.FormatStyle`/`.formatted(date:time:)` — die laatste heeft geen
  Android-ondersteuning in SkipFoundation, al gedocumenteerd bij
  `MatchShareReport.swift`.
- **Testfout gevonden en gefixt — in de test, niet de productiecode**: een
  eerste versie van `RoomMatchHistoryStoreTest` verwachtte dat een
  coachwedstrijd die pas na 2× `onGameEnd()` een derde game "stilzwijgend"
  wint, maar 2 games-gewonnen zou tellen. In werkelijkheid bevat
  `Match.games` de huidige game al vanaf het begin (`Game.winner` is
  berekend uit de score, niet pas gezet bij `onGameEnd()`), dus alle 3 games
  tellen al mee zodra de score dat toelaat — precies het gedrag dat de
  bestaande `CoachMatchStoreTest` ook al aantoont. Testverwachting
  gecorrigeerd naar 3, geen productiecode gewijzigd.
- `HomeScreenTest` bijgewerkt: "Afgeronde wedstrijden" uit de
  placeholder-lus gehaald (alleen "Instellingen" resteert als placeholder),
  en de activity-recreation-test gebruikt nu "Instellingen" als doel in
  plaats van "Afgeronde wedstrijden".
- Career-badges blijven bewust nog buiten scope, ook al bestaat er nu een
  geschiedenis: die vereisen `BadgeEngine.careerBadges(in:history:...)` met
  een specifieke `CareerMatch`-invoervorm die nog niet is opgebouwd uit
  `MatchHistorySummary`. Een volgende, aparte stap.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen, inclusief nieuwe `RoomMatchHistoryStoreTest`.
- `:app:connectedDebugAndroidTest`: 13/13 groen, inclusief nieuwe
  `MatchHistoryScreenTest`.
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED**.
- Handmatig op de emulator geverifieerd: lege staat toont de juiste uitleg;
  het gevulde pad (voltooide/afgebroken wedstrijd verschijnt, tikken/terug
  werkt) is grondig automatisch gedekt door `MatchHistoryScreenTest`.

## Fase 5 — "Badges verdiend"-strip op het match-einde-scherm (AFGEROND, 2026-09-27)

De laatste zichtbare stap van de badges-trits (catalogus → opslaan →
spelerslijst → **hier, direct na de wedstrijd**).

- **Nieuw, gedeeld `SharedMatchBadgesStrip`** in `SquashAnalyzerUI`: puur
  berekend, geen store nodig — de badges van een wedstrijd hangen alleen af van
  zijn eigen `badgeInput`, dus `SharedMatchBadgesStrip.earnings(player1Id:
  player1Name:player2Id:player2Name:badgeInput:)` roept rechtstreeks
  `BadgeEngine().badges(for:)` aan (dezelfde aanpak als de al bestaande
  `BadgeAwardStore.syncAwards` op Android, maar hier zonder opslag — puur
  voor weergave). Alleen spelers met een echte id (via "Kies speler") en
  minstens één verdiende badge komen in de strip. Bewust **niet**
  `MatchBadgesStrip` genoemd — dezelfde botsingsreden als de andere gedeelde
  schermen: iOS heeft al een eigen `MatchBadgesStrip`.
- **Ingehaakt in zowel `CoachScoringView.matchOverBanner` als
  `RefereeScoringView`'s match-over-blok** — verschijnt naast de bestaande
  "WINT DE WEDSTRIJD"-tekst, geen wijziging aan de game-over-banner (badges
  zijn een wedstrijd-optelling, geen per-game concept in deze weergave).
- Geen nieuwe Skip-transpile-bugs — hergebruikt dezelfde `BadgeMedallion`/
  `ScrollView`/`ForEach`-patronen die al elders gevalideerd zijn.
- **Niet volledig handmatig doorgeklikt tot een echte wedstrijd-einde-
  badge** dit keer: het toetsenbord van de emulator bleek te broos om via `adb`
  betrouwbaar een speler toe te voegen én een volledige 3-0 wedstrijd te
  scoren in één sessie. De onderliggende logica (badge-berekening,
  speler-koppeling, weergavecomponenten) is wel grondig gedekt: door
  bestaande unit tests (`BadgeAwardStoreTest`, `BadgeEngineTests`), door de
  eerder geverifieerde `SharedPlayerBadgesView`/`SharedBadgeCatalogView`
  (dezelfde `BadgeMedallion`), en door de volledige Android/iOS-testsuites
  die groen blijven met deze strip nu overal aanwezig in de renderboom.
  Aanbevolen vervolg als dit ooit twijfel oproept: een instrumented test die
  een speler zaait, een `RefereeMatch` met `player1Id` tot 3-0 laat winnen
  via directe model-aanroepen (zoals `RefereeMatchStoreTest` al doet) en
  controleert dat de UI de strip toont — sneller en robuuster dan 33 losse
  `adb`-tikken.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen.
- `:app:connectedDebugAndroidTest`: 13/13 groen (geen nieuwe test toegevoegd
  in deze stap, zie hierboven).
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED**.

## Fase 5 — Career-badges (AFGEROND, 2026-09-27)

De laatste badge-categorie: hat trick, off the mark, centurion, ten out of
ten, nemesis, veteran — die tellen over al iemands wedstrijden op dit
toestel, niet slechts één.

- **`BadgeAwardStore` kreeg twee nieuwe afhankelijkheden**: `MatchStore` en
  `RefereeMatchStore` (de plain Kotlin-stores, niet de Room-adapters) — nodig
  om, voor een gegeven speler-id, hun hele geschiedenis (coach + referee,
  alleen completed/abandoned) om te zetten naar `BadgeEngine.CareerMatch`
  (`matchId`, `date`, `won`, `pointsWon`, `opponentKey`). Games-gewonnen en
  punten komen uit dezelfde velden als `RoomMatchHistoryStore` al gebruikt
  (`GameRecord.winner`/`CompletedRefereeGame.winner`, spelerscores per game).
  `opponentKey` is de andere speler's id, of anders diens getypte naam (voor
  de Nemesis-badge, die specifiek dezelfde tegenstander moet herkennen).
- **`BadgeEngine.careerBadges(in:history:earnedElsewhere:)` rapporteert per
  wedstrijd alleen wát die ÉNE wedstrijd toevoegde** (bv. "off the mark"
  alleen in de wedstrijd waar de 0-naar-1-drempel wordt gehaald) — niet "heeft
  deze speler ooit badge X gehaald". Om dat laatste (nodig voor weergave) te
  krijgen, doorloopt `BadgeAwardStore.careerBadges(playerId)` de hele,
  chronologisch gesorteerde geschiedenis en unieert alle per-wedstrijd
  resultaten.
- **Niet opgeslagen in `badge_awards`** — in tegenstelling tot per-wedstrijd
  badges kunnen career-badges wijzigen zonder dat er een nieuwe wedstrijd
  wordt opgeslagen (bv. een 25e wedstrijd die al eerder is opgeslagen, maar
  nu pas meetelt omdat "veteran" opnieuw wordt berekend), dus deze worden
  altijd live berekend in `badges(forPlayer:)` in plaats van gesynchroniseerd
  bij een save.
- Dit betekent `PlayerBadgeSummaryStore.badges(forPlayer:)` — dus zowel de
  badge-telling in Spelers als `SharedPlayerBadgesView` — toont nu
  automatisch ook career-badges, zonder dat die UI zelf iets hoefde te
  wijzigen.
- **Kotlin-valkuil gevonden en gefixt (geen Skip-bug)**: `BadgeEngine`'s
  Swift-parameter `earnedElsewhere: Set<BadgeKind>` transpileert naar
  `skip.lib.Set<BadgeKind>`, niet Kotlin's eigen `kotlin.collections.Set` —
  net als `skip.lib.Array`, moet je expliciet `skip.lib.Set(...)`
  construeren (`import skip.lib.Set as SwiftSet`) in plaats van een gewone
  Kotlin-`Set`/`.toSet()` door te geven.
- Nieuwe test **`CareerBadgesTest`** (Robolectric, 3 tests): eerste
  overwinning geeft "off the mark"; 3 overwinningen op rij geven "hat
  trick"; career-badges lekken niet naar een niet-betrokken speler-id.

Actuele verificatie:

- `:app:testDebugUnitTest`: groen, inclusief de nieuwe `CareerBadgesTest`.
- `:app:connectedDebugAndroidTest`: 13/13 groen (geen nieuwe UI, dus geen
  nieuwe instrumented test nodig — bestaande dekking bevestigt dat niets is
  gebroken, inclusief de vier bestaande tests die nu ook `MatchStore`/
  `RefereeMatchStore` importeren voor `BadgeAwardStore`'s nieuwe parameters).
- `swift test --package-path Packages/SquashAnalyzerCore`: 16 XCTests groen,
  `skip test` 15/15 groen.
- `xcodebuild test -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer
  -destination 'platform=iOS Simulator,id=6AC09A50-94A7-4348-BB84-DA1EC43A4644'
  -skipPackagePluginValidation`: **TEST SUCCEEDED**.

## Fase 5 — Volgende onderdelen (NOG NIET GESTART)

Alle badges-substappen zijn nu afgerond (catalogus, opslag, "Kies speler",
per-wedstrijd + career-berekening, weergave in Spelers/spelerscherm/
match-einde-strip) en de geschiedenis bestaat. Volgorde: **spelerskaarten
delen via links, op beide platforms** (zie de beslissing hieronder, stap 1
t/m 6) → **"Nodig coach uit" + CloudKit-sync van iOS verwijderen** (stap 7,
pas als Android links kan maken én openen) → Mijn team (netwerk/regex, moet
met kleine aanpassingen overgaan; netwerken via Skip is nog ongetest, eerst
verkennen) → instellingen/AI Coach (Keychain is iOS-only; Android krijgt
EncryptedSharedPreferences achter dezelfde kleine abstractie).

## Beslissing: spelerskaarten delen via links op iOS én Android, CloudKit-sync verdwijnt (2026-09-28)

Gerd-Jan wil dat spelerskaarten (badges) over de platforms heen gedeeld
kunnen worden. **Gekozen: één mechanisme, de bestaande snapshot-link**
(`https://squashanalyzer.com/kaart/#<payload>`), op beide platforms, en
**"Nodig coach uit" (CloudKit `CKShare` + `CKSyncEngine`, `CardSync.swift`)
verdwijnt van iOS.** Geen live sync meer, ook niet iPhone↔iPhone.

Waarom:

- De snapshot-link is al platformneutraal: JSON → raw deflate → base64url in
  het URL-fragment (dat de browser nooit naar de server stuurt). De website
  pakt hem al uit met `DecompressionStream("deflate-raw")`; Kotlin kan dat met
  `java.util.zip` (`Inflater(nowrap = true)`). Award-ids zijn deterministisch
  (eerste 16 bytes SHA-256 over `cardId|badge|matchId`, versie-/variantbits
  gezet), dus ook in Kotlin (`MessageDigest`) exact na te bouwen.
- CloudKit werkt alleen tussen Apple-apparaten. Een Android-gebruiker kan een
  uitnodiging niet openen; twee knoppen die voor verschillende mensen wel/niet
  werken is verwarrend.
- Live sync over platforms heen vraagt een eigen backend met accounts — een
  veel grotere stap (en dan klopt het privacy-label "Data Not Collected" niet
  meer). Bewust niet gekozen.
- Het CloudKit-delen heeft (voor zover bekend) alleen in TestFlight-builds
  (2.2) gezeten, nooit in de App Store. Nu weghalen is het goedkoopste moment.

Geaccepteerde nadelen:

- Geen automatische synchronisatie meer: na nieuwe badges moet iemand de
  kaart opnieuw sturen. De app biedt dat na een wedstrijd met nieuwe badges
  al aan.
- **Bewuste uitzondering op de harde eis "geen functieverlies op iOS"**,
  expliciet door Gerd-Jan goedgekeurd. TestFlight-testers met een gedeelde
  kaart verliezen de live sync; hun badges blijven lokaal bewaard.
- De iCloud Drive-backup blijft ongemoeid (dat is iCloud Drive, niet de
  CloudKit-database).

Plan (elke stap los testen, iOS en Android groen, zoals alle vorige stappen):

1. **Eén gedeelde implementatie**: `CardSnapshot` (coderen/decoderen) en
   `SavedBadgeAward.awardId` naar `SquashAnalyzerCore`. Deflate en SHA-256
   krijgen per platform een eigen stukje (`#if SKIP`: `java.util.zip` /
   `MessageDigest`; anders de huidige Apple-API's). Vaste
   compatibiliteitstests: een door iOS gemaakte payload moet op Android
   identiek uitpakken, en een bekend award-id moet op beide platforms gelijk
   zijn. Gedragsneutraal voor iOS.
   **AFGEROND (2026-09-28)**, zie "Stap 1 — resultaat" hieronder.
2. **Android-datamodel gelijktrekken** (Room-migratie 5→6): `badge_awards`
   krijgt `cardId`, `opponentName`, `awardedBy` (een eigen id per installatie,
   zoals iOS' `BadgeAwarder.installId`) en het deterministische iOS-award-id.
   Bestaande Android-awards worden omgerekend (`cardId` = `players.cardId`
   of anders het speler-id, net als iOS' `badgeCardId`). Zelfde
   verwijder-semantiek als iOS: een verwijdering wint altijd bij samenvoegen.
3. **Delen vanaf Android**: knop "Deel kaart" in `SharedPlayerBadgesView`,
   die de link maakt en het Android-deelvenster opent (`Intent.ACTION_SEND`)
   via een kleine platform-hook vanuit `MainActivity`. Algemeen opgezet, zodat
   "Deel score" er later op kan meeliften.
4. **Ontvangen op Android**: intent-filters voor
   `https://squashanalyzer.com/kaart` en `squashanalyzer://kaart`, plus een
   importscherm zoals iOS' `CardImportSheet`: voorvertoning ("X nieuwe
   badges, Y verwijderd"), koppelen aan een bestaande speler of een nieuwe
   aanmaken, samenvoegen.
5. **Website**: `website/.well-known/assetlinks.json` (Android App Links, de
   tegenhanger van `apple-app-site-association`), eventueel een "Open in
   app"-knop op de kaartpagina. Voor een geverifieerde App Link is de
   SHA-256-vingerafdruk van de Android-release-sleutel nodig; die bestaat nog
   niet, dus tot dan opent de link via "openen met" of het eigen scheme.
   Uitrollen via Portainer (stack 85, zie de website-deploy-notitie).
6. **End-to-end-test**: een link van de iPhone via WhatsApp openen op de
   Android-emulator, en andersom.
7. **Pas daarna**: "Nodig coach uit" en de CloudKit-sync van iOS verwijderen
   (`CardSync.swift`, de uitnodigingsdelen van `CardShareActions`, het
   accepteren van shares in `AppDelegate`/`SceneDelegate`,
   `CKSharingSupported` in `Info.plist`, `docs/cloudkit-schema.ckdb`).
   Lokale `SavedPlayerCard`-/award-gegevens blijven staan; alleen het
   synchroniseren stopt. `ARCHITECTURE.md` (Badges-sectie) en de
   privacytekst bijwerken. Volgorde bewust zo, zodat er nooit een moment is
   zonder werkende manier van delen.

### Stap 1 — resultaat (AFGEROND, 2026-09-28)

- **`Packages/SquashAnalyzerCore/Sources/SquashAnalyzerCore/CardSnapshot.swift`**
  (nieuw): `AwardValue` (inclusief `AwardValue.awardId(cardId:badge:matchId:)`),
  `CardSnapshot` (payload/webURL/init(payload:)/init?(url:)) en
  `CardSnapshotError`. De iOS-app houdt alleen de SwiftData-kant over
  (`AwardValue.init?(_ award: SavedBadgeAward)`, `CardStore`, en
  `CardLinkError` met de twee CloudKit-gevallen, die bij stap 7 verdwijnen);
  `SavedBadgeAward.awardId` verwijst nu door naar de Core-versie.
- **SHA-256**: SkipFoundation biedt al een CryptoKit-compatibele `SHA256`
  (op `java.security.MessageDigest`), dus alleen `import CryptoKit` staat
  achter `#if !SKIP`; de rest van de award-id-code is gedeeld. De 16 bytes
  worden als `[Int]` bewerkt en via een hex-string naar `UUID(uuidString:)`
  omgezet, niet via `UUID(uuid:)`-tupels (minder transpile-risico).
- **Deflate**: `#if SKIP` gebruikt `java.util.zip.Deflater`/`Inflater` in
  `nowrap`-modus (raw deflate, zoals Apple's `.zlib` en de website);
  `Inflater` krijgt het gebruikelijke extra dummy-byte mee. De gecomprimeerde
  bytes mogen per platform verschillen — alleen de uitgepakte JSON moet
  gelijk zijn, dus er is bewust géén test "encode geeft exact dezelfde
  string".
- **Gouden testwaarden**: gemaakt met een letterlijke kopie van het oude
  iOS-algoritme (vóór de verhuizing), met een verwijderde award, een
  ontbrekende `d` en niet-ASCII-namen ("Paul Stéenks", "Jaïr"). Met Python
  (`zlib`, wbits −15) gecontroleerd dat de payload raw deflate is.
  `CardSnapshotTests` (5 tests): een iOS-link lezen, het iOS-award-id
  reproduceren, id-afhankelijkheid van kaart/badge/wedstrijd, round-trip via
  web- en app-URL, en andere URL's afwijzen. Draaien op Darwin én op Android.
- **Nieuwe Skip-bug**: in een failable init geeft
  `guard …, let snapshot = try? X else { return nil }; self = snapshot` in
  Kotlin `Unresolved reference 'snapshot'` — Skip hernoemt de guard-binding
  (`snapshot_0`) maar niet de uitgeschreven `self =`-toewijzing (die wordt
  per property `this.v = snapshot.v …`). Fix: `do { self = try X } catch {
  return nil }`. **Vuistregel**: wijs in een init nooit `self` toe vanuit een
  `guard let`/`if let`-binding; wijs het rechtstreeks toe.
- Nog open voor stap 6: een door Android gemaakte link echt openen op de
  iPhone en in de browser. Java's raw deflate is standaard, dus dat zou
  moeten werken, maar het is nog niet end-to-end gezien.

Verificatie:

- `swift test --package-path Packages/SquashAnalyzerCore`: 20 XCTests groen
  op Darwin, 20/20 JUnit op Android (15 badge + 5 kaart).
- `:app:testDebugUnitTest` en `:app:connectedDebugAndroidTest` (13/13): groen.
- `xcodebuild test … -skipPackagePluginValidation`: **TEST SUCCEEDED**,
  inclusief de bestaande `PlayerCardTests` en
  `BadgeAwardTests.testAwardIdIsDeterministic`.

## Beslissing: gedeeld team-importeren via URL, niet CloudKit (2026-09-27)

Idee van Gerd-Jan: een teamsamenstelling (spelers) ergens centraal neerzetten
(bijv. op squashanalyzer.com) zodat clubleden 'm zelf kunnen importeren in
"Spelers", in plaats van dat iedereen los een zip/bestand krijgt toegestuurd.

**Gekozen aanpak: uitbreiden van het bestaande zip/`team.json`-importpad
(`TeamImportService`) met een "importeer via URL"-optie**, die het bestand
ophaalt via een simpele HTTP-download en door dezelfde (al bestaande, al
geteste) parser haalt als de huidige lokale bestandsimport. **Bewust niet**
via CloudKit (zoals de gedeelde spelerskaarten nu werken): CloudKit is
Apple-only, en met de Android-port als expliciet doel moet dit juist op
beide platforms werken. Een HTTP-download + dezelfde parser is dat vanaf het
begin — `TeamImportService`/`LeagueTeamParser` zijn al pure Swift en dus
straks via het gedeelde package ook op Android bruikbaar.

Nadeel geaccepteerd: dit is een statisch bestand, geen live sync — bij een
line-up-wijziging moet Gerd-Jan het gehoste bestand handmatig vervangen.
Weegt niet op tegen een Apple-only afhankelijkheid nu cross-platform het doel
is. Nog niet gebouwd — dit is alleen de architectuurkeuze, vastgelegd zodat
ze niet opnieuw gemaakt hoeft te worden.

## Branching

Fases 1–3 staan inmiddels op `main` (de eerdere afspraak over een aparte
Android-branch is in die stappen niet gevolgd). Fase 4 wordt ontwikkeld op
`codex/android-phase4`. Verdere Android-UI-uitbreiding blijft op een aparte
branch tot een presenteerbare mijlpaal; samenvoegen is een afzonderlijke stap.

## Wat nog niet is overgezet

- Android-bestemmingen achter de starttegels: badges, geschiedenis, delen,
  Mijn team en instellingen/AI Coach (fase 5).
- Android-opslag voor badge-awards.
- Foto's, badgecatalogus en teamimport in het Android-spelersscherm.
- Spelerskaarten delen via links (gepland, zie de beslissing van 2026-09-28);
  CloudKit-uitnodigingen verdwijnen daarna ook van iOS.
- Een fysiek Android-toestel is nog nodig voor aanvullende praktijktests.
