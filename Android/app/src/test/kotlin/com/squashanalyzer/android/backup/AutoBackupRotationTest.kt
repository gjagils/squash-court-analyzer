package com.squashanalyzer.android.backup

import android.content.Context
import android.webkit.MimeTypeMap
import androidx.documentfile.provider.DocumentFile
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.io.File

/** Writing into the backup folder keeps the newest 7 dated backups and leaves other files alone */
@RunWith(RobolectricTestRunner::class)
class AutoBackupRotationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val dir = File(context.cacheDir, "auto-backup-test")

    @Before fun before() {
        dir.deleteRecursively()
        dir.mkdirs()
        shadowOf(MimeTypeMap.getSingleton()).addExtensionMimeTypeMapping("json", "application/json")
    }
    @After fun after() { dir.deleteRecursively() }

    @Test fun keepsTheNewestSevenAndOtherFiles() {
        File(dir, "notities.txt").writeText("blijft")
        val folder = DocumentFile.fromFile(dir)
        for (day in 1..9) {
            AutoBackup.writeAndRotate(context, folder, "backup $day".toByteArray(), "squash-backup-2026-09-0$day-120000.json")
        }
        val names = dir.list()!!.sorted()
        assertEquals(8, names.size)
        assertTrue("notities.txt" in names)
        assertFalse("squash-backup-2026-09-02-120000.json" in names)
        assertTrue("squash-backup-2026-09-03-120000.json" in names)
        assertEquals("backup 9", File(dir, "squash-backup-2026-09-09-120000.json").readText())
    }
}
