# Backlog uit code-analyse van 6 oktober 2026

> Wat bewust niet is gedaan (status `[-]`) staat met de reden ook in
> [bewuste-keuzes.md](bewuste-keuzes.md); een nieuwe analyse leest dat eerst.

Bron: `docs/code-analyse-2026-10-06.md` (stand `19fabb8`). Hier staat per punt wat
er mee gedaan is (stand: 6 oktober 2026, na de verwerking). Status: `[x]` opgelost
met test of controle, `[~]` deels of anders opgelost (met uitleg), `[ ]` bewust
niet gedaan (met reden), `[?]` wacht op een besluit van Gerd-Jan. Nummers
verwijzen naar het rapport (B = bug, §).

Afspraken: niets uploaden naar TestFlight of Play, geen versieverhoging
(`AGENTS.md`). Een punt dat een besluit vraagt (schema, back-upformaat,
badgeregels, kosten) is niet zonder Gerd-Jan doorgevoerd.

## Voor build 19 en voor het publiceren van de website

- [x] **B1** Deep-linkpatroon `/team*` kaapte de teamzip-links. AASA en manifest staan op
      `/kaart`, `/kaart/*`, `/team`, `/team/*`; `CardInbox.invite(from:)` accepteert alleen
      `squashanalyzer.com/team(/)` en `squashanalyzer://team`; tests. AASA is gepubliceerd.
      **Nog na te meten op de iPhone en de A13** (iOS cachet de AASA per installatie).
- [x] **B2** Teamwedstrijdenbestand: atomisch schrijven, versie in het bestand (de eerste
      vorm blijft leesbaar), een onleesbaar bestand wordt opzij gezet en gemeld (nooit als
      leeg gelezen en overschreven), slots weer vier bij het lezen, `restore` laat fouten
      zien (binnen de Room-transactie op Android) en `BackupCounts` telt teamwedstrijden.
- [x] **B3** Vernieuwen keerde een partij om: `linkedOwnIsPlayer1` wordt bewaard.
- [x] **B4** Foute of verlopen teamsleutel: `GET /api/team/:id/verify`, Deelnemen controleert
      de code, een geweigerde sleutel (401) staat zichtbaar op de livekaart, Vernieuwen
      verstuurt opnieuw, de uitnodigingscode staat zichtbaar op de kaart.
- [x] **B5** Privacy: privacytekst en releasenote waren al gecorrigeerd (Codex);
      `PrivacyInfo.xcprivacy` declareert Name, Photos/Videos en Other User Content;
      Google Fonts is van de hele website af (lettertype zelf gehost); de Worker kan sessies
      in de EU bewaren (`LIVE_JURISDICTION`, zie hieronder). **Nog te doen door Gerd-Jan:**
      het App Store-privacylabel in App Store Connect gelijktrekken vóór build 19.
- [x] **B5 EU-opslag**: `LIVE_JURISDICTION = "eu"` staat aan sinds 6 oktober (eigen commit, de
      ene lopende sessie was van Gerd-Jan zelf). Privacytekst aangevuld.
- [x] **B19** Website: Android-keuze op `team/` en `kaart/`, aanmeldanker op de testpagina;
      "wekelijks", de treden en Mijn team waren al gecorrigeerd (Codex); handleiding
      beschrijft build 19 als vooruitblik. Gepubliceerd.

## Sprint: Competitie en live robuust

- [x] **B6** `SessionSaver.save(exit:)` tijdens `busy` laat geen exit-vlag meer staan en
      `perform` blokkeert vóór het wachten; twee tests.
- [x] **B7** De uitnodigingssleutel schrijft partijen; alleen de **eigenaarssleutel** (blijft
      op de startende telefoon) stopt de pagina of wijzigt de teams; deelnemers krijgen
      "Live verlaten". De Worker weigert meer games dan nodig om te winnen en `fromLive`
      begrenst ze ook. **Blijft zo**: elke telefoon met de uitnodiging kan elk slot
      overschrijven (afspraak binnen het team, geen serverregel); zo gedocumenteerd.
- [x] **B8** Een stille 404 wist de sleutel niet meer (alleen na Vernieuwen), een geleegde
      partij gaat van de pagina, `retryPending` bij terugkeer in de app, een verdwenen
      teampagina stopt het versturen.
- [x] **B9** De speeldag-vraag koppelt via dezelfde route als een gestart wedstrijd
      (pusht en gebruikt de actuele opslag); "Nieuwe wedstrijd bijhouden" opent via
      `onDismiss` (geen 500 ms) en `TeamTrackRequest` heeft een eigen id.
- [x] **B10** Back-up: scheidsrechterwedstrijden van vóór de badges krijgen bij de export een
      blijvend id, `importFromJSON` dedupet. Besluit 6 oktober: `refereeMatches`,
      `teamMatches` en `teamPlayerIds` worden altijd geschreven (ook leeg) en de export is
      dus altijd formaat 4; Vervang alles wist ze als de bron de lijst heeft (leeg) en laat
      ze staan bij een oud bestand zonder lijst. Build 17/18 kan zo'n bestand niet
      terugzetten. Tests in Core, iOS en Android.
- [x] **B11** Rollback bij een mislukte referee-save, `keepAsAbandoned` slikt geen fouten meer
      (wist het bestand pas na succes), `loadHistory` committeert geen half werk.
- [x] **B12** Losse spellen (`SavedGame` zonder wedstrijd) staan op iOS in Afgeronde wedstrijden,
      besluit 6 oktober: als rij van één game (bestOf 1), openen in de analyse en verwijderen
      zoals vroeger. `SwiftDataMatchHistoryStore`, test in `ScoringAndPersistenceTests`.
- [x] **B13** Kaart-import en team-uitnodiging blijven niet meer hangen achter een
      `fullScreenCover` (getest op de simulator: de uitnodiging wacht en opent na het sluiten).
- [x] **B14** Opgave/walkover in het teammodel (`TeamPartij.giveUp/walkover/clearEnd`, `endedBy`,
      `endedAfter`; de games worden meteen ingevuld, dus tellingen, verslag en live werken
      mee) en de reglementsbron: Algemeen competitiereglement SBN art. 23 (meeste
      partijen; gelijk: volledig team; dan games, rallypunten, E1; winst van een
      onvolledig team zonder bonus) en reglement regulier bijlage 1 (incompleet team =
      3×11-0). Besluit Gerd-Jan 6 oktober: de app volgt het reglement (dus niet meer
      "games eerst") en bij een opgave gaan alle resterende punten naar de tegenstander.
      Beide teams onvolledig: geen winnaar (reglement zwijgt). Tests: `TeamPartijEndTests`,
      Worker `team.test.js`; editor-UI in `TeamPartijEditor`.
- [x] **B15** Hat trick: besluit 6 oktober, exact bij 3, 5 en 7 op rij (zoals Nemesis), niet
      bij elke wedstrijd daarna. Test aangepast (de 25e winst is geen goud meer).
- [x] **B16** Back-upformaat 4: golden bytes (de Darwin-uitvoer van een `TeamMatch` staat vast
      en draait ook in Kotlin) en een iPhone-v4-bestand dat op Android wordt teruggezet.
- [~] **B17** Room: `schemas/` zijn assets van de debug-build en `androidTest`,
      `AppDatabaseSchemaTest`, en de CI faalt als de build een ander schema schrijft dan er
      gecommit staat. **Niet te herstellen**: er zijn alleen schema's vanaf versie 9
      (`exportSchema` kwam pas daarna); de oudere stappen houden hun SQL-tests.
- [x] **B18** `readJson` weigert op `Content-Length` en leest anders stukje voor stukje.
- [x] **B20** `asc_api.py` heeft een timeout en herhaalt GET's; `testflight_distribute.py`
      loopt door bij een netwerkfout en geeft na het uploaden een herstart-instructie;
      `play_upload.py` weigert notities langer dan 500 tekens in plaats van af te kappen.

### "Laag" (§2)

- [x] `TeamInvite.parse` met leesteken; slots bij het decoderen; `Match.isValidHeadStart` via
      `MatchStand`; `LiveShare` maakt geen nieuwe sessie voor de eindstand; `TeamLive` stopt
      bij een verdwenen pagina; `trackingMatchId` wordt gewist bij weggooien/afbreken;
      `candidate` geeft een beslist teamduel niet terug; opnieuw deelnemen herstelt de kant;
      de uitnodigingscode is zichtbaar; Keychain-sleutel wordt op zijn plek vervangen;
      een onleesbaar referee-bestand wordt opzij gezet; de install-id van de badges blijft uit
      de Android-cloudback-up; Worker: botsend id, fotovlaggen i.p.v. twee foto's per stand,
      CSP, dode code, kijkersplek bij afbreken; website: `award.o`, juiste kop, favicon-opmerking.
- [-] `perfect-ten.png` is niet ongebruikt: `kaart/` laadt hem als gouden trede.
- [-] `RefereeSessionView.close()` met `onExit()` én `dismiss()`: idempotent, geen waarneembare fout.
- [-] `KeystoreAPIKeyStore` (Android) wist bewust eerst: een mislukte schrijfactie moet
      "niet ingesteld" geven in plaats van een oude sleutel te houden (gedocumenteerd).
- [x] `PlayerPhotoView` decodeert op Android niet meer bij elke recompose: `PhotoBitmapCache`
      (64 foto's, sleutel op inhoud omdat Skip's `Data` op array-identiteit hasht; zonder
      `remember`). Opgelost 7 oktober.
- [x] Competitie-bestand van de main thread (7 oktober): iOS `BackgroundTeamMatchStore` (een
      actor, één bewerking tegelijk), Android `BackgroundTeamMatchStore.kt` (`Dispatchers.IO`
      met `Mutex`); de logica staat in `TeamMatchFile.newestFirst/upsert/remove`.
      `TeamBackup.attach` op Android in `Dispatchers.IO`. Op iOS leest de export het bestand
      nog op de main thread, samen met het ophalen uit SwiftData (klein; bewust zo).
- [x] `saver.onExit` wordt bij `onDisappear` losgelaten (Coach en Scheidsrechter).
- [x] `AutomaticBackup` en "Nu naar iCloud" zoeken de iCloud-map buiten de main thread.
- [x] Worker: `release` vóór `deleteAll`, in een `try` (een mislukte release verloopt vanzelf).
- [x] Payload-`version` = 4 zoals de envelope (iOS en Android schrijven altijd formaat 4).
- [x] Losse systeemkleuren (`.green`, `Color.red`) vervangen door `SharedColors.positive` en
      `warmRed`; `scripts/lint.sh` bewaakt het nu.
- [x] `RefereeMatch`: de eerste game begint op `matchStartedAt` (injecteerbaar), niet op een
      tweede `Date()`.
- [-] `RefereeInProgressStore.load` zette een beschadigd bestand al opzij (was al gedaan).
- [-] Node-reserve `X-Forwarded-For`: bewust laten staan; de README beschrijft ook een opzet
      achter een gewone proxy (Nginx), die alleen die header meegeeft. Alleen met `TRUST_PROXY`.
- [-] `contentShape` is in SkipUI een no-op; op Android maakt `clickable` de hele rij al tikbaar.

## Cloudflare en CI

- [x] **Kostenbesluit**: Workers Paid ($5 per maand), besluit 6 oktober; Gerd-Jan heeft het
      abonnement aangezet. Geen hibernation-werk nodig (SSE houdt het object wakker; de
      limiet van het gratis plan, ~13.000 GB-s per dag, geldt niet meer).
- [x] Worker-vitest in `ci.yml` (job `worker`); `deploy-live-beta.yml` annuleert een lopende
      deploy niet meer.
- [x] `workers_dev: false` (de site staat nu alleen op squashanalyzer.com en www), `website/404.html`,
      `deploy-website.yml` weigert zonder `screenshots/` en `teams/`.
- [x] `server/live-worker/README.md` met de teamendpoints, eigenaarssleutel, verify en
      `LIVE_JURISDICTION`. (`compatibility_date` blijft 2025-10-01: de lokale workerd kent 2026
      niet.)

## Doorlopend opruimen

- [x] Gedeelde basisklasse `ViewerSession` voor `LiveSession` en `TeamSession`.
- [x] `TeamMatch.swift` gesplitst (model, `TeamMatchReport.swift`, `TeamMatchStore.swift`);
      `TeamTarget` en `TeamMatchSupport` naar Core, met tests; `SharedTeamMatchViews.swift`
      gesplitst (editor, nieuwe wedstrijd, delen); `SharedSettingsView` eigen bestand.
- [x] Eén verzendlaag voor `LiveShare`/`TeamLive` (7 oktober, `LiveSender.swift`):
      `LatestValueSender` (nieuwste stand per kanaal, samenvoegen, bewaren bij een fout) en
      `LiveWrite` (PUT/DELETE met sleutel). De eigen betekenis bleef bij de klassen: eindstand
      en opnieuw aanmaken in `LiveShare`, 401/404 per teampagina in `TeamLive`. Getest met de
      bestaande Live/TeamLive-tests (Swift en Kotlin) en op de emulator tegen de live-Worker
      (stand 3-1 kwam aan, Live stoppen gaf 404).
- [-] Eén "afgeronde game"-vorm in plaats van zeven: bewust niet (7 oktober). Vijf van de
      zeven hebben een eigen reden: `RefereeMatchSnapshot.FinishedGame`,
      `RefereeMatchBackupData.Game` en `TeamGame` zijn bestandsformaten met vaste JSON (en
      `TeamGame` rekent vanuit onze speler met onbekende punten), `MatchShareReport.Game` kent
      een lopende game met rally's en strokes, `CompletedRefereeGame` is het model met punten.
      Alleen `ResultGame` en `HistoryGameScore` overlappen (drie of vier velden); samenvoegen
      raakt iOS, Android en tests zonder winst.
- [x] `SharedFonts.system` (alle 372 lettertypes in de gedeelde UI en op iOS, `AppFonts`
      erop), `SectionHeader` (tien gelijke koppen in Competitie), `TagChip` (focus-tags),
      `CloseButton` gedeeld (iOS en Android, in alle sheets met `.cancellationAction`;
      "Annuleer" overal "Annuleren") en lintregels op `system(size:` en losse systeemkleuren.
      7 oktober. `ChoiceChip` niet gemaakt: er is maar één kiesbare chip (focus bij Spelers).
- [x] Skip: `keyboardType` ook op Android (gecontroleerd op de emulator), `"plus"`-icoon.
      Het alert-patroon in `TeamPartijEditor` is niet aangepast.
- [x] Docs-drift uit §7, `docs/archief/` (afgeronde plannen en instructies) en
      `docs/skip-valkuilen.md`.
- [~] Tests uit §6: 1–5 gedaan (bestand, deep link, perspectief, sleutel, golden bytes,
      fixture, Vervang alles met een bron zonder wedstrijden, history-store met
      referee- en losse spellen, `APIKeyManager`); 6 deels (Room); 7 deels (Worker:
      team-sleutel, verify, 413, games-clamp); 8 gedaan (opgave/walkover met
      competitiepunten, hat trick exact 3/5/7); 9 deels (7 oktober): `CompetitionScreenTest`
      (Compose, E1 als 3-0 invullen en bewaren) en terugspoeltests voor Room 6→7 en 7→8
      (`VolleyAndOpeningServeMigrationTest`). Nog open: een `SquashAnalyzerUITests`-target op
      iOS (een nieuw target maak je het veiligst in Xcode zelf).

## Besluiten (6 oktober 2026) en wat er nog openstaat

Alle zes besluiten zijn gegeven en verwerkt: B14 (volg het reglement; opgave = resterende
punten naar de tegenstander), B15 (exact 3/5/7), B12 (losse spellen tonen), B10 (altijd
formaat 4), kosten (Workers Paid, door Gerd-Jan aangezet) en EU-opslag.

Nog open:

1. **EU-opslag inschakelen**: `LIVE_JURISDICTION = "eu"` zodra `/health` `"sessions": 0` zegt
   (eigen kleine commit), daarna `website/privacy.html` aanvullen en de website publiceren.
2. **App Store-privacylabel** bijwerken door Gerd-Jan vóór build 19.
3. **Teamzip-links** nameten op de iPhone en de A13 (AASA-cache).
