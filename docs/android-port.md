# Android port (one Swift codebase, via Skip)

**Status: Fase 0, 1 en 2 afgerond (2026-09-27) — `SquashAnalyzerCore` is
geëxtraheerd, aan de app gekoppeld, in gebruik, én transpileert nu echt naar
Kotlin: `skip test` geeft 15/15 groen op zowel Darwin (XCTest) als Android
(Robolectric/JUnit). `xcodebuild test -skipPackagePluginValidation` op het
iOS-schema is ook groen. Volgende: Fase 3 (opslag-abstractie voor
Android).** Dit document is
het naslagwerk voor de Android-poging — voor wie er ook aan werkt (Claude of
Codex), zodat niemand blind begint. Werk je hieraan verder, houd dit bestand
bij: fase-status, nieuwe transpile-eigenaardigheden, en genomen beslissingen.

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

## Fase 3 — Opslag-abstractie (NOG NIET GESTART)

`MatchRepository`-protocol bestaat al op iOS
([`MatchRepository.swift`](../SquashAnalyzer/Services/MatchRepository.swift),
geïmplementeerd door `SwiftDataMatchRepository`). Voor Android komt een tweede
implementatie van datzelfde protocol op SQLite/Room. Dit is het stuk waarvoor
Gerd-Jan al vooraf akkoord gaf dat er losse code per platform mag komen.

## Fase 4 — Eerste echt scherm (NOG NIET GESTART)

Kandidaat: het beginscherm (`HomeView`'s tegels) of het badge-overzicht
(`BadgeCatalogView`) — simpel, geen gebaren, goede eerste visuele check.
**Hier pas een fysiek Android-toestel aanschaffen/regelen.**

## Fase 5 — Rest van de features, één voor één (NOG NIET GESTART)

Volgorde: startscherm/navigatie → Spelers (heeft fase 3 nodig) → coach-modus
scoren (`CourtView`'s eigen tekenwerk = hoogste transpile-risico) →
scheidsrechtermodus → badges-UI → geschiedenis → delen (linkjes overzetten;
**CloudKit-uitnodigen blijft bewust iOS-only**, dat is geen gat maar een
keuze) → Mijn team (netwerk/regex, moet met kleine aanpassingen overgaan) →
instellingen/AI Coach (Keychain is iOS-only; Android krijgt
EncryptedSharedPreferences achter dezelfde kleine abstractie).

## Branching

- Fase 1 (pure refactors): direct op `main`, want gedragsloos.
- Alles Android-specifiek (Gradle/Kotlin-scaffolding, het Skip-app-project,
  gedeeltelijke UI): op een langlevende branch `feature/android`, tot er een
  presenteerbare mijlpaal is. Zo blijft `main` een schone iOS-only geschiedenis
  zolang Android nog niet op eigen benen staat.

## Wat hier nog niet in zit

- Er is nog geen `feature/android`-branch en geen Skip-project **in deze
  repo** — de fase-0-proef stond in een scratch-map buiten git en is
  weggegooid na gebruik (het was wegwerpwerk, geen onderdeel van de app).
- `Packages/SquashAnalyzerCore` staat er en is zelfstandig groen (`swift
  test` binnen de package-map), maar hangt nog **niet** aan
  `SquashAnalyzer.xcodeproj` — zie "De hobbel" hierboven. De app gebruikt dus
  nog de oorspronkelijke, dubbele bestanden; er is nog niets verwijderd uit
  de app en er is nog geen `import SquashAnalyzerCore` ergens in de app.
- Nog te doen zodra de package gekoppeld is: de dubbele originelen uit de app
  verwijderen, imports toevoegen, en fase 2 (dit package als Skip-Android-
  target).
