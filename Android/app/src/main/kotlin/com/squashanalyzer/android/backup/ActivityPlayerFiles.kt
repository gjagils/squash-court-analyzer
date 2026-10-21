package com.squashanalyzer.android.backup

import com.squashanalyzer.android.R
import com.squashanalyzer.android.hostText
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Data
import squash.analyzer.core.PlayerFilePicker

/**
 * The system pickers for the player screens: a photo from the gallery
 * (Android's photo picker, no permission needed) and a team zip from the
 * files. Must be created in `onCreate`, like `ActivityBackupFiles`.
 */
class ActivityPlayerFiles(private val activity: ComponentActivity) : PlayerFilePicker {
    private var pending: CompletableDeferred<Uri?>? = null

    private val photoLauncher = activity.registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        pending?.complete(uri)
    }
    private val zipLauncher = activity.registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        pending?.complete(uri)
    }

    override suspend fun pickPhoto(): Data? {
        val result = CompletableDeferred<Uri?>()
        pending = result
        withContext(Dispatchers.Main) {
            photoLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        return read(result.await() ?: return null)
    }

    override suspend fun pickTeamZip(): Data? {
        val result = CompletableDeferred<Uri?>()
        pending = result
        withContext(Dispatchers.Main) { zipLauncher.launch(arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream")) }
        return read(result.await() ?: return null)
    }

    private suspend fun read(uri: Uri): Data = withContext(Dispatchers.IO) {
        val bytes = requireNotNull(activity.contentResolver.openInputStream(uri)) { activity.hostText(R.string.file_read_failed) }.use { input ->
            val out = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                out.write(buffer, 0, read)
                require(out.size() <= MAX_BYTES) { activity.hostText(R.string.file_too_large) }
            }
            out.toByteArray()
        }
        Data(platformValue = bytes)
    }

    companion object {
        const val MAX_BYTES = 50 * 1024 * 1024
    }
}
