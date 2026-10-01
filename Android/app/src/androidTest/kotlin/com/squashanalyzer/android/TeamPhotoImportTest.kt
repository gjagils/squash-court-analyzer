package com.squashanalyzer.android

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.team.RoomTeamImporter
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Team photos are scaled with the real Android image decoder: square, at most 512px */
@RunWith(AndroidJUnit4::class)
class TeamPhotoImportTest {
    @Test fun aTeamPhotoBecomesASquareOfAtMost512() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java).build()
        try {
            val image = ByteArrayOutputStream().also {
                Bitmap.createBitmap(700, 1400, Bitmap.Config.ARGB_8888).compress(Bitmap.CompressFormat.PNG, 100, it)
            }.toByteArray()
            val zip = ByteArrayOutputStream().also { out ->
                ZipOutputStream(out).use { zip ->
                    zip.putNextEntry(ZipEntry("team.json"))
                    zip.write("""{"players":[{"name":"Niels","photo":"photos/n.png"}]}""".toByteArray())
                    zip.closeEntry()
                    zip.putNextEntry(ZipEntry("photos/n.png"))
                    zip.write(image)
                    zip.closeEntry()
                }
            }.toByteArray()

            val result = RoomTeamImporter(db).importZip(zip)
            assertEquals(1, result.photos)
            val stored = db.playerDao().all().single().photoData!!
            val photo = BitmapFactory.decodeByteArray(stored, 0, stored.size)
            assertEquals(photo.width, photo.height)
            assertTrue(photo.width == 512)
        } finally {
            db.close()
        }
    }
}
