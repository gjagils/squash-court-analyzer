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

- `SquashAnalyzerSchemaV1` is the baseline `VersionedSchema`.
- Future model changes must add `SquashAnalyzerSchemaV2` (or later) and a `MigrationStage`; do not edit an already shipped historical schema definition.
- A failed store open never deletes the store. Store files are copied to `Application Support/Recovery/<timestamp>` and the app starts with a clearly disclosed in-memory fallback.
- Full backups use a versioned envelope containing schema version, app version and a SHA-256 checksum.
- Restore validates and decodes the entire backup before deleting existing records.
- The seven newest dated iCloud backups plus `latest-backup.json` are retained.

## Domain rules

`ScoringEngine` owns the pure scoring rules (11 points, win by 2). UI code and persistence models should not duplicate those rules; `Game` and `RefereeMatch` both delegate to it. Add new rule behavior to the engine with tests first.

`RefereeMatch` owns the service rules for referee mode: a server who wins the rally alternates service box, a hand-out puts the new server in the right box (the referee can correct this with the side chips), and the winner of a game serves first in the next game. Every rally won is recorded in `pointHistory`, which drives the scoring line between the two players.

## Tests

`SquashAnalyzerTests` currently covers game completion, extension scoring, service/undo, unforced-error entry, empty statistics, repository upsert/recovery, backup checksum rejection, and the referee service rules (box alternation, hand-out, side override, undo, next-game server).

