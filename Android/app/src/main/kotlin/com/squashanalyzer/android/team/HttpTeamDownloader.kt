package com.squashanalyzer.android.team

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Data
import skip.foundation.URL
import squash.analyzer.core.TeamDownloader
import squash.analyzer.core.TeamImport
import squash.analyzer.core.TeamImportError
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection

/**
 * Downloads a team zip from squashanalyzer.com/teams, the counterpart of iOS'
 * `URLSessionTeamDownloader`: status 200, at most `TeamImport.maxBytes`, and
 * it must start like a zip file.
 */
class HttpTeamDownloader : TeamDownloader {
    override suspend fun download(url: URL): Data = withContext(Dispatchers.IO) {
        val connection = java.net.URL(url.absoluteString).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 30_000
            connection.readTimeout = 60_000
            connection.setRequestProperty("User-Agent", "SquashAnalyzer/Android")
            if (connection.responseCode != 200) throw TeamImportError.unavailable
            val limit = TeamImport.maxBytes
            val out = ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                    if (out.size() > limit) throw TeamImportError.tooLarge
                }
            }
            val data = Data(platformValue = out.toByteArray())
            if (!TeamImport.looksLikeZip(data)) throw TeamImportError.notAZip
            data
        } finally {
            connection.disconnect()
        }
    }
}
