# Bewuste keuzes (niet opnieuw melden)

Punten die in een code-analyse als bevinding opduiken, maar waar bewust voor
gekozen is. **Lees dit vóór een nieuwe code-analyse** en meld deze punten niet
opnieuw, tenzij de reden hieronder niet meer klopt (zeg dan wat er veranderd
is). In de code staat bij elk punt een korte opmerking die hiernaar verwijst.

Een nieuwe bewuste keuze hoort hier ook: met datum, waar in de code, en de
reden in één alinea.

## Code en architectuur

### Zeven vormen van een "afgeronde game" (7 oktober 2026)

Gemeld in de code-analyse van 6 oktober (§4). Vijf van de zeven hebben een
eigen reden en blijven bestaan:

- `RefereeMatchSnapshot.FinishedGame` (`RefereeMatchSnapshot.swift`): het
  bestand van een lopende scheidsrechterwedstrijd. Vaste JSON: een wedstrijd
  die vóór een update is opgeslagen, moet erna nog te hervatten zijn. Het
  bestand bewaart de winnaar als string, het model als `Player`.
- `RefereeMatchBackupData.Game` (`Backup.swift`): het back-upformaat, dat iOS en
  Android allebei lezen. Vaste JSON, met de golden-bytes-test als bewaking.
- `TeamGame` (`TeamMatch.swift`): het teambestand. Rekent vanuit onze speler
  (eigen/hun punten in plaats van speler 1/2), en de punten mogen onbekend zijn.
- `MatchShareReport.Game` (`MatchShareReport.swift`): kent een lopende game
  (`winner` nil), de rally's voor de langste reeks en het aantal strokes.
- `CompletedRefereeGame` (`RefereeMatch.swift`): het model zelf, met de punten.

Alleen `ResultGame` (`MatchResult.swift`) en `HistoryGameScore`
(`MatchHistoryStore.swift`) overlappen echt: drie of vier velden. Samenvoegen
raakt iOS, Android (`RoomMatchHistoryStore.kt`) en de tests zonder winst.

### Geen aparte `ChoiceChip` (7 oktober 2026)

Er is maar één kiesbare chip: de coachingfocus bij Spelers
(`PlayerDirectory.swift`). Een gedeeld onderdeel voor één plek voegt niets toe.
De niet-kiesbare chips zijn wel samengevoegd in `TagChip` (`SharedFonts.swift`).

### `.contentShape(Rectangle())` alleen op Apple (7 oktober 2026)

`HomeMenu.swift`, `SharedTeamMatchViews.swift`. In SkipUI is `contentShape`
een no-op. Op Android maakt `clickable` de hele rij toch al tikbaar,
gecontroleerd op de emulator: een tik in de lege ruimte van de rij Spelers
opent Spelers.

### iOS-export leest het teambestand op de main thread (7 oktober 2026)

`ExportService.exportFullBackup` → `TeamBackup.attach`. De export haalt toch al
alles uit SwiftData op de main thread op, en het teambestand is een paar kB.
Het schrijven van de back-up gebeurt wel buiten de main thread
(`AutomaticBackup`, "Nu naar iCloud"). Op Android loopt `attach` in
`Dispatchers.IO` (`RoomBackupStore.kt`), omdat Room daar al buiten de main
thread draait.

### `RefereeSessionView.close()` roept `onExit()` én `dismiss()` aan (6 oktober 2026)

`onExit()` laat de ouder het scherm sluiten (op iOS `showingReferee = false`
in `ContentView`), `dismiss()` sluit de presentatie zelf. Allebei aanroepen
is idempotent; bij de analyse van 6 oktober was er geen waarneembare dubbele
dismiss. `CoachSessionView.close()` doet hetzelfde.

### Android `KeystoreAPIKeyStore`: bij een mislukte schrijfactie leeg (6 oktober 2026)

Lukt het versleutelen of opslaan niet, dan wordt de sleutel verwijderd. Hij
leest dan als "niet ingesteld", in plaats van dat stilletjes een oude sleutel
blijft staan die de gebruiker dacht te vervangen.

### `website/badges/perfect-ten.png` is niet ongebruikt (6 oktober 2026)

`website/kaart/index.html` laadt hem als gouden trede van "5 op een rij"; de
oude losse badge Perfect ten is die trede geworden.

### Room-migraties met `hasColumn`-controles (6 oktober 2026)

`AppDatabase.kt`, stappen 6→7, 7→8 en 8→9. De controle is er voor de tests
die een huidige database terugzetten naar een oude versie (de kolom bestaat
dan al). Voor een echte oude database doet hij niets. Room-schema's van vóór
versie 9 bestaan niet (`exportSchema` kwam later); de oudere stappen worden
getest met die terugspoeltests (`ErrorKindMigrationTest`,
`VolleyAndOpeningServeMigrationTest`, `BadgeAwardMigrationTest`).

## Servers

### Node-reserve: `X-Forwarded-For` als terugvaloptie (7 oktober 2026)

`server/live/server.js`, `clientIp`. Alleen met `TRUST_PROXY=1`. De README
beschrijft ook een opzet achter een gewone reverse proxy (Nginx Proxy Manager),
die geen `CF-Connecting-IP` meegeeft. Zonder `TRUST_PROXY` telt alleen het
socket-adres, zodat niemand de limiet omzeilt met een verzonnen header; daar
is een test voor. De productieversie is de Worker, die alleen
`cf-connecting-ip` gebruikt.
