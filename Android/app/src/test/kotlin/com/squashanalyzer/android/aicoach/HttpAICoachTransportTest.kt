package com.squashanalyzer.android.aicoach

import kotlinx.coroutines.test.runTest
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary

/** The AI Coach sender against a local server; nothing reaches OpenAI */
@RunWith(RobolectricTestRunner::class)
class HttpAICoachTransportTest {
    private val server = MockWebServer()

    @Before fun start() = server.start()
    @After fun stop() = server.close()

    private fun url() = URL(string = server.url("/v1/chat/completions").toString())!!
    private fun data(text: String) = Data(platformValue = text.toByteArray(Charsets.UTF_8))

    @Test fun postsTheBodyWithTheHeaders() = runTest {
        server.enqueue(MockResponse.Builder().code(200).body("{\"ok\":true}").build())
        val headers = Dictionary<String, String>()
        headers["Authorization"] = "Bearer sk-test"
        headers["Content-Type"] = "application/json"

        val response = HttpAICoachTransport().post(url(), headers = headers, body = data("{\"model\":\"gpt-4o-mini\"}"))

        assertEquals(200, response.status)
        assertEquals("{\"ok\":true}", String(response.body.platformValue, Charsets.UTF_8))
        val request = server.takeRequest()
        assertEquals("POST", request.method)
        assertEquals("Bearer sk-test", request.headers["Authorization"])
        assertEquals("{\"model\":\"gpt-4o-mini\"}", request.body?.utf8())
    }

    @Test fun anErrorStatusIsReturnedNotThrown() = runTest {
        server.enqueue(MockResponse.Builder().code(401).body("{\"error\":\"bad key\"}").build())
        val response = HttpAICoachTransport().post(url(), headers = Dictionary(), body = data("{}"))
        assertEquals(401, response.status)
        assertEquals("{\"error\":\"bad key\"}", String(response.body.platformValue, Charsets.UTF_8))
    }
}
