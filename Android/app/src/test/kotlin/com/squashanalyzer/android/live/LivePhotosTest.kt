package com.squashanalyzer.android.live

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Color
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

/** The avatars of the live score notification: the server's flags, the cache, the drawings */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class LivePhotosTest {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val match = FollowedMatch("abcdefgh2345", "https://live.squashanalyzer.com")
    private val other = FollowedMatch("zzzzzzzz9999", "https://live.squashanalyzer.com")
    private val dir get() = File(app.filesDir, "live-photos")

    @Test fun readsWhichPhotosTheServerHas() {
        assertEquals(listOf(true, false), LivePhotos.photoFlags("""{"snapshot":{},"photos":[true,false],"photoVersion":1}"""))
        assertEquals(listOf(false, true), LivePhotos.photoFlags("""{"photos":[false,true]}"""))
        // An older server without flags, or no JSON at all: no photos
        assertEquals(listOf(false, false), LivePhotos.photoFlags("""{"snapshot":{}}"""))
        assertEquals(listOf(false, false), LivePhotos.photoFlags("Afgelopen"))
    }

    @Test fun roundCropsTheCentreSquare() {
        val wide = Bitmap.createBitmap(200, 100, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) }
        val round = LivePhotos.round(wide, 64)
        assertEquals(64, round.width)
        assertEquals(64, round.height)
    }

    @Test fun avatarsAndThePairHaveTheirSize() {
        val first = LivePhotos.avatar(null, "G", 1, 96)
        val second = LivePhotos.avatar(Bitmap.createBitmap(50, 80, Bitmap.Config.ARGB_8888), "T", 2, 96)
        assertEquals(96, first.width)
        val pair = LivePhotos.pair(first, second, 144)
        assertEquals(144, pair.width)
        assertEquals(144, pair.height)
    }

    @Test fun deletingTheFollowRemovesItsPhotosOnly() {
        dir.mkdirs()
        val mine = listOf(File(dir, "${match.id}-1.png"), File(dir, "${match.id}-2.png"), File(dir, "${match.id}.checked"))
        val theirs = listOf(File(dir, "${other.id}-1.png"), File(dir, "${other.id}.checked"))
        (mine + theirs).forEach { file -> file.writeText("x") }
        assertFalse(LivePhotos.needsFetch(app, match))

        LivePhotos.deleteAllExcept(app, listOf(match))
        assertTrue(mine.all { file -> file.exists() })
        assertTrue(theirs.none { file -> file.exists() })
        assertTrue(LivePhotos.needsFetch(app, other))

        LivePhotos.delete(app, match)
        assertTrue(mine.none { file -> file.exists() })
        assertTrue(LivePhotos.needsFetch(app, match))
    }

    @Test fun loadsAStoredPhoto() {
        assertNull(LivePhotos.load(app, match, 1))
        dir.mkdirs()
        val bitmap = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888)
        File(dir, "${match.id}-1.png").outputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, out) }
        assertNotNull(LivePhotos.load(app, match, 1))
        LivePhotos.delete(app, match)
    }
}
