package com.squashanalyzer.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [MatchEntity::class, GameEntity::class, PointEntity::class, LetEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun matchDao(): MatchDao

    companion object {
        @Volatile private var instance: AppDatabase? = null

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
                ).addCallback(enableForeignKeys).build().also { instance = it }
            }
    }
}
