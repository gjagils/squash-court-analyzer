# Skip-valkuilen (Swift → Kotlin) in een lijst

`Packages/SquashAnalyzerCore` en `Packages/SquashAnalyzerUI` worden met Skip naar
Kotlin/Compose getranspileerd. Dit is de korte lijst van wat er misgaat, met de
oplossing; het uitgebreide logboek met de achtergrond per geval staat in
`docs/android-port.md` (zoek op de trefwoorden). `scripts/lint.sh` bewaakt een
paar van deze regels. Bij een nieuwe valkuil: voeg hem hier toe.

## Taal en typen

- **Geen keypath-literals (`\.naam`) en geen `$0`/`$1` in geneste closures**:
  schrijf een closure met een naam (`{ point in point.scorer }`). Ook een gebonden
  method reference (`kinds.contains`) wordt `{ kind in kinds.contains(kind) }`.
  (lint-regel)
- **Gehele getallen in een `Double`-context krijgen een `.0`**: `?? 0.0`,
  `60.0 * 60.0`, en in een ternaire `Double`-waarde op beide takken
  (`flag ? 8.0 : 9.0`). Een `Double` wordt als `1.79E12` gecodeerd: gebruik
  `Int64` voor tijden in JSON (`TeamLiveHeader.date`).
- **Geen tuples in publieke API** en geen benoemde tuples in `ForEach`; maak een
  struct (`PlayerRun`, `ServiceState`).
- **Kotlin-sleutelwoorden als naam vermijden**: `out`, `in`, `is`, `object`, `fun`,
  `val`, `when` (geen enum-case `out`; lint-regel).
- **Een property en een methode `set<Naam>` botsen** op JVM-niveau
  (`startingServer` ↔ `setStartingServer`).
- **Een argumentlabel gelijk aan een property verbergt die property**
  (`func start(matchId id:)`): schrijf `self.` voor de property.
- **Statics worden van boven naar beneden geïnitialiseerd**: een
  `static let shared = X()` staat onder de statics die de init gebruikt.
- **`@Observable` vraagt `import Observation` in het bestand zelf.**
- **Geen `CharacterSet`-splitsen, geen `lastIndex(of:)`, geen range-subscripts op
  strings**: knip met een lus (`TeamInvite.parse`); `s += String(character)` in
  plaats van `s.append(character)`; `Character.isLetter` bestaat niet.
- **`optional.map { value in … value.rounded() }` wordt `optionalrounded`** in Kotlin
  (9 oktober, `SharedPlayerTrendView`): schrijf een `guard let` of `if let`.
- **Lege literals zonder type** (`[]`, `[:]`) laten het type soms niet afleiden:
  geef het type mee.
- **`Date.FormatStyle` bestaat niet**: gebruik `DateFormatter` met een vast patroon
  en locale.
- **Bytes in Core**: geen `Data([0xFF…])`, `data[0]` of `Data(repeating:)`; werk via
  base64. `Data.write(to:options:)` vraagt het volle type: `Data.WritingOptions.atomic`.
- **Async-code in tests**: wacht op het eindresultaat, niet op een tussenstap
  (poll met een korte slaap en een limiet).

## Tests (SkipUnit)

- **Geen `XCTAssertThrowsError`**: `do { try …; XCTFail("…") } catch { }`.
- **Geen `String(decoding:as:)`**: `String(data:encoding: String.Encoding.utf8)`.
- Een testbestand dat `UUID`, `Date` of `TimeInterval` noemt, importeert `Foundation`.
- Een test die op de MainActor draait, krijgt `@MainActor` (let op bij het invoegen van
  een test vlak onder een bestaand attribuut: dat attribuut hoort dan bij de nieuwe test).
- Timing-tests met vaste slaaptijden zijn flaky: poll tot de toestand er is.

## UI

- **Geen `Image(systemName:)` in de gedeelde UI**: gebruik `AppSymbol` (alleen symbolen
  met een Android-mapping in `AppSymbol.swift`; lint-regel).
- **Kleuren uit `SharedColors`**, geen `Color(red:…)` (lint-regel). Liever
  `.background(kleur)` + `.clipShape` dan `RoundedRectangle().fill`.
- **Een `Button` nooit conditioneel tussen twee takken splitsen**: één vaste knop met een
  optioneel aangeroepen closure.
- **Een `.alert` met alleen een `.cancel`-knop krijgt op Android twee knoppen**: geef de
  enige knop geen rol.
- **Titels naast knoppen**: `.lineLimit(1)` + `.minimumScaleFactor(…)`.
- **iOS-only code**: `#if os(iOS) && !SKIP` (de Android-build draait eerst `swift build`
  voor macOS). `.keyboardType` bestaat in SkipUI: `#if os(iOS) || SKIP`.
- **`fullScreenCover` bestaat niet in de macOS-voorbouw**: gebruik `trackedCover`.
- **Een `Binding` die bij `false` gegevens wist als alert-patroon** werkt niet betrouwbaar op
  Android: sla de gegevens apart op.
- **Compose-hulpfuncties in `#if SKIP` (zoals `remember`) kunnen de hele build laten falen**
  met een fout in een ander bestand (`Cannot access … Tuple2.element`): bouw na zo'n
  wijziging meteen `assembleDebug`. Probeerde op 6 oktober `remember(photo)` in
  `PlayerPhotoView`; teruggedraaid.

## Build

- **"Enum types cannot be instantiated" of "Cannot access 'constructor(rawValue…)'"** bij een
  aanroep als `ServerSide(rawValue = …)` in gegenereerde Kotlin, terwijl de Swift niet
  veranderd is: de Skip-uitvoer van het UI-pakket is half bijgewerkt (7 oktober, na alleen
  commentaarwijzigingen). `gradlew clean` helpt niet. Wel:
  `rm -rf Packages/SquashAnalyzerUI/.build/plugins/outputs/squashanalyzerui Packages/SquashAnalyzerUI/.build/gradle-skip-stamp`
  en opnieuw bouwen.

- **Gradle in een worktree** vraagt `JAVA_HOME` (JBR van Android Studio) en
  `ANDROID_HOME`; `skip test --project Packages/SquashAnalyzerCore` (niet `--package-path`).
- **AGP 9 + KSP**: `android.builtInKotlin=false` en `android.newDsl=false` in
  `Android/gradle.properties`.
- **Room**: bij een nieuwe databaseversie de gegenereerde `schemas/<versie>.json`
  committen; de CI faalt als `git diff Android/app/schemas` niet leeg is.
