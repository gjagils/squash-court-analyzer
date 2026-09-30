package com.squashanalyzer.android.aicoach

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary
import squash.analyzer.core.AICoachTransport
import squash.analyzer.core.AITransportResponse
import java.net.HttpURLConnection

/**
 * Android's sender for AI Coach (Core's `AICoachClient`), the counterpart of
 * iOS' `URLSessionAICoachTransport`: one HTTPS POST with the given headers.
 * An error status is returned, not thrown, so the client can name it
 * (401 = wrong API key).
 */
class HttpAICoachTransport(private val timeoutMillis: Int = 60_000) : AICoachTransport {
    override suspend fun post(url: URL, headers: Dictionary<String, String>, body: Data): AITransportResponse = withContext(Dispatchers.IO) {
        val connection = java.net.URL(url.absoluteString).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = timeoutMillis
            connection.readTimeout = timeoutMillis
            connection.doOutput = true
            for ((name, value) in headers) {
                connection.setRequestProperty(name, value)
            }
            connection.outputStream.use { it.write(body.platformValue) }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val bytes = stream?.use { it.readBytes() } ?: ByteArray(0)
            AITransportResponse(status = status, body = Data(platformValue = bytes))
        } finally {
            connection.disconnect()
        }
    }
}
