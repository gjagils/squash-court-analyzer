package com.squashanalyzer.android.live

import com.squashanalyzer.android.HttpRequest
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary
import squash.analyzer.core.AITransportResponse
import squash.analyzer.core.LiveTransport

/**
 * Android's sender for live meekijken (Core's `LiveShare`), the counterpart of
 * iOS' `URLSessionLiveTransport`: one request (POST, PUT or DELETE) to the
 * live server, through `HttpRequest`. An error status is returned, not thrown,
 * so `LiveShare` can tell a lost session (404) from no network.
 */
class HttpLiveTransport(private val timeoutMillis: Int = 10_000) : LiveTransport {
    override suspend fun send(method: String, url: URL, headers: Dictionary<String, String>, body: Data?): AITransportResponse =
        HttpRequest.send(method, url, headers, body, timeoutMillis)
}
