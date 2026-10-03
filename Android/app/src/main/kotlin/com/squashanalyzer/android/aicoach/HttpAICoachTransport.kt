package com.squashanalyzer.android.aicoach

import com.squashanalyzer.android.HttpRequest
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary
import squash.analyzer.core.AICoachTransport
import squash.analyzer.core.AITransportResponse

/**
 * Android's sender for AI Coach (Core's `AICoachClient`), the counterpart of
 * iOS' `URLSessionAICoachTransport`: one HTTPS POST (or GET for the model list)
 * with the given headers, through `HttpRequest`.
 * An error status is returned, not thrown, so the client can name it
 * (401 = wrong API key).
 */
class HttpAICoachTransport(private val timeoutMillis: Int = 60_000) : AICoachTransport {
    override suspend fun post(url: URL, headers: Dictionary<String, String>, body: Data): AITransportResponse =
        HttpRequest.send("POST", url, headers, body, timeoutMillis)

    override suspend fun get(url: URL, headers: Dictionary<String, String>): AITransportResponse =
        HttpRequest.send("GET", url, headers, null, timeoutMillis)
}
