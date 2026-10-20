package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.lib.Array as SwiftArray
import squash.analyzer.core.BackupCodec
import squash.analyzer.core.BackupStore
import squash.analyzer.core.TeamMatchStore
import squash.analyzer.core.TestDataCleanup
import squash.analyzer.core.TestDataCleanupStore
import squash.analyzer.core.TestDataCounts
import squash.analyzer.core.TestDataGroup
import squash.analyzer.core.TestDataMatch
import java.io.File

/**
 * Android's "Testgegevens opruimen" after the badge reset, the counterpart of
 * iOS' `SwiftDataTestDataStore`: the same matches through Core's
 * `TestDataCleanup`, removed like a deletion from the history (badges marked
 * deleted), after a full backup in the app's own files.
 */
class RoomTestDataStore(
    private val matches: MatchStore,
    private val refereeMatches: RefereeMatchStore,
    private val badges: BadgeAwardStore,
    private val teamMatches: TeamMatchStore,
    private val backupStore: BackupStore,
    private val appVersion: String,
    /** Where the backup from before the cleanup goes (`filesDir/Voor opruimen`) */
    private val backupDirectory: File,
) : TestDataCleanupStore {

    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis / 1000.0)

    private fun value(match: MatchRecord) = TestDataMatch(
        startedAt = date(match.savedAt), player1Name = match.player1Name, player2Name = match.player2Name,
        isUnfinished = match.status != MatchStatus.COMPLETED,
    )

    private fun value(match: RefereeMatchRecord) = TestDataMatch(
        startedAt = date(match.matchStartedAt), player1Name = match.player1Name, player2Name = match.player2Name,
        isUnfinished = match.status != MatchStatus.COMPLETED,
    )

    override suspend fun counts(before: Date): TestDataCounts {
        val all = matches.all().map { value(it) } + refereeMatches.all().map { value(it) }
        val teams = teamMatches.loadAll().toList().map { it.date }
        return TestDataCleanup.counts(matches = SwiftArray(all), teamMatchDates = SwiftArray(teams), before = before,
            earlierBadges = badges.countEarnedBefore(before))
    }

    override suspend fun backUp() {
        val data = BackupCodec.encode(backupStore.makeBackup(), appVersion = appVersion)
        backupDirectory.mkdirs()
        File(backupDirectory, "squashanalyzer-voor-opruimen-${System.currentTimeMillis()}.json").writeBytes(data.platformValue)
    }

    override suspend fun remove(groups: SwiftArray<TestDataGroup>, before: Date) {
        badges.inTransaction {
            for (match in matches.all()) {
                if (!TestDataCleanup.removes(value(match), chosen = groups, before = before)) continue
                matches.delete(match)
                badges.markMatchDeleted(match.id)
            }
            for (match in refereeMatches.all()) {
                if (!TestDataCleanup.removes(value(match), chosen = groups, before = before)) continue
                refereeMatches.delete(match)
                badges.markMatchDeleted(match.id)
            }
        }
        if (groups.contains(TestDataGroup.competition)) {
            for (team in teamMatches.loadAll().toList()) {
                if (team.date.timeIntervalSince1970 < before.timeIntervalSince1970) teamMatches.delete(id = team.id)
            }
        }
    }
}
