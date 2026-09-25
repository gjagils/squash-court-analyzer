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

## Tests

`SquashAnalyzerTests` currently covers game completion, extension scoring, service/undo, unforced-error entry, empty statistics, repository upsert/recovery (including the restored server and the head start), backup checksum rejection, the coach WhatsApp text, the head start in both modes, completing an incomplete match (validation, persistence, backup, discard), and the service rules in both modes (box alternation, hand-out, per-player preferred box, undo, next-game server).


## Release

- TestFlight: bump `CURRENT_PROJECT_VERSION`, then `xcodebuild archive` + `xcodebuild -exportArchive` (method `app-store-connect`, destination `upload`) with the App Store Connect API key (`~/.appstoreconnect/private_keys`, key id in `scripts/asc_api.py`). Distribution signing is cloud-managed via `-allowProvisioningUpdates`. `scripts/testflight_distribute.py --version X --build N --notes release-notes/X-N.md` waits for processing, sets the What to Test notes for testers (kept per build in `release-notes/`), adds the build to the external TestFlight group and submits it for beta review (internal groups receive builds automatically). To pull a build, expire it via the API (`PATCH /v1/builds/{id}` with `expired: true`).
- App Store screenshots: `scripts/screenshots.sh` builds a Debug app, launches it on the iPhone 17 Pro Max simulator once per `ScreenshotScenario` (`-screenshot <name>`, Debug builds only) and saves 6.9" PNGs to `screenshots/nl-NL`. `scripts/upload_screenshots.py` replaces the iPhone 6.9" set of the current `MARKETING_VERSION` in App Store Connect (`--create-version` when the version does not exist yet, `--dry-run` to preview).
