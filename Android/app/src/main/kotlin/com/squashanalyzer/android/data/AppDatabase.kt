package com.squashanalyzer.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import skip.foundation.UUID
import squash.analyzer.core.AwardValue
import squash.analyzer.core.BadgeKind

@Database(
    entities = [
        MatchEntity::class, GameEntity::class, PointEntity::class, LetEntity::class, PlayerEntity::class,
        RefereeMatchEntity::class, RefereeGameEntity::class, RefereePointEntity::class, RefereeCurrentPointEntity::class,
        BadgeAwardEntity::class,
    ],
    version = 6,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun matchDao(): MatchDao
    abstract fun playerDao(): PlayerDao
    abstract fun refereeMatchDao(): RefereeMatchDao
    abstract fun badgeAwardDao(): BadgeAwardDao

    companion object {
        @Volatile private var instance: AppDatabase? = null

        /**
         * Rebuilds `badge_awards` in the iOS shape (card instead of player,
         * opponent name, awarding install, shared deterministic id). Rows with
         * `deletedAt` set are dropped: before this version Android only set it
         * when an undone rally retracted a badge (there was no delete action),
         * and iOS removes those outright — carried over they would block the
         * badge for good and travel in card links as deletions.
         */
        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE badge_awards_new (
                        id TEXT NOT NULL PRIMARY KEY,
                        cardId TEXT NOT NULL,
                        badge TEXT NOT NULL,
                        matchId TEXT NOT NULL,
                        earnedAt INTEGER NOT NULL,
                        opponentName TEXT NOT NULL,
                        awardedBy TEXT NOT NULL,
                        deletedAt INTEGER
                    )
                """.trimIndent())
                db.query("""
                    SELECT a.badge, a.matchId, a.earnedAt, COALESCE(p.cardId, a.playerId)
                    FROM badge_awards a LEFT JOIN players p ON p.id = a.playerId
                    WHERE a.deletedAt IS NULL
                """.trimIndent()).use { rows ->
                    while (rows.moveToNext()) {
                        val badge = BadgeKind.init(rawValue = rows.getString(0)) ?: continue
                        val matchId = rows.getString(1)
                        val cardId = rows.getString(3)
                        val matchUuid = UUID(uuidString = matchId) ?: continue
                        val cardUuid = UUID(uuidString = cardId) ?: continue
                        val id = AwardValue.awardId(cardId = cardUuid, badge = badge, matchId = matchUuid).uuidString
                        db.execSQL(
                            "INSERT OR IGNORE INTO badge_awards_new (id, cardId, badge, matchId, earnedAt, opponentName, awardedBy, deletedAt) VALUES (?, ?, ?, ?, ?, '', '', NULL)",
                            arrayOf<Any>(id, cardId, badge.rawValue, matchId, rows.getLong(2)),
                        )
                    }
                }
                db.execSQL("DROP TABLE badge_awards")
                db.execSQL("ALTER TABLE badge_awards_new RENAME TO badge_awards")
                db.execSQL("CREATE INDEX IF NOT EXISTS index_badge_awards_cardId ON badge_awards (cardId)")
                db.execSQL("CREATE INDEX IF NOT EXISTS index_badge_awards_matchId ON badge_awards (matchId)")
            }
        }

        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS badge_awards (
                        id TEXT NOT NULL PRIMARY KEY,
                        playerId TEXT NOT NULL,
                        badge TEXT NOT NULL,
                        matchId TEXT NOT NULL,
                        earnedAt INTEGER NOT NULL,
                        deletedAt INTEGER
                    )
                """.trimIndent())
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS referee_matches (
                        id TEXT NOT NULL PRIMARY KEY,
                        player1Name TEXT NOT NULL,
                        player2Name TEXT NOT NULL,
                        player1Id TEXT,
                        player2Id TEXT,
                        bestOf INTEGER NOT NULL,
                        player1GamesBefore INTEGER NOT NULL,
                        player2GamesBefore INTEGER NOT NULL,
                        player1Score INTEGER NOT NULL,
                        player2Score INTEGER NOT NULL,
                        currentServer TEXT NOT NULL,
                        serverSide TEXT NOT NULL,
                        currentGameNumber INTEGER NOT NULL,
                        player1PreferredSide TEXT,
                        player2PreferredSide TEXT,
                        matchStartedAt INTEGER NOT NULL,
                        gameStartedAt INTEGER NOT NULL,
                        lastPointAt INTEGER,
                        savedAt INTEGER NOT NULL,
                        updatedAt INTEGER NOT NULL,
                        status TEXT NOT NULL
                    )
                """.trimIndent())
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS referee_games (
                        id TEXT NOT NULL PRIMARY KEY,
                        matchId TEXT NOT NULL,
                        number INTEGER NOT NULL,
                        player1Score INTEGER NOT NULL,
                        player2Score INTEGER NOT NULL,
                        winner TEXT NOT NULL,
                        duration REAL NOT NULL,
                        FOREIGN KEY(matchId) REFERENCES referee_matches(id) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS index_referee_games_matchId ON referee_games(matchId)")
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS referee_points (
                        id TEXT NOT NULL PRIMARY KEY,
                        gameId TEXT NOT NULL,
                        pointNumber INTEGER NOT NULL,
                        scorer TEXT NOT NULL,
                        score INTEGER NOT NULL,
                        side TEXT NOT NULL,
                        isStroke INTEGER NOT NULL,
                        FOREIGN KEY(gameId) REFERENCES referee_games(id) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS index_referee_points_gameId ON referee_points(gameId)")
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS referee_current_points (
                        id TEXT NOT NULL PRIMARY KEY,
                        matchId TEXT NOT NULL,
                        pointNumber INTEGER NOT NULL,
                        scorer TEXT NOT NULL,
                        score INTEGER NOT NULL,
                        side TEXT NOT NULL,
                        isStroke INTEGER NOT NULL,
                        FOREIGN KEY(matchId) REFERENCES referee_matches(id) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS index_referee_current_points_matchId ON referee_current_points(matchId)")
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE games ADD COLUMN serviceState TEXT DEFAULT NULL")
            }
        }

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS players (
                        id TEXT NOT NULL PRIMARY KEY,
                        name TEXT NOT NULL,
                        coachingFocusAreas TEXT NOT NULL,
                        coachingNotes TEXT NOT NULL,
                        createdAt REAL NOT NULL,
                        photoData BLOB,
                        cardId TEXT
                    )
                """.trimIndent())
            }
        }

        /** Games/points/lets cascade-delete with their match; SQLite needs this pragma explicitly. */
        private val enableForeignKeys = object : Callback() {
            override fun onOpen(db: SupportSQLiteDatabase) {
                super.onOpen(db)
                db.execSQL("PRAGMA foreign_keys=ON")
            }
        }

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "squash-analyzer.db",
                ).addCallback(enableForeignKeys)
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6)
                    .build().also { instance = it }
            }
    }
}
