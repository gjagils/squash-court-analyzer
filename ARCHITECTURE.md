# Squash Analyzer architecture

## Local-first data flow

SwiftUI features call `MatchRepository`; the repository is the only write path for coach matches. `SwiftDataMatchRepository` upserts one `SavedMatch` with child games, points and lets under stable UUIDs.

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

**Zones and shots (coach mode).** The court is entered as 6 zones (front/middle/back × left/right) or 9 (with a middle column); `CourtLayout` (Core) holds both, the choice is a setting on iOS and Android (`courtZoneLayout`, default 6). After the zone, only the shots of that zone's *row* are offered (`ShotType.options(for:)`: front Drop · Boast · Kill, middle Kill · Drive · Cross · Boast, back Drive · Cross · Lob), so the rules hold in both layouts. "Uit de lucht" is a switch on top of the shot (`Point.isVolley`, not for a lob), stored in SwiftData schema V6, Room 7 and the backup file (`PointExportData.isVolley`, optional). The old `ShotType.volley` stays readable for earlier points (`isLegacy`, shown as "Volley (oud)") but is no longer offered. Analysis draws the heatmap in the grid the game was played with (`Game.heatmapLayout`: 3×3 as soon as a point lies in the middle column), counts a volley apart from the same shot (`ShotCount.name`: "Volley drop") and shows the volleys per shot (`CoachAdvice.volleyBreakdown`). Plan and history: `docs/plan-6-vakken-slagen.md`.

**Local coaching advice.** `CoachAdvice.local(in:for:match:)` (Core, so iOS and Android give the same advice) collects candidate lines from `AdviceRules`: where the player wins, loses and errs per row (voor/midden/achter) and side (links/rechts) from `ZoneProfile` (winners and forced errors, the opponent's, own unforced errors; strokes and service points do not count), where the opponent errs (a chance), volleys, the best shot per row, tempo, and the older error/let/service rules. "Vaak" needs 5 points, 3 in the row or side and 50% (row) or 70% (side). Each line carries a potential (points at stake; things that already go well weigh less); the dashboard shows the 5 with the most potential, and a finding that also showed in an earlier game of the match says "Net als in game N.". `ZoneProfileTable` shows the counts on both dashboards, and the AI prompt gets the same counts. Plan and decisions: `docs/plan-lokaal-advies.md`.

**AI Coach model.** `AICoachClient.send` first asks OpenAI which models the key may use (`GET /v1/models`) and picks the cheapest suitable chat model with `AIModelChoice`: a preference list (cheapest first: gpt-4.1-nano, gpt-4o-mini, gpt-5-nano, gpt-4.1-mini, gpt-5-mini), else the first "nano" and then "mini" chat model in the list (no audio/realtime/search/… variants). OpenAI's API gives no prices, so "cheapest" is that order. Reasoning models (gpt-5, o-series) get `reasoning_effort: low`, more `max_completion_tokens` and no temperature. When OpenAI answers that the model does not exist (retired, 404/model_not_found), the next one is tried once; without a model list the preference list is tried. The dashboards (iOS and Android) only show the AI card when a key is set.

`Game` applies the same service-box rules in coach mode (`serverSide`, per-player preferred box, undo); `Match.startNewGame()` carries the preferred boxes into the next game. The box is not persisted: a game restored from the store derives the server from its last point (`restoreServiceState()`) and starts from the hand-out box until Links/Rechts is tapped. Both screens share `ServiceSideSelector`, and all four player columns (coach and referee, iOS and Android) take their text colours from `ServerHighlight` in `ScoreboardSupport.swift`: the server's name and score in white, the receiver's in the player colour.

## Badges

Players earn badges during a match, in coach and referee mode, but only players picked from "Kies speler" (a typed-in name has no id and earns nothing). A player's badges are shared across the devices of every coach who tracks that player.

**Built so far (local, schema V5):** `BadgeKind` (stable raw values, stored and shared, never renamed) and `BadgeEngine`, which, like `ScoringEngine`, is pure: it takes the rally winners of a match in play order (`Match.rallyWinners`, `RefereeMatch.rallyWinners`) and returns the badges per player; runs carry over from one game into the next. The setup screen remembers a player picked in "Kies speler" (`PickedPlayer`; editing the name drops it) and passes `player1Id`/`player2Id` into `Match` and `RefereeMatch`, which are persisted. `BadgeAwarder.syncAwards` runs on every `MatchRepository.upsert` and when a referee match is saved, so an undone rally takes back an award while a deleted one stays deleted; discarding a match removes its awards, deleting one from the history marks them deleted. Awards go into the full backup (including deleted ones; import merges by award id). UI: `MatchBadgesStrip` on both match-over screens, `MatchBadgesSheet` / `PlayerBadgesView` with counts and the earning moments (`BadgeMomentsView`, swipe to delete), a badge count in the player list and a medal on history cards. `BadgeKind` has 31 badges (set 01–06); `BadgeCatalogView` (player list → medal) and `website/badges/index.html` list them all; the engine takes a `BadgeMatchInput` (rallies with shot and point type per game, head start, final stand, match winner) that `Match.badgeInput` and `RefereeMatch.badgeInput` build. Shot and service badges (`coachOnly`) can only be earned in coach mode. Career badges (`isCareer`: hat trick, off the mark, centurion, ten out of ten) come from `BadgeEngine.careerBadges` over the player's finished matches on this device (`BadgeAwarder.history`); the once-only ones (`isOnce`) are not awarded again when the card already has them. Artwork is `badge-<id>` (240px) in SquashAnalyzerUI's `Resources/Module.xcassets`, drawn by the shared `BadgeArtwork` on iOS (`BadgeView`) and Android (`BadgeMedallion`), and `website/badges/<id>.png` on the site; unearned badges are shown greyed out. Debug scenario `-screenshot badges` shows a finished match with badges. Sharing is by link only (since 2026-09-30; the CloudKit live sync — `CardSync`, "Nodig coach uit" — was removed so iPhone and Android share cards the same way, see docs/android-port.md): `CardSnapshot` is the link format (it and `AwardValue`, including the deterministic award id, live in `SquashAnalyzerCore` so iOS and Android produce and read identical links; golden-vector tests in `CardSnapshotTests` pin the format on both platforms), `CardStore` merges awards and links players to cards (`link` moves the player's own awards onto the card), `CardShareActions` ("Deel kaart": image plus link) / `CardImportSheet` / `CardImportPresenter` are the UI, and an opened link goes through the shared Core `CardInbox`. The website has `kaart/index.html` (draws the card from the fragment, never sends it) and `.well-known/apple-app-site-association` (applinks for `/kaart*`); the app also opens `squashanalyzer://kaart#…`. `SavedPlayerCard` and `SavedBadgeAward.cloudSystemFields` are unused leftovers of the CloudKit sync, kept because schema V5 is frozen. The design below is what was built, minus the CloudKit parts marked as removed.

**Planned design:**

- **Identity.** `SavedPlayer` gets a `cardId`; `SavedMatch` and `SavedRefereeMatch` get `player1Id`/`player2Id` (new `VersionedSchema`). Cards are matched on `cardId`, never on name.
- **Awards.** A `BadgeAward` is one earning moment with a deterministic id derived from (cardId, badgeKind, matchId), plus `earnedAt`, `awardedBy` and an optional `deletedAt`. A player has a badge while at least one award without `deletedAt` exists. Because badges derive from the point history, awards are recomputed for old matches once (backfill); recomputing never recreates an existing id, so a deleted badge does not come back, while a new match can earn it again.
- **Deletion is soft.** Deleting sets `deletedAt` on the awards, which is never cleared; on merge `deletedAt` always wins. Deleting a match offers to delete the badges it produced. Any badge can be deleted on the device that has it; the deletion travels in the next card link.
- **Storage.** SwiftData locally (Room on Android). Only the name and badges go into a card link; photo, coaching notes and focus stay local. *(Removed 2026-09-30: one CloudKit record zone per card, synced with `CKSyncEngine`.)*
- **Exchange via links (WhatsApp).** *(Removed 2026-09-30: the `CKShare` invitation with live sync.)* A *snapshot* is `https://squashanalyzer.com/kaart#<compressed card>`: the app imports and merges it (showing what changes first); the Android app does the same; a browser renders the card, so anyone can see the badges. The data is in the fragment, which browsers never send to the server, so the website stores and sees nothing. After a match with new badges the app offers to share the card (image plus snapshot link); there is no automatic sync, so after new badges someone sends the card again.
- **Where badges show.** Not during the match (no interruption while counting). The "Wedstrijd klaar" screen shows a "Badges verdiend" strip and a "Bekijk badges" button next to "Deel score", only when a picked player earned something. The badge screen per player shows the badges new in this match, the collection with a count per badge ("5 op rij · 3×" = earned in 3 matches, one award per match), locked badges still to earn, and "Deel kaart". The same screen opens from the player list; history cards get a small medal icon for matches with a badge.
- **App Store / privacy.** No accounts (no in-app account deletion or Sign in with Apple needed), nothing public or searchable (no user-generated content moderation), and no data leaves the device except in links the user sends, so the privacy label can stay "Data Not Collected" (verify when filling it in). The privacy policy gets a paragraph on shared player cards, and the share flow asks to share only with the player's consent.

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
in `filesDir`; no SwiftData or Room change, not yet in the backup). UI in
SquashAnalyzerUI: `SharedTeamMatchesView` (list, new from the fixtures or
by hand), `SharedTeamMatchView`, `TeamPartijEditor` (roster chips from Mijn
team, scores or winner only, link picker with the match day on top) and
`TeamMatchLinkPrompt`, which both session views show once after a finished
match when `TeamMatchSupport.candidate` finds a team match of today (saved or
a fixture of Mijn team). Later: live per team match, SBN comparison, badge
category Teamspeler.

## Android port

A Skip-based (Swift → Kotlin/Compose) Android port is planned and in progress.
Android coach scoring now uses the shared `CoachMatchStore` boundary and
`CoachSessionView` to serialize edits with durable writes. `RoomCoachMatchStore`
maps live Swift models to the existing transactional `MatchStore`. Room schema
3 adds optional per-game service state through migration 2→3 (1→2 remains
available). Each point, undo, service-side change, game transition and explicit
exit saves; completed matches are retained but excluded from resume. Starting
over marks the previous match abandoned instead of deleting its history.
Android referee mode (`RefereeScoringView`/`RefereeSessionView` in
`SquashAnalyzerUI`, backed by the shared `RefereeMatch` in
`SquashAnalyzerCore`) now scores points, LET, STROKE, undo and game
transitions, and persists through the same pattern as coach mode: a
`RefereeMatchStore` protocol (`loadInProgress`/`save`/`abandon`) implemented
by `RoomRefereeMatchStore` over a dedicated, smaller Room schema
(`RefereeMatchEntity`/`RefereeGameEntity`/`RefereePointEntity`/
`RefereeCurrentPointEntity` — no point type/zone/shot columns, since referee
mode never tags those). `RefereeMatch.undo()` pops a private, in-memory
undo stack; a saved match keeps who served the game's first rally
(`openingServer`/`openingSide`, Room v8 and `RefereeMatchSnapshot`), and
`rebuildUndo()` rebuilds the stack from that and the timeline on resume, so
undo reaches back to the game's first rally on both platforms. Android
also now has a badges destination: `SharedBadgeCatalogView`/`BadgeMedallion`
in `SquashAnalyzerUI` render the full `BadgeKind` catalog (already pure and
shared via `BadgeEngine.swift` in `SquashAnalyzerCore`) with a placeholder
medallion instead of real artwork, the same scope-cut `PlayerAvatarPlaceholder`
made for photos. It needs no player or match data, so it shipped before real
per-player badge awards. `Match`/`RefereeMatch`'s `badgeInput`/`rallyWinners`
extensions live in `SquashAnalyzerCore` (`BadgeInput.swift`) for the same
reason. The `HomeMenuTiles` grid is shared between platforms, so this added a
fifth tile to iOS' own home screen too, wired there to iOS' existing,
separate `BadgeCatalogView` (real artwork attempts) rather than the Android
placeholder. Real per-player badge awards need a real player id on the
match, so Android's coach/referee match setup now has a "Kies speler" step
too: a new, shared `MatchSetupView` (a much smaller version of iOS' full
`MatchStartView` — two names, each optionally picked from the existing
player list, no head-start/coaching-focus setup) shown by `CoachSessionView`/
`RefereeSessionView` before a brand-new match is created, mirroring iOS'
`PickedPlayer` rule that editing the name after picking drops the id.
`PlayerProfile.id` (a `String`) bridges to `Match`/`RefereeMatch.player1Id`/
`player2Id` (`UUID?`) via `UUID(uuidString:)` at that point — no Core type
change needed. With a real player id available, Android computes and stores
real badge awards too: `BadgeAwardStore` (Room schema 6, table
`badge_awards`) is a behaviour-identical Kotlin counterpart of
`BadgeAwarder` without CloudKit, called from
`RoomCoachMatchStore`/`RoomRefereeMatchStore` on every `save()`/`abandon()`.
Its rows have the iOS `SavedBadgeAward` shape (card id, badge, match,
earnedAt, opponent name, awarding install id, deletedAt) and the shared
`AwardValue.awardId` id, so awards merge across platforms: an award lives on
the player's card (`players.cardId ?: players.id`, like `badgeCardId`), a
player without a `players` row earns nothing, an undone rally removes the
award outright, a deleted award stays deleted, and career badges are stored
with the decided match that earned them (history built like
`BadgeAwarder.history(of:)`: decided matches only, head start counted,
opponent keyed by id or lowercased name; once-only badges not awarded twice).
The install id is kept in the app's `SharedPreferences`. Earned badges are
now visible too: a shared `PlayerBadgeSummaryStore` protocol
(`badges(forPlayer:) -> [BadgeKind]`, `cardSnapshot(forPlayer:)`), implemented by `BadgeAwardStore`
itself, backs a badge-count pill on each row of `PlayerDirectoryView`
(Android's "Spelers" screen) and a new shared `SharedPlayerBadgesView`
(a `BadgeMedallion` grid, with a "Deel kaart" toolbar button that sends the
card as the same snapshot link iOS shares — `cardSnapshot(forPlayer:)` on the
protocol, the Android share sheet via a `shareText` closure that `MainActivity`
passes down and fills with `shareTextIntent`) it taps through to — and card links come back in the same way: `MainActivity` (`singleTask`,
intent-filters for `squashanalyzer.com/kaart` and `squashanalyzer://kaart`)
hands the link to a Core `CardInbox`, and `AndroidHomeView` shows
`SharedCardImportView` over any screen while one is pending; `BadgeAwardStore`
implements the Core `CardImportStore` with iOS' `CardStore` rules (link moves
the player's own awards onto the card, merge where a deletion wins, one
transaction); after an import `CardInbox.importCount` goes up and the open player list
and badge screen reload (`.task(id:)`). Checked end to end between the iOS
simulator, the Android emulator and the website (docs/android-port.md, step 6) — named `Shared...`, not
`PlayerBadgesView`, for the same reason as `SharedBadgeCatalogView`: the
iOS app target already has its own, richer `PlayerBadgesView`. A "Badges
verdiend" strip now shows on the match-over screen too: `SharedMatchBadgesStrip`
computes earnings the same way `BadgeAwardStore` does (running `BadgeEngine`
over the match's `badgeInput`), but purely for display, no store needed —
wired into both `CoachScoringView.matchOverBanner` and `RefereeScoringView`'s
match-over block.

Android also now has a read-only history browser: a shared
`MatchHistoryStore` protocol (`loadHistory() -> [MatchHistorySummary]`,
`MatchHistorySummary` a small flat record — names, games won, status, date,
not full point-by-point data) backs the "Afgeronde wedstrijden" tile.
`RoomMatchHistoryStore` merges completed/abandoned coach and referee
matches into one sorted list; games-won counts come straight from each
record's own game winners rather than restoring a live `Match`/
`RefereeMatch`, so a head start is not added in (an accepted simplification
for this summary list). The new `SharedMatchHistoryView` (much smaller than
iOS' full `MatchHistoryView` — no import/export, backup or filters, no
tap-through detail yet) renders it.

Mijn team runs on both platforms from Core: `LeagueTeamLink` (validation),
`LeagueTeamParser` (the SBN team and standings pages; a tiny `LeagueRegex`
wraps NSRegularExpression on Apple and `kotlin.text.Regex` on Android, since
Skip has no NSRegularExpression), `LeagueTeamFetcher` (the cookie-wall
consent and all sanity checks) and `LeagueTeamStorage` (same UserDefaults
keys as iOS). Only the page loader is per platform (`LeaguePageLoader`):
`URLSessionLeaguePageLoader` on iOS, `HttpLeaguePageLoader` (Kotlin,
HttpURLConnection + a process CookieManager) on Android, because Skip's
URLSession keeps no cookies and the cookie wall needs them. Android shows it
with `SharedLeagueTeamCard` on the home screen, `SharedLeagueTeamDetailView`,
and `SharedSettingsView` (the gear: team link and AI Coach key).

The coach dashboard's local advice (`CoachAdvice`) and AI Coach
(`AICoachPrompt`, `AICoachClient`) are in Core too; the platforms supply
`AICoachTransport` (URLSession on iOS, `HttpAICoachTransport` on Android) and
`APIKeyStore` (Keychain via `APIKeyManager` on iOS, `KeystoreAPIKeyStore`,
AES-GCM with an Android Keystore key, on Android). Android's
`SharedCoachDashboardView` opens from ANALYSE on a finished coach game.

Backups use one file format on both platforms: `FullBackup` and
`BackupCodec` (envelope + SHA-256 over sorted-key ISO 8601 JSON) are in Core;
Skip's JSONEncoder produces the same bytes as Apple's, so a backup from
either platform passes the checksum on the other (pinned by a test that runs
on both). iOS' `ExportService` and Android's `RoomBackupStore` map their
stores to and from it; Android picks files with the system document pickers
(`ActivityBackupFiles`). Automatic backups follow Core's `AutoBackupPlan`
(weekly, newest 7, made when the app goes to the background): iOS'
`AutomaticBackup` writes to iCloud Drive, Android's `AutoBackup` to a folder
the user picked.
Full plan, phase status, toolchain setup and transpile gotchas found so far:
see [`docs/android-port.md`](docs/android-port.md). Read that file before
touching anything Android-related, and keep it updated as phases complete.

## Sharing a score

`MatchShareReport` holds the three WhatsApp layouts (Kort, Scorekaart, Verslag, `MatchShareStyle`). Coach mode (`Match.shareReport`) and referee mode (`RefereeMatch.shareReport`) both build one, and both match-over / game-over screens open the same `MatchShareSheet`, so a change to the texts or the sheet applies to both modes.

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

- TestFlight: bump `CURRENT_PROJECT_VERSION`, then `xcodebuild archive` + `xcodebuild -exportArchive` (method `app-store-connect`, destination `upload`) with the App Store Connect API key (`~/.appstoreconnect/private_keys`, key id in `scripts/asc_api.py`). Distribution signing is cloud-managed via `-allowProvisioningUpdates`. `scripts/testflight_distribute.py --version X --build N --notes release-notes/X-N.md` waits for processing, sets the What to Test notes for testers (kept per build in `release-notes/`), adds the build to the external TestFlight group and submits it for beta review (internal groups receive builds automatically). To pull a build, expire it via the API (`PATCH /v1/builds/{id}` with `expired: true`).
- App Store screenshots: `scripts/screenshots.sh` builds a Debug app, launches it on the iPhone 17 Pro Max simulator once per `ScreenshotScenario` (`-screenshot <name>`, Debug builds only) and saves 6.9" PNGs to `screenshots/nl-NL`. `scripts/upload_screenshots.py` replaces the iPhone 6.9" set (API type `APP_IPHONE_67`) of the current `MARKETING_VERSION` in App Store Connect (`--create-version` when the version does not exist yet, `--dry-run` to preview).
- Every external build (TestFlight, later Google Play) also refreshes the App Store screenshots and the Dutch user manual on the website: `website/handleiding/` (`index.html` chooser, `iphone.html`, `android.html`, one section per home tile, screenshots in `img/iphone` and `img/android`, sample players Gerard and Thé). Check the manual against what the build does, retake changed screens (iOS via the `ScreenshotScenario` scenarios, Android on the emulator) and publish with the website (Gerd-Jan's OK first). When `website/style.css` changes, raise the `?v=` on every stylesheet link: Cloudflare caches CSS for 4 hours, and the apex and www hosts are cached separately.
