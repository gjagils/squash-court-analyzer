package com.squashanalyzer.android.live

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary
import squash.analyzer.core.AITransportResponse
import squash.analyzer.core.LiveTransport
import java.net.HttpURLConnection

/**
 * Android's sender for live meekijken (Core's `LiveShare`), the counterpart of
 * iOS' `URLSessionLiveTransport`: one request (POST, PUT or DELETE) to the
 * live server. An error status is returned, not thrown, so `LiveShare` can
 * tell a lost session (404) from no network.
 */
class HttpLiveTransport(private val timeoutMillis: Int = 10_000) : LiveTransport {
    override suspend fun send(method: String, url: URL, headers: Dictionary<String, String>, body: Data?): AITransportResponse =
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
