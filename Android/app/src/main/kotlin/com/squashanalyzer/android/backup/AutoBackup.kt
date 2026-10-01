package com.squashanalyzer.android.backup

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Date
import squash.analyzer.core.AutoBackupControl
import squash.analyzer.core.AutoBackupPlan
import squash.analyzer.core.BackupCodec
import squash.analyzer.core.BackupStore

/**
 * Automatic backups on Android: once the user picks a folder (the system
 * folder picker; the app keeps a persistent permission for it), a backup is
 * written there at most once a day when the app comes to the foreground, and
 * only the newest 7 dated files are kept. The rules come from Core's
 * `AutoBackupPlan`, the file format from `BackupCodec` (same file as iOS).
 * Must be created in `onCreate` (it registers an activity-result launcher).
 */
class AutoBackup(
    private val activity: ComponentActivity,
    private val store: BackupStore,
    private val appVersion: String,
) : AutoBackupControl {
    private val prefs = activity.getSharedPreferences("squash-analyzer", Context.MODE_PRIVATE)
    private var pendingFolder: CompletableDeferred<Uri?>? = null
    private val folderLauncher = activity.registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        pendingFolder?.complete(uri)
    }

    private fun folderUri(): Uri? = prefs.getString(KEY_FOLDER, null)?.let(Uri::parse)

    private fun folder(): DocumentFile? = folderUri()?.let { DocumentFile.fromTreeUri(activity, it) }

    override fun folderName(): String? = folderUri()?.let { folder()?.name ?: "gekozen map" }

    override fun lastBackupDate(): Date? =
        prefs.getLong(KEY_LAST, 0L).takeIf { it > 0 }?.let { Date(timeIntervalSince1970 = it / 1000.0) }

    override suspend fun turnOn(): Boolean {
        val result = CompletableDeferred<Uri?>()
        pendingFolder = result
        withContext(Dispatchers.Main) { folderLauncher.launch(null) }
        val uri = result.await() ?: return false
        activity.contentResolver.takePersistableUriPermission(uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        prefs.edit().putString(KEY_FOLDER, uri.toString()).apply()
        backUp()
        return true
    }

    override fun turnOff() {
        folderUri()?.let { uri ->
            runCatching {
                activity.contentResolver.releasePersistableUriPermission(uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }
        }
        prefs.edit().remove(KEY_FOLDER).apply()
    }

    /** Called when the app comes to the foreground; a failure is retried next time */
    suspend fun runIfDue() {
        if (folderUri() == null || !AutoBackupPlan.isDue(lastBackup = lastBackupDate(), now = Date())) return
        runCatching { backUp() }
    }

    private suspend fun backUp() {
        val target = requireNotNull(folder()) { "De back-upmap is niet meer bereikbaar" }
        val data = BackupCodec.encode(store.makeBackup(), appVersion = appVersion, createdAt = Date())
        withContext(Dispatchers.IO) { writeAndRotate(activity, target, data.platformValue, AutoBackupPlan.fileName(at = Date())) }
        prefs.edit().putLong(KEY_LAST, System.currentTimeMillis()).apply()
    }

    companion object {
        private const val KEY_FOLDER = "autoBackupFolder"
        private const val KEY_LAST = "autoBackupLastMillis"

        /**
         * Writes one dated backup into `folder` and removes all but the newest 7.
         * The name goes in without ".json": providers add the extension for the
         * MIME type themselves; one that does not gets the file renamed.
         */
        fun writeAndRotate(context: Context, folder: DocumentFile, bytes: ByteArray, name: String) {
            val base = name.removeSuffix(".json")
            val file = requireNotNull(folder.createFile("application/json", base)) { "Kan geen bestand maken in de back-upmap" }
            if (file.name?.endsWith(".json") != true) file.renameTo("$base.json")
            requireNotNull(context.contentResolver.openOutputStream(file.uri, "wt")) { "Kan het back-upbestand niet schrijven" }
                .use { it.write(bytes) }
            val files = folder.listFiles().filter { it.isFile }
            val names = files.mapNotNull { it.name }
            val expired = AutoBackupPlan.filesToDelete(skip.lib.Array(names), keep = AutoBackupPlan.keep).toSet()
            files.filter { it.name in expired }.forEach { it.delete() }
        }
    }
}
