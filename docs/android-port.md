# Android port (one Swift codebase, via Skip)

**Status: Fase 0 afgerond, Fase 1 ten dele (2026-09-27) — zie hieronder, er
staat één handmatige stap open in Xcode voordat fase 1 verder kan.** Dit document is
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
swift test
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

## Fase 1 — Pure logica loskoppelen (GEDEELTELIJK: package staat, nog niet aan de app gekoppeld)

Doel: `ScoringEngine`, `BadgeEngine`, `MatchShareReport`, `CardSnapshot`, de
teamlink-parser (`LeagueTeamParser`/`LeagueTeamService`), en de simpele
modelwaarden (`Player`, `PointType`, `ShotType`, `CourtZone`) verhuizen naar
een Swift Package **binnen deze repo** (`Packages/SquashAnalyzerCore/`).

### Wat er staat (2026-09-27)

Het package [`Packages/SquashAnalyzerCore`](../Packages/SquashAnalyzerCore)
bestaat en bevat `Player`, `PointType`, `ShotType`, `CourtZone`,
`ScoringEngine`/`SquashScore`, `MatchShareReport`/`MatchShareStyle`, en de
volledige pure kant van `BadgeEngine` (`BadgeKind`, `BadgeRally`, `BadgeGame`,
`BadgeMatchInput`, `BadgeEngine`, `MatchBadgeEarning`), allemaal met `public`
API. Alle types kregen expliciete `public init(...)` waar nodig, want SPM's
automatische memberwise-init is nooit `public`.

`Packages/SquashAnalyzerCore/Tests` bevat een overgezette, groene versie van
`BadgeEngineTests` (15 tests, `swift test` binnen de package-map): draai het
zelf met

```bash
cd Packages/SquashAnalyzerCore && swift test
```

Twee tests bleven bewust in de app achter, want die raken `Match`/
`RefereeMatch` (die niet mee verhuizen): `testRefereeRunCarriesOverIntoTheNextGame`
en `testCoachMatchRallyWinnersFollowPlayOrder`.

**Wat nog NIET is gedaan:** de app zelf gebruikt dit package nog niet. De
oorspronkelijke bestanden (`Game.swift`'s `Player`, `PointType.swift`,
`ShotType.swift`, `CourtZone.swift`, `ScoringEngine.swift`,
`MatchShareReport.swift`, en de pure helft van `BadgeEngine.swift`) staan dus
nog dubbel: één keer in de app (ongewijzigd, nog steeds wat de app gebruikt)
en één keer in het nieuwe package (nog ongebruikt). Dat is bewust zo
achtergelaten — zie hieronder waarom.

### De hobbel: het package aan het Xcode-project koppelen

Ik heb geprobeerd `Packages/SquashAnalyzerCore` als lokale Swift Package
dependency in `SquashAnalyzer.xcodeproj/project.pbxproj` te verbinden door het
projectbestand direct te bewerken (dit project gebruikt het oude,
handgeschreven pbxproj-formaat, geen `PBXFileSystemSynchronizedRootGroup`).
Ik voegde toe: een `XCLocalSwiftPackageReference`, twee
`XCSwiftPackageProductDependency`-objecten, `packageReferences` op het
project, `packageProductDependencies` op beide targets, en de bijbehorende
`PBXBuildFile`/Frameworks-fase-entries.

Het projectbestand bleef geldig (`plutil -lint` OK, `xcodebuild -list` OK), en
zolang niets het package echt importeerde, bouwde de app zelfs foutloos. Maar
zodra ergens `import SquashAnalyzerCore` werd toegevoegd, gaf de build
`error: Unable to resolve module dependency: 'SquashAnalyzerCore'`. Verder
onderzoek (`xcodebuild -resolvePackageDependencies` bleef "resolved source
packages:" leeg tonen, ook na het wissen van alle DerivedData) liet zien dat
Xcode's buildsysteem het package helemaal niet in de dependency-graph van het
`SquashAnalyzer`-target opnam — "note: Target dependency graph (1 target)" —
ondanks dat de pbxproj-secties er syntactisch correct uitzagen. Met Xcode
27.0 kan het schema voor lokale package-referenties net iets anders zijn dan
wat hier is neergezet; zonder de Xcode-GUI om dit stap voor stap te
verifiëren was verder blind doorproberen niet verantwoord, dus **is deze
wijziging teruggedraaid** (de app staat weer exact op commit `345164f`; alleen
`Packages/SquashAnalyzerCore` zelf is nieuw en blijft staan).

### Openstaande handmatige stap (voor Gerd-Jan of iemand met Xcode open)

Dit kost in de Xcode-GUI naar verwachting minder dan een minuut, en schrijft
het juiste formaat automatisch weg:

1. Open `SquashAnalyzer.xcodeproj` in Xcode.
2. Selecteer het project in de Project Navigator → tab **Package Dependencies**.
3. Klik **+** → **Add Local...** → kies de map `Packages/SquashAnalyzerCore`.
4. Voeg het product `SquashAnalyzerCore` toe aan het target **SquashAnalyzer**
   (en desgewenst ook aan **SquashAnalyzerTests**).
5. Commit de bijgewerkte `project.pbxproj` (Xcode schrijft `packageReferences`,
   `XCLocalSwiftPackageReference`, `XCSwiftPackageProductDependency` en
   `packageProductDependencies` zelf correct weg).

Zodra dat gedaan is, is de rest van fase 1 weer pure herhaling: `import
SquashAnalyzerCore` toevoegen aan de bestanden die de verplaatste types
gebruiken (dat lijstje stond al klaar — zoek op `\b(Player|PointType|
ShotType|CourtZone|ScoringEngine|SquashScore|MatchShareReport|
MatchShareStyle|BadgeEngine|BadgeKind|BadgeRally|BadgeGame|BadgeMatchInput|
MatchBadgeEarning)\b` door `SquashAnalyzer/`), de dubbele originelen
verwijderen (`CourtZone.swift`, `PointType.swift`, `ShotType.swift`,
`ScoringEngine.swift`, `MatchShareReport.swift` volledig; uit `Game.swift`
alleen de `Player`-enum; uit `BadgeEngine.swift` alles behalve de
`Match`/`RefereeMatch`-extensies), en dan `xcodebuild test` + `swift test`
(in de package) allebei groen krijgen.

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

## Fase 2 — Android-kant van dat package (NOG NIET GESTART)

De bestaande XCTest-stijl tests (`BadgeEngineTests`, `ScoringAndPersistenceTests`
voor zover ze geen SwiftData raken, `PlayerCardTests` voor zover puur) draaien
via `swift test` óók als JUnit op de JVM. Dit is het vangnet: wijkt Android
ooit af van iOS, dan faalt dit meteen.

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
