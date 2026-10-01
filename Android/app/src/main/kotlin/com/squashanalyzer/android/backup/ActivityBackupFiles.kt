package com.squashanalyzer.android.backup

import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Data
import squash.analyzer.core.BackupFiles

/**
 * The Android file pickers behind "Maak back-up" / "Zet back-up terug": the
 * system's Create/Open document screens, so the user picks Google Drive,
 * Downloads or any other provider; the app needs no storage permission.
 * Must be created in `onCreate` (activity-result launchers are registered
 * before the activity starts).
 */
class ActivityBackupFiles(private val activity: ComponentActivity) : BackupFiles {
    private var pendingSave: CompletableDeferred<Uri?>? = null
    private var pendingOpen: CompletableDeferred<Uri?>? = null

    private val createLauncher = activity.registerForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        pendingSave?.complete(uri)
    }
    private val openLauncher = activity.registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        pendingOpen?.complete(uri)
    }

    override suspend fun save(data: Data, suggestedName: String): Boolean {
        val result = CompletableDeferred<Uri?>()
        pendingSave = result
        withContext(Dispatchers.Main) { createLauncher.launch(suggestedName) }
        val uri = result.await() ?: return false
        withContext(Dispatchers.IO) {
            requireNotNull(activity.contentResolver.openOutputStream(uri, "wt")) { "Kan het bestand niet schrijven" }
                .use { it.write(data.platformValue) }
        }
        return true
    }

    override suspend fun open(): Data? {
        val result = CompletableDeferred<Uri?>()
        pendingOpen = result
        withContext(Dispatchers.Main) { openLauncher.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }
        val uri = result.await() ?: return null
        val bytes = withContext(Dispatchers.IO) {
            requireNotNull(activity.contentResolver.openInputStream(uri)) { "Kan het bestand niet lezen" }.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                    require(out.size() <= MAX_BYTES) { "Dit bestand is te groot voor een back-up" }
                }
                out.toByteArray()
            }
        }
        return Data(platformValue = bytes)
    }

    companion object {
        /** Backups with player photos stay well below this */
        const val MAX_BYTES = 100 * 1024 * 1024
    }
}
