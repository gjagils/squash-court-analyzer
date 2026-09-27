# Android port (one Swift codebase, via Skip)

**Status: Fase 0 t/m 4 afgerond; fase 5 Spelers, `CourtView` én coach-modus
scoren afgerond (2026-09-27).** Android heeft nu een echt startscherm, een
werkend spelersbeheer-scherm, en een volledig werkende coach-scoreflow (tik
score → puntsoort → zone → slag, undo, game/match-einde) — handmatig op de
emulator geverifieerd met screenshots. `Game`, `Match`, `Point`, `LetCall`,
`ServerSide` en `MatchStatus` zijn nu allemaal gedeeld via
`SquashAnalyzerCore`. Zes nieuwe echte Skip-bugs gevonden en gefixt tijdens
deze stap (bovenop de drie uit de `CourtView`-stap) — zie Fase 5 hieronder.
Regressie: `:app:testDebugUnitTest` (11/11), `:app:connectedDebugAndroidTest`
(5/5), `skip test` (15/15 op Darwin en Android), volledige iOS-testsuite
(`xcodebuild test -skipPackagePluginValidation`) — allemaal groen. Nog open:
de Coach-tegel gebruikt een los `Match()` per bezoek, nog niet gekoppeld aan
`MatchStore` (fase 3) voor echte opslag. Geen TestFlight-upload.

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
beslissingen. Volgende: **fase 5, scheidsrechtermodus (kan `ServiceSideSelector`/
`ServerIndicator`/`Game`/`Match` hergebruiken) en de `MatchStore`-koppeling
voor coach-modus**.

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
   Dit loste de *productie*code op, maar **de bijbehorende geautomatiseerde
   UI-test (`CoachScreenTest.kt`) bleef falen op exact hetzelfde symptoom en
   is daarom niet meegenomen** — zie "Open testprobleem" hieronder.

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

### Open testprobleem (niet blokkerend)

Een geautomatiseerde instrumentatietest voor de volledige score-tap-flow
(`CoachScreenTest.kt`) is geschreven maar weer verwijderd: het tikken op de
score van Speler 1 riep de handler niet aan via **geen enkele** Compose-
testmethode (`performClick()`, `performTouchInput { click() }` op de node,
of op `onRoot()` op exact dezelfde coördinaat) — terwijl een echte tik op
hetzelfde punt op het draaiende (niet-test-harness) toestel wél gewoon
werkte, herhaaldelijk bevestigd. Dit wijst op een verschil tussen hoe
`ActivityScenarioRule`/`createAndroidComposeRule` de host-Activity opstart
versus een normale app-launch, niet op een echte functionele bug — vandaar
"niet blokkerend". Als dit later terugkomt bij een ander scherm: probeer
`androidx.compose.ui.test.junit4.v2.createAndroidComposeRule` (de nieuwere,
niet-deprecated variant met `StandardTestDispatcher`) voordat je verder
zoekt, want de huidige (`v1`) rule's deprecatiewaarschuwing wijst zelf al in
die richting.

### Geverifieerd

`:app:testDebugUnitTest` (11/11), `:app:connectedDebugAndroidTest` (5/5,
`CourtViewTest` blijft de automatische dekking voor het risicovolste
tekenwerk), `skip test` (15/15 op Darwin en Android), volledige iOS-testsuite
(`xcodebuild test -skipPackagePluginValidation`) — allemaal groen. Geen
gedragsverandering op iOS; `Game`/`Match`/`Point`/`LetCall` heten en werken
overal exact hetzelfde, nu vanuit een ander (gedeeld) module.

## Fase 5 — Volgende onderdelen (NOG NIET GESTART)

Volgorde: scheidsrechtermodus (kan nu veel hergebruiken:
`ServiceSideSelector`, `ServerIndicator`, `Game`/`Match` zijn al gedeeld) →
badges-UI → geschiedenis → delen (linkjes overzetten; **CloudKit-uitnodigen
blijft bewust iOS-only**, dat is geen gat maar een keuze) → Mijn team
(netwerk/regex, moet met kleine aanpassingen overgaan) → instellingen/AI
Coach (Keychain is iOS-only; Android krijgt EncryptedSharedPreferences
achter dezelfde kleine abstractie). Ook nog open: `CoachScoringView`
koppelen aan `MatchStore` (fase 3) zodat een gescoorde wedstrijd op Android
ook echt bewaard blijft — nu gebruikt de Coach-tegel een los, ongepersisteerd
`Match()` per bezoek.

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

- Android-bestemmingen achter de starttegels: scoren, scheidsrechter,
  badges, geschiedenis, delen, Mijn team en instellingen/AI Coach (fase 5).
- Android-opslag voor badge-awards en scheidsrechterwedstrijden.
- Foto's, badgecatalogus en teamimport in het Android-spelersscherm.
- CloudKit-uitnodigingen blijven bewust iOS-only.
- Een fysiek Android-toestel is nog nodig voor aanvullende praktijktests.
