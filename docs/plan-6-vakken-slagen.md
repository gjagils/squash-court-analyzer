# Bouwplan: 6 vakken + slagkeuze per vak

Status: **in uitvoering op `codex/android-phase4`** (oktober 2026)

## Bijgewerkt voor deze branch (2026-10-01)

Het plan hieronder is geschreven tegen `main`. Op `codex/android-phase4` geldt:

- **Schakelaar 6 of 9 vakken** (wens van Gerd-Jan, om beide uit te
  proberen): in Instellingen op iOS en Android, gedeelde sleutel
  `courtZoneLayout`, standaard 6. De slagkeuze per vak hangt alleen van de
  **rij** af, dus werkt in beide indelingen (de middenkolom volgt dezelfde
  regels als links/rechts). Heatmaps kiezen zelf: 3×3 als er punten in de
  middenkolom liggen, anders 2×3. De "oude indeling"-regel uit 4.1 is
  daarmee niet nodig; middenkolom-vakken zijn geen "legacy" maar gewoon
  vakken van de 9-indeling.
- **Snelle invoer bestaat niet meer** (iOS, 2026-10-01): stap 3.4 en
  `assignShotToLastPoint` vervallen; de slagkeuze-overlay (3.2) is ook weg.
  Invoer = alleen de score-tap-flow (iOS `ContentView.scoreTapStage`,
  Android `CoachScoringView`).
- **Android is niet meer basaal** (fase 5): Room staat op versie 6, dus
  migratie **6 → 7** (`points.isVolley`). Baan, slagkeuze, dashboard en
  analyse zijn grotendeels gedeelde code (`SquashAnalyzerUI`), dus Android
  krijgt de invoer en heatmap mee.
- **Back-upformaat** (gedeeld, `Backup.swift`): `PointExportData.isVolley`
  optioneel, zodat oude back-ups en back-ups tussen iPhone en Android
  blijven werken.
- **Badges**: *Volleywood* telt `isVolley` plus oude "Volley"-slagen;
  *Full house* = alle 6 kiesbare slagen (Drive, Cross, Drop, Lob, Boast,
  Kill), of — voor oude wedstrijden — de oude 6 met Volley.
- Lokaal advies en AI-prompt staan nu in Core (`CoachAdvice`, `AICoachPrompt`)
  en gebruiken de weergavenaam (4.4).

## Aanleiding

Feedback van de trainer:

- Een vak voorin sluit Drive, Cross en Lob uit, een vak achterin sluit Drop en Boast uit. De app toont nu altijd alle 6 slagen.
- Minder vakken: de middenkolom weg. 9 vakken (3×3) worden 6 vakken (3 rijen × links/rechts).
- Volley-varianten (volley-drop, volley-drive, …) moeten vast te leggen zijn. Een kill ontbreekt.

## Besluiten

| # | Besluit |
|---|---|
| 1 | 6 vakken: Voor / Midden / Achter × Links / Rechts |
| 2 | Volley is geen slag meer maar een schakelaar **"Uit de lucht"** bij de slagkeuze |
| 3 | Nieuwe slag **Kill**. Cross drop valt onder **Drop** |
| 4 | Welke slagen je ziet, hangt af van de rij van het vak (tabel hieronder) |
| 5 | Boast mag ook in het midden |

### Slagen per rij

| Slag | Voorin | Midden | Achterin | Volley-schakelaar |
|---|:---:|:---:|:---:|:---:|
| Drop (ook cross drop) | ✅ | – | – | ✅ |
| Boast | ✅ | ✅ | – | ✅ |
| Kill *nieuw* | ✅ | ✅ | – | ✅ |
| Drive | – | ✅ | ✅ | ✅ |
| Cross | – | ✅ | ✅ | ✅ |
| Lob | – | – | ✅ | – (uit) |

Per vak zie je dus 3 of 4 knoppen: voorin Drop · Boast · Kill, in het midden Kill · Drive · Cross · Boast, achterin Drive · Cross · Lob.

Buiten scope (eventueel later): nick als vinkje, reverse/trickle boast, cross lob.

---

## Fase 1 — Kernmodel (`Packages/SquashAnalyzerCore`)

**AFGEROND 2026-10-01** op `codex/android-phase4`: `CourtZone.row`,
`isMiddleColumn`, `CourtLayout` (`six`/`nine`, `rows`, `zones`,
`zone(x:y:)`, `showing(_:)`, `from(stored:)` — een statische functie, want
`init(stored: String)` botst in Kotlin met `init(rawValue:)`),
`ShotType.kill`, `isLegacy`, `selectableCases`, `options(for:)`,
`allowsVolley`, `displayName(isVolley:)`, `Point.isVolley`,
`Game.addPoint(…, isVolley:)` (genegeerd zonder slag of bij Lob),
`Game.volleysWon(by:)`, `BadgeRally.isVolley`; Volleywood, Full house en
Front row king aangepast (zie boven). Eigen Kill-icoon (steile pijl naar de
tin) in beide `ShotIconView`s. Tests: Core `ZoneAndShotTests` (6) op Darwin
en Android; `testFullHouseNeedsEveryShot` (Core en iOS) gebruikt nu
`selectableCases`. Nog niets zichtbaar veranderd: de invoer biedt Kill en
de volleyschakelaar pas vanaf stap 3.

### 1.1 `CourtZone.swift`
- De 6 vakken zijn de bestaande cases `frontLeft`, `frontRight`, `middleLeft`, `middleRight`, `backLeft`, `backRight`. **De rawValues blijven gelijk** ("Voor Links", …), dus 6 van de 9 oude waarden blijven 1-op-1 geldig.
- `frontMiddle`, `middleMiddle` en `backMiddle` blijven bestaan als **legacy**: oude wedstrijden moeten blijven decoderen. Ze worden niet meer aangeboden bij de invoer.
- Nieuw:
  - `enum CourtRow { front, middle, back }` en `enum CourtSide { left, right, center }`, met `zone.row` / `zone.side`.
  - `static let inputZones: [CourtZone]` (de 6 vakken in rasterorde) en `var isLegacy: Bool`.
  - `from(x:y:)` geeft alleen nog de 6 vakken terug (x < 0.5 = links).
- `allCases` blijft alle 9 bevatten (nodig voor decoderen en stats over oude data). Invoer en heatmaps gebruiken `inputZones`.

### 1.2 `ShotType.swift`
- Nieuwe case `kill = "Kill"` (shortName `KIL`, omschrijving "Hard en laag, sterft snel").
- `volley = "Volley"` blijft als **legacy** case: oude punten met "Volley" blijven leesbaar en tonen als "Volley (oud)". Niet meer kiesbaar.
- `drop`-omschrijving: "Korte bal naar voren (ook cross drop)".
- Nieuw: `static func options(for zone: CourtZone?) -> [ShotType]` volgens de tabel hierboven. Bij `nil` of een legacy-vak: alle niet-legacy slagen.
- Nieuw: `var allowsVolley: Bool` (alles behalve `lob` en de legacy `volley`).
- Nieuw: `var isLegacy: Bool`, plus `static let selectableCases`.

### 1.3 `BadgeEngine.swift` (Core)
- `BadgePoint` krijgt `isVolley: Bool = false`.
- *Front row king*: `zone.row == .front` in plaats van de vaste set van 3 (oude data met `frontMiddle` telt zo ook mee).

### 1.4 Tests (Core)
- `CourtZone.from(x:y:)` geeft alleen de 6 vakken.
- `ShotType.options(for:)` per rij, inclusief legacy-vak en `nil`.
- Front row king met `frontLeft`/`frontRight` en met legacy `frontMiddle`.

## Fase 2 — Opslag en volley-vlag (iOS)

**AFGEROND 2026-10-01** op `codex/android-phase4`:
- **iOS**: bevroren `SquashAnalyzerSchemaV5` (volledige kopie van de 8
  modellen zoals ze in builds 13–14 stonden), nieuw `SquashAnalyzerSchemaV6`
  (huidig), lichte migratie `v5ToV6`; `SavedPoint.isVolley: Bool = false`,
  mee in `SavedPoint.from(_:)` en `SavedGame` → `Point`.
  `MigrationTests.testStoreFromVersion5MigratesToVolleyFlag`: een echte
  V5-store met een oude "Volley"-slag in een middenvak migreert, punten
  houden hun slag/vak, `isVolley` begint op `false` en kan daarna worden gezet.
- **Back-upformaat** (Core): `PointExportData.isVolley: Bool?`, alleen
  geschreven als `true`, zodat bestaande back-ups en het vastgepinde
  controlegetal ongewijzigd blijven; iOS en Android lezen en schrijven het.
- **Android**: Room versie 7, `MIGRATION_6_7` voegt `points.isVolley`
  (standaard 0) toe, alleen als de kolom ontbreekt (tests die een huidige
  database terugzetten hebben hem al). `PointEntity`/`PointRecord`,
  `MatchStore`, `RoomCoachMatchStore` en `RoomBackupStore` nemen het mee.
  Op de emulator een v6-installatie bijgewerkt en gestart zonder fout;
  `RoomBackupStoreTest` controleert een volley-kill via Room → back-up → Room.

### 2.1 Volley opslaan
- `Point` krijgt `isVolley: Bool` (standaard `false`).
- `SavedPoint` krijgt `var isVolley: Bool = false`.
- **Nieuw schema `SchemaV6`** in `PersistenceSchema.swift`, met een lightweight migratie `v5ToV6` (nieuw veld met standaardwaarde). Opslag is lokaal (`cloudKitDatabase: .none`), dus er is geen CloudKit-schemawijziging nodig.
- Oude punten met shotType "Volley" krijgen **niet** automatisch `isVolley = true` in de database. De analyse behandelt legacy `volley` als "volley, slag onbekend" (zie 4.2). Zo blijft de migratie lightweight.

### 2.2 Export/import (`ExportService.swift`)
- Het JSON-puntmodel krijgt `isVolley` als **optioneel** veld (`Bool?`, ontbreekt = `false`), zodat oude exportbestanden te blijven importeren zijn.
- Tekstexport: slag tonen als "Volley drop" enz. via één gedeelde helper (zie 3.4).

### 2.3 Tests
- `MigrationTests`: V5-store → V6, punten behouden met `isVolley == false`.
- Opslaan en laden met `isVolley = true`, plus import van een oud JSON-bestand zonder het veld.

## Fase 3 — Invoer (iOS)

**AFGEROND 2026-10-01** op `codex/android-phase4`, voor iOS én Android tegelijk:
`CourtView(layout:)` tekent de vakken uit `CourtLayout.rows` (standaard 6,
via Instellingen → Baanindeling ook 9; opgeslagen onder `courtZoneLayout`).
Na de zone verschijnt de schakelaar "Uit de lucht" (`VolleyToggle`, alleen
bij slagen waar `allowsVolley` geldt) en de slagen van die rij
(`ShotType.options(for:)`, in rijen van 2 of 3 via `ShotType.rows`). Snelle
invoer en `ShotTypeSelectorView` zijn verwijderd (3.2/3.4 vervallen). Op de
emulator gecontroleerd: middenvak → Kill/Drive/Cross/Boast, volley + Kill
wordt opgeslagen.

Er zijn drie plekken waar je een vak of slag kiest. Alle drie gebruiken straks dezelfde logica.

### 3.1 Baan (`CourtView.swift`)
- Een raster van 2 kolommen × 3 rijen in plaats van 3×3, op basis van `CourtZone.inputZones`.
- Het lokale `zoneFor(row:col:)` verdwijnt en wordt vervangen door het Core-raster.

### 3.2 Slagkeuze-overlay (`ShotTypeSelectorView.swift`)
- Neemt het gekozen vak (`game.selectedZone`) en toont `ShotType.options(for:)`: 3 of 4 knoppen, met 3 knoppen op één rij en 4 knoppen in een raster van 2×2.
- Bovenaan de schakelaar **"Uit de lucht"** (bliksem-icoon, nu nog het volley-icoon). Uitgeschakeld en grijs bij Lob.
- De callback wordt `onShotSelected(ShotType, isVolley: Bool)`.
- `ShotIconView`: een eigen icoon voor Kill (bijvoorbeeld een pijl steil naar beneden tegen de frontwand). Zie `shot-icons-preview.html` voor de bestaande stijl.

### 3.3 Score-tap-flow (`ContentView.swift`, stap `.selectShot`)
- De vaste rijen `[.drive, .cross, .volley]` / `[.drop, .lob, .boast]` worden vervangen door `ShotType.options(for: selectedZone)` plus dezelfde volleyschakelaar.

### 3.4 Snelle invoer (`shotStrip(for:)` in `ContentView.swift`)
- De chips achteraf filteren op `lastPoint.zone`.
- De volleyschakelaar komt hier als kleine chip "⚡" vóór de slagchips. Een tik zet hem aan of uit, waarna je een slag kiest.
- `Game.assignShotToLastPoint(_:isVolley:)`.

### 3.5 Model (`Game.swift`)
- `selectShotType(_:isVolley:)` → `addPoint(…, isVolley:)`.
- `serviceLandingZone` blijft `backLeft`/`backRight`, dat zijn al geldige vakken.

### 3.6 Weergave van een slag
Eén helper (in Core, zodat Android hem ook krijgt): `ShotType.displayName(isVolley:)` geeft "Drop", "Volley drop", "Volley (oud)", enzovoort. Die helper wordt overal gebruikt (puntenlijst, export, AI-prompt, deelrapport).

## Fase 4 — Analyse en coaching (iOS)

**AFGEROND 2026-10-01** op `codex/android-phase4` (iOS én Android):
heatmaps in iOS `AnalysisView`/`CoachDashboardView` en het gedeelde
`SharedCoachDashboardView` volgen `Game.heatmapLayout` (2×3, of 3×3 zodra er
een punt in de middenkolom ligt). Slaglijsten tellen een volley apart
(`ShotCount.isVolley`/`name`: "Volley kill"). Nieuwe kaart **"Uit de lucht"**
met `CoachAdvice.volleyBreakdown` ("2 drop, 1 kill"; oude Volley-punten als
"oud"). Het slagraster in `AnalysisView` is Drive · Cross · Lob / Drop ·
Boast · Kill plus een volley-regel. De AI-prompt noemt de volley-namen, het
aantal volleys en of de baan in 6 of 9 vakken is verdeeld.
`CoachAdvice.courtRows` is vervallen (`CourtLayout.nine.rows`). De
share-tekst (`GameSummaryText`) noemt alleen de beste zone en blijft zo.

### 4.1 Heatmaps (`AnalysisView.swift`, `CoachDashboardView.swift`)
- Een raster van 2×3 met `CourtZone.inputZones` in plaats van 3×3.
- **Oude wedstrijden:** punten in een legacy-middenvak vallen buiten het raster. Onder de heatmap komt dan een regel "Midden (oude indeling): n punten". Er verdwijnt dus niets en er wordt niets verzonnen.

### 4.2 Slagstatistieken
- Het slagraster in `AnalysisView` (nu Drive/Cross/Volley + Drop/Lob/Boast) wordt Drive · Cross · Lob / Drop · Boast · Kill.
- Een nieuwe tegel **"Volleys"**: aantal punten met `isVolley == true` plus legacy-`volley`, met daaronder de verdeling ("3 drop, 1 kill").
- `Game.pointsWon(by:with:)` en `Match.totalPointsWon(by:with:)` blijven per slag tellen, ongeacht volley. Nieuw is `volleysWon(by:)`.
- `bestShotType` / `mostEffectiveShot`: legacy `volley` doet mee voor oude data, maar alleen als er geen nieuwere slag hoger scoort. Simpel gehouden via `ShotType.allCases`.

### 4.3 Beste zone en adviezen
- `bestZone`, `worstZone`, `recommendedZones` (`Game.swift`, `Match.swift`): ongewijzigde logica over `allCases`, dus ook legacy-vakken blijven voor oude data werken.
- Tekst "Vermijd …" is ongewijzigd (gebruikt de rawValue).

### 4.4 AI-coaching (`OpenAIService.swift`)
- Zone- en slagoverzicht via de nieuwe weergavenamen ("Volley kill: 2 punten").
- Prompt aanvullen: "De baan is verdeeld in 6 vakken (voor/midden/achter × links/rechts). Links/rechts = forehand/backhand-kant afhankelijk van de speler."

### 4.5 Overig
- `ExportService` tekst "Beste zone": ongewijzigd.
- `MatchShareReport` (Core): controleren of slag/zone erin voorkomen en dan de weergavehelper gebruiken.
- `SampleDataService`, `ScreenshotScenario`, previews in `AnalysisView`/`CoachDashboardView`: voorbeelddata omzetten naar de 6 vakken en de nieuwe slagen (incl. een paar volleys en kills), zodat screenshots de nieuwe indeling tonen.
- `CoachingFocusTag.volley` (`SavedPlayer.swift`) blijft. Dat is een trainingsfocus, geen slagtype.

## Fase 5 — Android

De Android-app is nog een basisopzet (Room `version = 1`).

- `MatchEntities.kt` / `MatchRecord.kt`: kolom `isVolley: Boolean = false`.
- `AppDatabase.kt`: versie 2 met migratie `ALTER TABLE … ADD COLUMN isVolley INTEGER NOT NULL DEFAULT 0`. Als er nog geen geïnstalleerde gebruikers zijn, mag destructive fallback ook. Dat besluiten we bij het bouwen.
- `MatchStore.kt`: veld meenemen bij opslaan en laden, met test in `MatchStoreTest.kt`.
- Zone- en slaglogica komt uit Core (via Skip), dus Android krijgt `inputZones`, `options(for:)` en `displayName` vanzelf mee.

## Fase 6 — Teksten en release

- `release-notes/`: nieuwe notitie ("Baan in 6 vakken, slagen passend bij het vak, volley als schakelaar, nieuwe slag Kill").
- `website/` en `appstore-metadata.md`: noemen geen 9 vakken, dus geen wijziging nodig. Wel opnieuw screenshots maken (`scripts/screenshots.sh`).
- `ARCHITECTURE.md`: korte alinea over legacy-vakken/-slagen en de volley-vlag.

## Volgorde en omvang

| Stap | Inhoud | Inschatting |
|---|---|---|
| 1 | Core: zones, slagen, helpers, badge + tests | klein |
| 2 | Opslag: `isVolley`, SchemaV6, export + tests | klein–middel |
| 3 | Invoer: baan, overlay, score-tap, snelle invoer | middel |
| 4 | Analyse: heatmaps, slagstats, volley-tegel, AI | middel |
| 5 | Android: kolom + migratie | klein |
| 6 | Voorbeelddata, screenshots, release notes | klein |

Elke stap is los te testen en te committen. Stap 1 en 2 veranderen nog niets zichtbaars. Vanaf stap 3 ziet de gebruiker de nieuwe indeling.

## Risico's en aandachtspunten

- **Oude wedstrijden met middenkolom-vakken.** Die worden niet omgezet, alleen apart getoond (4.1). Een omzetting naar links/rechts zou gegevens verzinnen.
- **Oude "Volley"-slagen.** Die blijven "Volley (oud)": de slag zelf is onbekend.
- **Gemengde analyse over oude en nieuwe wedstrijden** (spelerskaart, coachdashboard over meerdere wedstrijden): legacy-vakken en -slagen tellen mee in totalen maar niet in de 2×3-heatmap. Dat staat zichtbaar in de "oude indeling"-regel.
- **SwiftData-migratie.** Altijd testen met een echte V5-store (bestaande `MigrationTests`-opzet).

## Open punten voor later

- Nick als extra vinkje ("eindigde in de nick").
- Instelling om toch alle slagen te tonen ("vrije keuze") voor trainers die de filter te streng vinden.
