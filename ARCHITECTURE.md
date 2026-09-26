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

- `SquashAnalyzerSchemaV0` is a frozen copy of the models as shipped in App Store 2.0 (build 8, March 2026; unversioned `Schema([...])`). SwiftData matches an existing store to a schema by model shape, so the plan must start there or 2.0 users get "unknown model version" and the in-memory fallback. `SquashAnalyzerSchemaV1` (TestFlight 2.2 build 5: SavedMatch status/updatedAt/coaching fields) `SquashAnalyzerSchemaV2` (build 6: `SavedPlayer.photoData`) and `SquashAnalyzerSchemaV3` (build 7: `player1GamesBefore`/`player2GamesBefore` on `SavedMatch` and `SavedRefereeMatch`) are frozen too; `SquashAnalyzerSchemaV4` (`player1GamesAfter`/`player2GamesAfter` on `SavedMatch`) references the live classes and is the current schema (`SquashAnalyzerCurrentSchema`). `MigrationTests` writes a real 2.0-style store and opens it with the plan.
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

`Game` applies the same service-box rules in coach mode (`serverSide`, per-player preferred box, undo); `Match.startNewGame()` carries the preferred boxes into the next game. The box is not persisted: a game restored from the store derives the server from its last point (`restoreServiceState()`) and starts from the hand-out box until Links/Rechts is tapped. Both screens share `ServiceSideSelector`.

## Badges

Players earn badges during a match, in coach and referee mode, but only players picked from "Kies speler" (a typed-in name has no id and earns nothing). A player's badges are shared across the devices of every coach who tracks that player.

**Built so far (local, schema V5):** `BadgeKind` (stable raw values, stored and shared, never renamed) and `BadgeEngine`, which, like `ScoringEngine`, is pure: it takes the rally winners of a match in play order (`Match.rallyWinners`, `RefereeMatch.rallyWinners`) and returns the badges per player; runs carry over from one game into the next. The setup screen remembers a player picked in "Kies speler" (`PickedPlayer`; editing the name drops it) and passes `player1Id`/`player2Id` into `Match` and `RefereeMatch`, which are persisted. `BadgeAwarder.syncAwards` runs on every `MatchRepository.upsert` and when a referee match is saved, so an undone rally takes back an award while a deleted one stays deleted; discarding a match removes its awards, deleting one from the history marks them deleted. Awards go into the full backup (including deleted ones; import merges by award id). UI: `MatchBadgesStrip` on both match-over screens, `MatchBadgesSheet` / `PlayerBadgesView` with counts and the earning moments (`BadgeMomentsView`, swipe to delete), a badge count in the player list and a medal on history cards. `BadgeKind` has 31 badges (set 01–06); `BadgeCatalogView` (player list → medal) and `website/badges/index.html` list them all; the engine takes a `BadgeMatchInput` (rallies with shot and point type per game, head start, final stand, match winner) that `Match.badgeInput` and `RefereeMatch.badgeInput` build. Shot and service badges (`coachOnly`) can only be earned in coach mode. Career badges (`isCareer`: hat trick, off the mark, centurion, ten out of ten) come from `BadgeEngine.careerBadges` over the player's finished matches on this device (`BadgeAwarder.history`); the once-only ones (`isOnce`) are not awarded again when the card already has them. Artwork is `badge-<id>` in the asset catalog and `website/badges/<id>.png`; a badge without artwork gets a gold placeholder, and unearned badges are shown greyed out. Debug scenario `-screenshot badges` shows a finished match with badges. Sharing is built too: `CardSync` (two `CKSyncEngine`s, private and shared database; engine state in UserDefaults) keeps the `SavedPlayerCard`s in CloudKit in sync, `CardSnapshot` is the link format, `CardStore` merges awards and links players to cards (`link` moves the player's own awards onto the card), `CardShareActions` / `CardImportSheet` / `CardImportPresenter` are the UI, and `AppDelegate`/`SceneDelegate` register for pushes and accept shares (`CKSharingSupported` in `Info.plist`). The website has `kaart/index.html` (draws the card from the fragment, never sends it) and `.well-known/apple-app-site-association` (applinks for `/kaart*`); the app also opens `squashanalyzer://kaart#…`. The CloudKit schema is in `docs/cloudkit-schema.ckdb`; it must be deployed to Production in the CloudKit Console before a TestFlight build can share. The design below is what was built, except that a card only goes to iCloud when it is first shared ("Nodig coach uit"), not for every player.

**Planned design:**

- **Identity.** `SavedPlayer` gets a `cardId`; `SavedMatch` and `SavedRefereeMatch` get `player1Id`/`player2Id` (new `VersionedSchema`). Cards are matched on `cardId`, never on name.
- **Awards.** A `BadgeAward` is one earning moment with a deterministic id derived from (cardId, badgeKind, matchId), plus `earnedAt`, `awardedBy` and an optional `deletedAt`. A player has a badge while at least one award without `deletedAt` exists. Because badges derive from the point history, awards are recomputed for old matches once (backfill); recomputing never recreates an existing id, so a deleted badge does not come back, while a new match can earn it again.
- **Deletion is soft.** Deleting sets `deletedAt` on the awards, which is never cleared; on merge `deletedAt` always wins. Deleting a match offers to delete the badges it produced. The card owner may delete any badge, a coach the badges they awarded (enforced in the app; CloudKit permissions are per share, not per record).
- **Storage.** SwiftData locally, plus one CloudKit record zone per player card in the owner's private database, synced with `CKSyncEngine` (not SwiftData's CloudKit mirroring, which stays off). Only the name and badges go to the card; photo, coaching notes and focus stay local. The coach who first creates the player owns the card; CloudKit cannot transfer ownership, so a player who wants to own their card later starts a new one and the awards are merged (a union, since award ids are stable).
- **Exchange via links (WhatsApp).** An *invitation* is a `CKShare` URL: accepting it links a local player to the card ("Koppel aan bestaande speler") and from then on awards sync live in both directions, queued while offline. A *snapshot* is `https://squashanalyzer.com/kaart#<compressed card>`: the app imports and merges it (showing what changes first); a browser renders the card, so a player without an iPhone can see their badges. The data is in the fragment, which browsers never send to the server, so the website stores and sees nothing. After a match with new badges the app offers to share the card (image plus snapshot link); a coach not linked to the card sends the snapshot so a linked coach can import it.
- **Where badges show.** Not during the match (no interruption while counting). The "Wedstrijd klaar" screen shows a "Badges verdiend" strip and a "Bekijk badges" button next to "Deel score", only when a picked player earned something. The badge screen per player shows the badges new in this match, the collection with a count per badge ("5 op rij · 3×" = earned in 3 matches, one award per match), locked badges still to earn, and "Deel kaart" / "Nodig coach uit". The same screen opens from the player list; history cards get a small medal icon for matches with a badge.
- **Share permission.** The CKShare has `publicPermission = .readWrite`: anyone with the invitation link can join, which is what a WhatsApp group needs. Stopping sharing deletes the zone.
- **App Store / privacy.** No accounts (no in-app account deletion or Sign in with Apple needed), nothing public or searchable (no user-generated content moderation), and the developer cannot read iCloud data, so the privacy label can stay "Data Not Collected" (verify when filling it in). The privacy policy gets a paragraph on shared player cards, and the share flow asks to share only with the player's consent.

## Sharing a score

`MatchShareReport` holds the three WhatsApp layouts (Kort, Scorekaart, Verslag, `MatchShareStyle`). Coach mode (`Match.shareReport`) and referee mode (`RefereeMatch.shareReport`) both build one, and both match-over / game-over screens open the same `MatchShareSheet`, so a change to the texts or the sheet applies to both modes.

## Tests

`SquashAnalyzerTests` currently covers game completion, extension scoring, service/undo, unforced-error entry, empty statistics, repository upsert/recovery (including the restored server and the head start), backup checksum rejection, the coach WhatsApp text, the head start in both modes, completing an incomplete match (validation, persistence, backup, discard), the service rules in both modes (box alternation, hand-out, per-player preferred box, undo, next-game server), and the badge rules (5 in a row, broken runs, runs across games in both modes).


## Release

- TestFlight: bump `CURRENT_PROJECT_VERSION`, then `xcodebuild archive` + `xcodebuild -exportArchive` (method `app-store-connect`, destination `upload`) with the App Store Connect API key (`~/.appstoreconnect/private_keys`, key id in `scripts/asc_api.py`). Distribution signing is cloud-managed via `-allowProvisioningUpdates`. `scripts/testflight_distribute.py --version X --build N --notes release-notes/X-N.md` waits for processing, sets the What to Test notes for testers (kept per build in `release-notes/`), adds the build to the external TestFlight group and submits it for beta review (internal groups receive builds automatically). To pull a build, expire it via the API (`PATCH /v1/builds/{id}` with `expired: true`).
- App Store screenshots: `scripts/screenshots.sh` builds a Debug app, launches it on the iPhone 17 Pro Max simulator once per `ScreenshotScenario` (`-screenshot <name>`, Debug builds only) and saves 6.9" PNGs to `screenshots/nl-NL`. `scripts/upload_screenshots.py` replaces the iPhone 6.9" set of the current `MARKETING_VERSION` in App Store Connect (`--create-version` when the version does not exist yet, `--dry-run` to preview).
