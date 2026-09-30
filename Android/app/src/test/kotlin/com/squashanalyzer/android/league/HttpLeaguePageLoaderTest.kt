package com.squashanalyzer.android.league

import kotlinx.coroutines.test.runTest
import mockwebserver3.Dispatcher
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import mockwebserver3.RecordedRequest
import okio.Buffer
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.foundation.URL

/**
 * The loader against a local server that behaves like SBN's cookie wall: a
 * page without the consent cookie redirects to /cookiewall, the consent POST
 * sets the cookie and redirects back. No request leaves this machine.
 */
@RunWith(RobolectricTestRunner::class)
class HttpLeaguePageLoaderTest {
    private val server = MockWebServer()
    private val posted = mutableListOf<String>()

    private fun url(path: String) = URL(string = server.url(path).toString())!!

    private fun page(status: Int, body: String) = MockResponse.Builder().code(status).body(body).build()
    private fun redirect(location: String) = MockResponse.Builder().code(302).addHeader("Location", location).build()

    @Before fun start() {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                val path = request.url.encodedPath
                return when {
                    path == "/team" && (request.headers["Cookie"] ?: "").contains("consent=1") -> page(200, "<h2>SC Hugo 1 – Jaïr</h2>")
                    path == "/team" -> redirect("/cookiewall?ReturnUrl=%2Fteam")
                    path == "/cookiewall/Save" && request.method == "POST" -> {
                        posted.add(request.body?.utf8() ?: "")
                        MockResponse.Builder().code(302).addHeader("Set-Cookie", "consent=1; Path=/").addHeader("Location", "/team").build()
                    }
                    path == "/cookiewall" -> page(200, "<form action=\"/cookiewall/Save\">")
                    path == "/broken" -> page(500, "fout")
                    path == "/latin1" -> MockResponse.Builder().code(200).body(Buffer().write(byteArrayOf(0xE9.toByte()))).build()
                    path == "/big" -> page(200, "x".repeat(50_000))
                    else -> page(404, "")
                }
            }
        }
        server.start()
    }

    @After fun stop() = server.close()

    @Test fun cookieWallConsentCarriesTheCookieThroughTheRedirect() = runTest {
        val loader = HttpLeaguePageLoader()
        val wall = loader.get(url("/team"))
        assertEquals(200, wall.status)
        assertTrue(wall.finalURL!!.path.contains("cookiewall"))
        assertTrue(wall.body!!.contains("/cookiewall/Save"))

        val page = loader.postForm(url("/cookiewall/Save"), body = "ReturnUrl=/team&SettingsOpen=true&CookiePurposes=1")
        assertEquals(listOf("ReturnUrl=/team&SettingsOpen=true&CookiePurposes=1"), posted)
        assertEquals(200, page.status)
        assertEquals("/team", page.finalURL!!.path)
        assertEquals("<h2>SC Hugo 1 – Jaïr</h2>", page.body)
    }

    @Test fun errorsAndNonUtf8AreReportedNotThrown() = runTest {
        val loader = HttpLeaguePageLoader()
        val broken = loader.get(url("/broken"))
        assertEquals(500, broken.status)
        assertEquals("fout", broken.body)
        val latin1 = loader.get(url("/latin1"))
        assertNull(latin1.body)
        assertEquals(1, latin1.byteCount)
    }

    @Test fun bigPagesStopBeingReadPastTheLimit() = runTest {
        val page = HttpLeaguePageLoader(maxBytes = 1_000).get(url("/big"))
        assertTrue(page.byteCount in 1_001..50_000)
    }
}
