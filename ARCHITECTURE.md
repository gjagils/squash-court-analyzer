# Squash Analyzer architecture

**Status 6 oktober 2026.** Laatste gedocumenteerde testuploads: iOS 2.2 (18) en Android 0.5 (5). Competitie en live teamwedstrijden zijn op main gebouwd voor de volgende upload; zie [opleveren en hosting](docs/opleveren-en-hosting.md).

## Local-first data flow

SwiftUI features call `MatchRepository`; the iOS repository persists coach matches behind the shared store interfaces. `SwiftDataMatchRepository` upserts one `SavedMatch` with child games, points and lets under stable UUIDs.

The lifecycle is:

1. Create and persist a match when setup completes.
2. Persist after every point, let and undo.
3. Persist when a game changes or the app becomes inactive/backgrounded.
4. Mark the match `completed` or `abandoned` instead of creating another copy.
5. Offer the most recently updated `inProgress` match for recovery at launch.

SwiftData remains the primary store. CloudKit database sync is disabled intentionally. iCloud Drive is used only for explicit, versioned backup files.

## Persistence safety

- `SquashAnalyzerSchemaV0` is a frozen copy of the models as shipped in App Store 2.0 (build 8, March 2026; unversioned `Schema([...])`). SwiftData matches an existing store to a schema by model shape, so the plan must start there or 2.0 users get "unknown model version" and the in-memory fallback. `SquashAnalyzerSchemaV1` (TestFlight 2.2 build 5: SavedMatch status/updatedAt/coaching fields) `SquashAnalyzerSchemaV2` (build 6: `SavedPlayer.photoData`) and `SquashAnalyzerSchemaV3` (build 7: `player1GamesBefore`/`player2GamesBefore` on `SavedMatch` and `SavedRefereeMatch`) are frozen too; `SquashAnalyzerSchemaV4` (`player1GamesAfter`/`player2GamesAfter` on `SavedMatch`), `SquashAnalyzerSchemaV5` (badges: player ids, cards, awards), `SquashAnalyzerSchemaV6` (`SavedPoint.isVolley`) are frozen as well; `SquashAnalyzerSchemaV7` (`SavedPoint.errorKind`, October 2026) references the live classes and is the current schema (`SquashAnalyzerCurrentSchema`). V7 is on the developer's phone since 2026-10-03, so it is frozen too: the next model change is V8. `MigrationTests` writes a real 2.0-style store and opens it with the plan.
- Future model changes must add a new `VersionedSchema` (turning the previous current one into frozen nested copies) and a `MigrationStage`; do not edit an already shipped historical schema definition.
- A failed store open never deletes the store. Store files are copied to `Application Support/Recovery/<timestamp>` and the app starts with a clearly disclosed in-memory fallback.
- Full backups use a versioned envelope containing schema version, app version and a SHA-256 checksum.
- Restore validates and decodes the entire backup before deleting existing records.
- The seven newest dated iCloud backups plus `latest-backup.json` are retained.

## Domain rules

`ScoringEngine` owns the pure scoring rules (11 points, win by 2). UI code and persistence models should not duplicate those rules; `Game` and `RefereeMatch` both delegate to it. Add new rule behavior to the engine with tests first.

`RefereeMatch` owns the service rules for referee mode: a server who wins the rally alternates service box, a hand-out puts the new server in their preferred box (right by default; tapping Links/Rechts for a player stores that box as their hand-out default for the rest of the match, e.g. for a left-hander), and the winner of a game serves first in the next game from their preferred box. Every rally won is recorded in `pointHistory`, which drives the scoring line between the two players.

A match can be picked up at game 2–5 ("Later instappen" in the setup screen): `Match` and `RefereeMatch` carry `player1GamesBefore`/`player2GamesBefore`, which count towards the stand and shift the game numbers (`firstGameNumber`, `gameNumber(at:)`) but have no game records of their own; they show as grey `G1 –` chips. `Match.isValidHeadStart` rejects a stand that already decides the match.

The end of a match can be filled in the same way ("Uitslag aanvullen"). Stopping a coach match that is not over asks whether to save it as incomplete (status `abandoned`, shown with an INCOMPLEET badge in the history), to fill in the result, or to discard it (`MatchRepository.delete`); a match without any rally is discarded without asking. Filling in the result (`Match.completeResult(with:)`, also from the history card) takes only the winners of the games from `firstUnrecordedGameNumber` on, which must decide the match exactly with the last one. They are stored as `player1GamesAfter`/`player2GamesAfter`, count towards the stand and show as `–` chips after the tracked games. An unfinished game without rallies is dropped; one with rallies keeps them and is the first of the filled-in games.

**Zones and shots (coach mode).** The court is entered as 6 zones (front/middle/back × left/right) or 9 (with a middle column); `CourtLayout` (Core) holds both, the choice is a setting on iOS and Android (`courtZoneLayout`, default 6). After the zone, only the shots of that zone's *row* are offered (`ShotType.options(for:)`: front Drop · Boast · Kill, middle Kill · Drive · Cross · Boast, back Drive · Cross · Lob), so the rules hold in both layouts. "Uit de lucht" is a switch on top of the shot (`Point.isVolley`, not for a lob), stored in SwiftData schema V6, Room 7 and the backup file (`PointExportData.isVolley`, optional). The old `ShotType.volley` stays readable for earlier points (`isLegacy`, shown as "Volley (oud)") but is no longer offered. Analysis draws the heatmap in the grid the game was played with (`Game.heatmapLayout`: 3×3 as soon as a point lies in the middle column), counts a volley apart from the same shot (`ShotCount.name`: "Volley drop") and shows the volleys per shot (`CoachAdvice.volleyBreakdown`). Plan and history: `docs/archief/plan-6-vakken-slagen.md`.

**Local coaching advice.** `CoachAdvice.local(in:for:match:)` (Core, so iOS and Android give the same advice) collects candidate lines from `AdviceRules`: where the player wins, loses and errs per row (voor/midden/achter) and side (links/rechts) from `ZoneProfile` (winners and forced errors, the opponent's, own unforced errors; strokes and service points do not count), where the opponent errs (a chance), volleys, the best shot per row, tempo, and the older error/let/service rules. "Vaak" needs 5 points, 3 in the row or side and 50% (row) or 70% (side). Each line carries a potential (points at stake; things that already go well weigh less); the dashboard shows the 5 with the most potential, and a finding that also showed in an earlier game of the match says "Net als in game N.". `ZoneProfileTable` shows the counts on both dashboards, and the AI prompt gets the same counts. Plan and decisions: `docs/archief/plan-lokaal-advies.md`.

**AI Coach model.** `AICoachClient.send` first asks OpenAI which models the key may use (`GET /v1/models`) and picks an available chat model using a fixed preference list with `AIModelChoice`: a preference list (in this order: gpt-4.1-nano, gpt-4o-mini, gpt-5-nano, gpt-4.1-mini, gpt-5-mini), else the first "nano" and then "mini" chat model in the list (no audio/realtime/search/… variants). This is not a live price comparison and does not guarantee the cheapest model. Reasoning models (gpt-5, o-series) get `reasoning_effort: low`, more `max_completion_tokens` and no temperature. When OpenAI answers that the model does not exist (retired, 404/model_not_found), the next one is tried once; without a model list the preference list is tried. The dashboards (iOS and Android) only show the AI card when a key is set.

`Game` applies the same service-box rules in coach mode (`serverSide`, per-player preferred box, undo); `Match.startNewGame()` carries the preferred boxes into the next game. The box is not persisted: a game restored from the store derives the server from its last point (`restoreServiceState()`) and starts from the hand-out box until Links/Rechts is tapped. Both screens share `ServiceSideSelector`, and all four player columns (coach and referee, iOS and Android) take their text colours from `ServerHighlight` in `ScoreboardSupport.swift`: the server's name and score in white, the receiver's in the player colour.

## Badges

Stand 6 oktober 2026: **37 badgefamilies en 71 varianten**, waarvan 17 families
met brons, zilver en goud. Uitgeleverd in iOS 2.2 (18) / Android 0.5 (5).
`BadgeKind` behoudt stabiele ids; `perfect-ten` blijft compatibel als gouden
variant van vijf op rij. De collectie toont de hoogste behaalde trede.

`BadgeEngine` in Core berekent awards uit `BadgeMatchInput`; carrièrebadges
gebruiken de opgeslagen wedstrijdgeschiedenis. Alleen geselecteerde, opgeslagen
spelers hebben een speler-id en kunnen badges verdienen. Coach- en
scheidsrechtermodus delen de berekening; slagbadges vereisen coachgegevens.
Awards worden opnieuw berekend bij opslaan en undo. Verwijderde awards hebben
een tombstone: bij samenvoegen wint `deletedAt`, zodat een verwijderde award
niet terugkomt door een oudere kaart te importeren. Awards gaan mee in back-ups.

De gedeelde UI toont de catalogus, collectie en verdienmomenten op beide
platforms. Artwork staat in de resources van SquashAnalyzerUI en in
`website/badges/`. Zie [de artworkoverdracht](docs/style/badge-artwork-overdracht-claude-code.md).

Kaarten worden uitgewisseld als **snapshots via links**, zonder automatische
CloudKit-synchronisatie. `CardSnapshot` en `AwardValue` in Core leggen het
platformonafhankelijke formaat vast; `CardStore` koppelt spelers en voegt awards
samen. De link `https://squashanalyzer.com/kaart#…` bevat de kaartgegevens in het
fragment. De browser toont ze lokaal; de app kan de kaart importeren en koppelen
via `CardImportSheet` / `CardImportPresenter` en `CardInbox`. Nieuwe awards vragen
een nieuwe gedeelde link. Namen en badges worden zo gedeeld; de kaartlink bevat
geen spelersfoto of vrije coachingnotities. Oude CloudKit-velden blijven voor
schemacompatibiliteit bestaan, niet als actieve synchronisatie.

## Competitie (teamwedstrijden)

An SBN team match is four singles (E1–E4). `TeamMatch` (Core,
`TeamMatch.swift`) holds the fixture (from `LeagueFixture` of Mijn team or
typed in), our side (home/away) and four `TeamPartij`s with `TeamGame`s seen
from our player (points optional, winner always known). `TeamMatchScore` is
pure: games, partijen, rally points, winner (most games; tie → most partijen;
tie → most rally points when every game has a score; else a draw) and
competition points (games + 3 bonus for the winner, only once all four are
decided). A partij can be linked to a tracked coach or referee match
(`link(_: MatchHistorySummary, ownIsPlayer1:)` from the history,
`link(coach:)` / `link(referee:)` from a match just played; `linkedMatchId`
is the history id, so "Vernieuwen" re-reads it). `TeamMatchReport.text` is
the WhatsApp message. Storage is one JSON file per phone
(`JSONFileTeamMatchStore`, shared by iOS in Application Support and Android
in `filesDir`; no SwiftData or Room change; included through TeamBackup in backup format 4). UI in
SquashAnalyzerUI: `SharedTeamMatchesView` (list, new from the fixtures or
by hand), `SharedTeamMatchView`, `TeamPartijEditor` (roster chips from Mijn
team, scores or winner only, link picker with the match day on top) and
`TeamMatchLinkPrompt`, which both session views show once after a finished
match when `TeamMatchSupport.candidate` finds a team match of today (saved or
a fixture of Mijn team). A partij can also start a new tracked match
(`TeamTarget`: names to start with, the home player is Speler 1; the finished
match is linked without asking, `TeamMatchSupport.link`). "Deel verslag" has
the three choices of "Deel score" (`TeamMatchReport.text(_:style:)`,
`ResultCard.from(_ teamMatch:)`, `TeamMatchShareView`). Players marked "In mijn
team" are a list of ids in the settings (`TeamRoster`; no schema change), and
team matches plus that list travel in the backup (`TeamBackup`, format 4,
`TeamMatchFile` for the synchronous file access of the platform backup code).
Live per team match (built, `docs/plan-live-teamwedstrijd.md`): the Worker
has a `TeamSession` Durable Object (`server/live-worker/src/team.js`, routes
`/api/team…`, viewer page `/t/<id>`) with the header, four partij slots
and the same two-hour idle alarm. The phone side is `TeamLive` in Core: one
shared write key per team match, invitation `id.key` as a link
(`squashanalyzer.com/team/#…`), code or `squashanalyzer://team#…`
(`TeamInvite`). The app writes its selected partij, home player first
(`TeamLivePartij`); empty names stay empty and the page and app render the
team name plus position. A tracked coach/referee match bound with
`TeamTarget.bind` is forwarded point by point through `LiveShareSync.send`;
the team match screen pushes changed partijen on save and pulls/merges
(`mergeLive`) on open and "Vernieuwen". The setup screen can attach a new
match to a team match ("Onderdeel van een teamwedstrijd"). The Node server
`server/live` (NAS reserve) has no team endpoints.
All participants share the same write key; the server does not enforce ownership per phone or slot.
Later: SBN comparison, badge category Teamspeler.

## Android port

**Room database version (Android): 9.** Every step 1→9 has a `Migration`
(`AppDatabase.kt`), there is no destructive fallback, and the schema is exported
to `Android/app/schemas/<version>.json` (committed; the CI job fails when the build
writes a different schema, so a changed entity cannot ship without a version bump
and a migration). `AppDatabaseSchemaTest` keeps `MigrationTestHelper` usable: for
the next version commit its JSON and test the step with `createDatabase(old)` +
`runMigrationsAndValidate(new, true, MIGRATION_x_y)`. Steps up to 9 have SQL-based
rewind tests because no JSON was exported for them. Competitie (team matches) lives
outside Room, in a JSON file (`JSONFileTeamMatchStore`).

De Android-port is beschikbaar voor testers als 0.5 (5). De app gebruikt
Swift/SwiftUI via Skip, met gedeelde schermen in SquashAnalyzerUI en regels in
SquashAnalyzerCore. Coach- en scheidsrechtermodus, spelers met foto's, badges,
kaartlinks, geschiedenis, analyse, delen, Mijn team en teamimport zijn aanwezig.
Competitie en live teamwedstrijden staan op main voor de nog niet geüploade
build 19 / Android 0.6 (6).

Opslag loopt via de gedeelde store-protocollen. iOS gebruikt SwiftData-adapters;
Android Room-adapters. Teamwedstrijden staan in een afzonderlijk JSON-bestand.
Back-ups zijn uitwisselbaar tussen iOS en Android en bevatten teamdata via
formaat 4 wanneer die aanwezig is. Automatische back-ups zijn op beide platforms
wekelijks: iOS naar iCloud Drive, Android naar een gekozen map. Herstellen moet
valideren voordat bestaande gegevens worden vervangen.

[Android-port](docs/android-port.md) bevat het technische logboek, de toolchain
en Skip-beperkingen. [Opleveren en hosting](docs/opleveren-en-hosting.md) bevat
de actuele test- en releaseprocedure. Oudere fasen zijn geen open backlog.

## Sharing a score

De zichtbare deelopties zijn **Scorekaart, Verslag en Plaatje** (`MatchShareChoice`). `MatchShareReport` levert de gedeelde tekstgegevens voor coach- en scheidsrechtermodus. `MatchShareStyle` bevat intern ook nog Kort; dat is geen vierde zichtbare deeloptie. De gedeelde UI verzorgt tekst en afbeelding op beide platforms.

## Taal (besluit T24, 3 oktober 2026)

De app is alleen Nederlands: de spelers en testers zijn Nederlandse en Belgische
squashers, en een tweede taal betekent elke tekst twee keer bijhouden (ook in de
handleiding, de releasenotes en de website). Er komt dus geen
`Localizable.xcstrings`; teksten staan gewoon in de code.

- `defaultLocalization: "nl"` in `Packages/SquashAnalyzerUI/Package.swift` blijft:
  het zegt alleen in welke taal de teksten staan (systeemknoppen zoals "Annuleren"
  in sheets en de datum-/getalnotatie volgen het toestel). De Core heeft geen
  teksten als resource; daar maakt `"en"` niets uit.
- Squashtermen blijven zoals spelers ze zeggen: Winner, Let, Stroke, Undo, rally,
  Heatmap, best of 5, Down/Out. Een Nederlandse vertaling ("ongedwongen fout"
  voor Unforced error) staat er alleen als uitleg onder.
- Mocht er ooit een Engelse versie komen: Skip ondersteunt één `.xcstrings` in
  het UI-package voor iOS en Android tegelijk; begin daar, niet in de iOS-app.

## Tests

`SquashAnalyzerTests` currently covers game completion, extension scoring, service/undo, unforced-error entry, empty statistics, repository upsert/recovery (including the restored server and the head start), backup checksum rejection, the coach WhatsApp text, the head start in both modes, completing an incomplete match (validation, persistence, backup, discard), the service rules in both modes (box alternation, hand-out, per-player preferred box, undo, next-game server), and the badge rules (5 in a row, broken runs, runs across games in both modes).


## Release

Hosting since 5 October 2026: the live server (Worker `squash-live-beta`, Durable Objects `LiveSession`, `LiveLimiter`, `TeamSession`) and the website (Worker `squashanalyzer-site`) both run on Cloudflare; the NAS (Portainer stacks 85 and 109) is reserve only. The live Worker deploys from CI on a push to `main` that touches `server/live-worker/**`; the website is published by hand from the Mac with `npx wrangler deploy -c server/website-worker/wrangler.jsonc` (its git-ignored `website/screenshots/` and `website/teams/` must be present). The full delivery procedure, the test commands and the open points are in `docs/opleveren-en-hosting.md`.

- Version numbers: `scripts/version.py` keeps iOS and Android in step (`3.1 build 4`, internal `3.1 build 4.1`; see `docs/opleveren-en-hosting.md`). TestFlight: run `scripts/version.py upload`, then `xcodebuild archive` + `xcodebuild -exportArchive` (method `app-store-connect`, destination `upload`) with the App Store Connect API key (`~/.appstoreconnect/private_keys`, key id in `scripts/asc_api.py`). Distribution signing is cloud-managed via `-allowProvisioningUpdates`. `scripts/testflight_distribute.py --version X --build N --notes release-notes/X-N.md` waits for processing, sets the What to Test notes for testers (kept per build in `release-notes/`), adds the build to the external TestFlight group and submits it for beta review (internal groups receive builds automatically). To pull a build, expire it via the API (`PATCH /v1/builds/{id}` with `expired: true`).
- App Store screenshots: `scripts/screenshots.sh` builds a Debug app, launches it on the iPhone 17 Pro Max simulator once per `ScreenshotScenario` (`-screenshot <name>`, Debug builds only) and saves 6.9" PNGs to `screenshots/nl-NL`. `scripts/upload_screenshots.py` replaces the iPhone 6.9" set (API type `APP_IPHONE_67`) of the current `MARKETING_VERSION` in App Store Connect (`--create-version` when the version does not exist yet, `--dry-run` to preview).
- Every external build (TestFlight, later Google Play) also refreshes the App Store screenshots and the Dutch user manual on the website: `website/handleiding/` (`index.html` chooser, `iphone.html`, `android.html`, one section per home tile, screenshots in `img/iphone` and `img/android`, sample players Gerard and Thé). Check the manual against what the build does, retake changed screens (iOS via the `ScreenshotScenario` scenarios, Android on the emulator) and publish with the website (Gerd-Jan's OK first). When `website/style.css` changes, raise the `?v=` on every stylesheet link: Cloudflare caches CSS for 4 hours, and the apex and www hosts are cached separately.
