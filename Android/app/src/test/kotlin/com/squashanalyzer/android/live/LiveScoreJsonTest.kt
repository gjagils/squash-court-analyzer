package com.squashanalyzer.android.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** org.json is part of Android, so these run under Robolectric */
@RunWith(RobolectricTestRunner::class)
class LiveScoreJsonTest {
    @Test fun readsAServerSnapshot() {
        val json = """
            {"p1":"Gerd-Jan","p2":"Thomas","bestOf":5,"games":[[11,8],[6,11]],"score":[4,2],
             "gamesWon":[1,1],"server":2,"side":"L","status":"playing","lastPoint":"Thomas: winner"}
        """.trimIndent()
        val score = LiveScoreJson.parse(json)!!
        assertEquals("Gerd-Jan", score.p1)
        assertEquals("Thomas", score.p2)
        assertEquals(5, score.bestOf)
        assertEquals(listOf(11 to 8, 6 to 11), score.games)
        assertEquals(4 to 2, score.score)
        assertEquals(1 to 1, score.gamesWon)
        assertEquals(2, score.server)
        assertEquals("L", score.side)
        assertEquals("playing", score.status)
        assertEquals("Thomas: winner", score.lastPoint)
        assertNull(score.winner)
    }

    @Test fun readsTheWinner() {
        val json = """{"p1":"A","p2":"B","bestOf":3,"games":[[11,1],[11,2]],"score":[11,2],"gamesWon":[2,0],"server":1,"side":"R","status":"finished","winner":1}"""
        val score = LiveScoreJson.parse(json)!!
        assertEquals("finished", score.status)
        assertEquals(1, score.winner)
    }

    @Test fun fillsInMissingOrOddFields() {
        val score = LiveScoreJson.parse("""{"p1":"","status":"dancing","server":7,"side":"X","bestOf":99,"winner":3}""")!!
        assertEquals("Speler 1", score.p1)
        assertEquals("Speler 2", score.p2)
        assertEquals("playing", score.status)
        assertEquals(1, score.server)
        assertEquals("R", score.side)
        assertEquals(9, score.bestOf)
        assertEquals(0 to 0, score.score)
        assertEquals(emptyList<Pair<Int, Int>>(), score.games)
        assertNull(score.winner)
        assertNull(score.lastPoint)
    }

    @Test fun notJsonIsNull() {
        assertNull(LiveScoreJson.parse("geen json"))
        assertNull(LiveScoreJson.parse("[1,2]"))
    }
}
