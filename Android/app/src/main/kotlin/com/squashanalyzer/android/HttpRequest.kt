package com.squashanalyzer.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary
import squash.analyzer.core.AITransportResponse
import java.net.HttpURLConnection

/**
 * One HTTPS request on Dispatchers.IO, shared by AI Coach and live meekijken.
 * An error status is returned, not thrown, so the caller can name it
 * (401 = wrong API key, 404 = lost live session); no network does throw.
 */
object HttpRequest {
    suspend fun send(method: String, url: URL, headers: Dictionary<String, String>, body: Data?, timeoutMillis: Int): AITransportResponse =
        withContext(Dispatchers.IO) {
            val connection = java.net.URL(url.absoluteString).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = timeoutMillis
                connection.readTimeout = timeoutMillis
                for ((name, value) in headers) {
                    connection.setRequestProperty(name, value)
                }
                if (body != null) {
                    connection.doOutput = true
                    connection.outputStream.use { it.write(body.platformValue) }
                }
                val status = connection.responseCode
                val stream = if (status >= 400) connection.errorStream else connection.inputStream
                val bytes = stream?.use { it.readBytes() } ?: ByteArray(0)
                AITransportResponse(status = status, body = Data(platformValue = bytes))
            } finally {
                connection.disconnect()
            }
        }
}
