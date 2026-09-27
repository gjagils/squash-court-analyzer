package com.squashanalyzer.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [MatchEntity::class, GameEntity::class, PointEntity::class, LetEntity::class, PlayerEntity::class],
    version = 3,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun matchDao(): MatchDao
    abstract fun playerDao(): PlayerDao

    companion object {
        @Volatile private var instance: AppDatabase? = null

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
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                    .build().also { instance = it }
            }
    }
}
