package com.squashanalyzer.android.league

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import skip.foundation.URL
import squash.analyzer.core.LeaguePage
import squash.analyzer.core.LeaguePageLoader
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.net.HttpURLConnection
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.StandardCharsets

/**
 * Android's page loader for Mijn team (Core's `LeagueTeamFetcher`), the
 * counterpart of iOS' `URLSessionLeaguePageLoader`. `HttpURLConnection` follows
 * redirects (a POST answered with 302 continues as GET) and uses the process
 * cookie handler, so SBN's cookie-wall consent cookie reaches the page it
 * redirects back to. Skip's URLSession has no cookie store, hence this class.
 */
class HttpLeaguePageLoader(private val maxBytes: Int = 5_000_000) : LeaguePageLoader {
    init {
        synchronized(CookieHandler::class.java) {
            if (CookieHandler.getDefault() == null) {
                CookieHandler.setDefault(CookieManager(null, CookiePolicy.ACCEPT_ORIGINAL_SERVER))
            }
        }
    }

    override suspend fun get(url: URL): LeaguePage = request(url, null)

    override suspend fun postForm(url: URL, body: String): LeaguePage = request(url, body)

    private suspend fun request(url: URL, formBody: String?): LeaguePage = withContext(Dispatchers.IO) {
        val connection = java.net.URL(url.absoluteString).openConnection() as HttpURLConnection
        try {
            connection.instanceFollowRedirects = true
            connection.connectTimeout = 20_000
            connection.readTimeout = 20_000
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 SquashAnalyzer/Android")
            connection.setRequestProperty("Accept-Language", "nl-NL,nl;q=0.9")
            if (formBody != null) {
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                connection.outputStream.use { it.write(formBody.toByteArray(StandardCharsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val bytes = stream?.use { readCapped(it) } ?: ByteArray(0)
            LeaguePage(
                finalURL = URL(string = connection.url.toString()),
                status = status,
                body = utf8(bytes),
                byteCount = bytes.size,
            )
        } finally {
            connection.disconnect()
        }
    }

    /** Stops reading past the limit; the fetcher then refuses the page as too big */
    private fun readCapped(input: InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        while (out.size() <= maxBytes) {
            val read = input.read(buffer)
            if (read < 0) break
            out.write(buffer, 0, read)
        }
        return out.toByteArray()
    }

    /** Strict UTF-8, like iOS' `String(data:encoding:)`: invalid bytes give null */
    private fun utf8(bytes: ByteArray): String? = try {
        StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString()
    } catch (e: CharacterCodingException) {
        null
    }
}
