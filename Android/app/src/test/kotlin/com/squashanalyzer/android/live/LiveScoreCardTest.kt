package com.squashanalyzer.android.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveScoreCardTest {
    private fun score(
        score: Pair<Int, Int> = 0 to 0,
        games: List<Pair<Int, Int>> = emptyList(),
        gamesWon: Pair<Int, Int> = 0 to 0,
        status: String = "playing",
        server: Int = 1,
        side: String = "R",
        bestOf: Int = 5,
        winner: Int? = null,
    ) = LiveScoreCard(
        LiveScore(
            p1 = "Gerd-Jan", p2 = "Thomas", bestOf = bestOf, games = games, score = score,
            gamesWon = gamesWon, server = server, side = side, status = status, winner = winner,
        ),
    )

    @Test fun playingShowsTheScoreAndWhoServes() {
        val card = score(9 to 7, games = listOf(11 to 8), gamesWon = 1 to 0, server = 2, side = "L")
        assertEquals("9–7", card.chipText)
        assertEquals("Gerd-Jan 9 – 7 Thomas", card.title)
        assertEquals("Thomas serveert links · games 1–0", card.text)
        assertEquals("Game 2 · games 1–0 · Thomas serveert", card.compactText)
        assertEquals("Game 2 · best of 5", card.tickerStatus)
        assertEquals(null, card.serveText(1))
        assertEquals("serveert links", card.serveText(2))
        assertEquals(listOf(LiveScoreCard.GameChip("11–8", 1)), card.chips)
        assertNull(card.gameBallFor)
    }

    @Test fun gameBallAtTenWithTheLead() {
        val card = score(10 to 8)
        assertEquals(1, card.gameBallFor)
        assertFalse(card.isMatchBall)
        assertEquals("Gamebal voor Gerd-Jan · games 0–0", card.text)
        assertEquals("Game 1 · gamebal Gerd-Jan", card.compactText)
        assertEquals("Game 1 · gamebal", card.tickerStatus)
    }

    @Test fun noGameBallAtTenAll() {
        assertNull(score(10 to 10).gameBallFor)
        // Two clear points: 11-10 is game ball again
        assertEquals(1, score(11 to 10).gameBallFor)
        assertEquals(2, score(12 to 13).gameBallFor)
    }

    @Test fun matchBallWhenTheGameDecidesTheMatch() {
        val card = score(7 to 10, games = listOf(11 to 8, 9 to 11, 5 to 11), gamesWon = 1 to 2)
        assertEquals(2, card.gameBallFor)
        assertTrue(card.isMatchBall)
        assertEquals("Matchbal voor Thomas · games 1–2", card.text)
        assertEquals("Game 4 · matchbal Thomas", card.compactText)
        assertEquals("Game 4 · matchbal", card.tickerStatus)
    }

    @Test fun noGameBallOutsidePlay() {
        assertNull(score(11 to 9, games = listOf(11 to 9), gamesWon = 1 to 0, status = "between").gameBallFor)
    }

    @Test fun betweenGamesSaysWhoWonTheGame() {
        val card = score(6 to 11, games = listOf(11 to 8, 6 to 11), gamesWon = 1 to 1, status = "between")
        assertEquals("Pauze", card.chipText)
        assertEquals("Thomas wint game 2 met 11–6", card.title)
        assertEquals("Games 1–1 · game 3 begint zo", card.text)
        assertEquals(card.text, card.compactText)
        assertEquals("Pauze · game 3 begint zo", card.tickerStatus)
        // The points of the game just finished stay, as on the website
        assertEquals(6, card.points(1))
        assertEquals(11, card.points(2))
    }

    @Test fun finishedShowsTheWinnerFirst() {
        val card = score(
            9 to 11, games = listOf(11 to 8, 6 to 11, 9 to 11, 8 to 11),
            gamesWon = 1 to 3, status = "finished", winner = 2,
        )
        assertEquals("3–1", card.chipText)
        assertEquals("Thomas wint 3–1", card.title)
        assertEquals("11–8 · 6–11 · 9–11 · 8–11", card.text)
        assertEquals("Thomas wint 3–1", card.tickerStatus)
        assertTrue(card.isFinished)
        // The winner gets a cup, nobody serves any more
        assertNull(card.serveText(1))
        assertNull(card.serveText(2))
        assertEquals(
            listOf(
                LiveScoreCard.GameChip("11–8", 1),
                LiveScoreCard.GameChip("6–11", 2),
                LiveScoreCard.GameChip("9–11", 2),
                LiveScoreCard.GameChip("8–11", 2),
            ),
            card.chips,
        )
        assertEquals(1, card.gamesWon(1))
        assertEquals(3, card.gamesWon(2))
    }

    @Test fun finishedWithoutWinnerUsesTheGames() {
        val card = score(11 to 4, games = listOf(11 to 2, 11 to 3, 11 to 4), gamesWon = 3 to 0, status = "finished")
        assertEquals("3–0", card.chipText)
        assertEquals("Gerd-Jan wint 3–0", card.title)
    }

    @Test fun warmup() {
        val card = score(status = "warmup", bestOf = 3)
        assertEquals("Inspelen · best of 3", card.text)
        assertEquals("Inspelen · best of 3", card.tickerStatus)
        assertTrue(card.chips.isEmpty())
        assertEquals(2, card.gamesToWin)
    }

    @Test fun namesInTheNotificationCannotBreak() {
        assertEquals("Gerd\u2011Jan", LiveScoreCard.unbreakable("Gerd-Jan"))
        assertEquals("All\u00A0Inn\u00A0Squash\u00A08", LiveScoreCard.unbreakable("All Inn Squash 8"))
    }

    @Test fun initialsAreOneCapitalLetter() {
        assertEquals("G", LiveScoreCard.initialOf("gerd-Jan"))
        assertEquals("É", LiveScoreCard.initialOf(" émile"))
        assertEquals("?", LiveScoreCard.initialOf("  "))
        // A letter outside the BMP stays whole
        assertEquals("\uD835\uDC00", LiveScoreCard.initialOf("\uD835\uDC00bc"))
        assertEquals("T", score().initial(2))
    }

    @Test fun gameBarHasOneStretchOfElevenPerGame() {
        val card = score(6 to 3, games = listOf(11 to 8, 9 to 11), gamesWon = 1 to 1)
        assertEquals(
            listOf(
                LiveScoreCard.Segment(11, 1),
                LiveScoreCard.Segment(11, 2),
                LiveScoreCard.Segment(6, 1),
                LiveScoreCard.Segment(5, 0),
                LiveScoreCard.Segment(11, 0),
                LiveScoreCard.Segment(11, 0),
            ),
            card.segments,
        )
        assertEquals(28, card.progress)
        assertEquals(55, card.progressMax)
    }

    @Test fun gameBarAtTheStartAndInDeuce() {
        val start = score()
        assertEquals(List(5) { LiveScoreCard.Segment(11, 0) }, start.segments)
        assertEquals(0, start.progress)
        // 13-12 fills the game to 11, not past it
        val deuce = score(13 to 12, bestOf = 3)
        assertEquals(LiveScoreCard.Segment(11, 1), deuce.segments.first())
        assertEquals(33, deuce.progressMax)
    }

    @Test fun gameBarPutsAHeadStartFirst() {
        // One game head start for player 2, no games played yet
        val card = score(2 to 0, gamesWon = 0 to 1, bestOf = 3)
        assertEquals(
            listOf(LiveScoreCard.Segment(11, 2), LiveScoreCard.Segment(2, 1), LiveScoreCard.Segment(9, 0), LiveScoreCard.Segment(11, 0)),
            card.segments,
        )
    }

    @Test fun finishedBarIsFullyPlayedGames() {
        val card = score(11 to 9, games = listOf(11 to 5, 11 to 9), gamesWon = 2 to 0, status = "finished", bestOf = 3)
        assertEquals(
            listOf(LiveScoreCard.Segment(11, 1), LiveScoreCard.Segment(11, 1), LiveScoreCard.Segment(11, 0)),
            card.segments,
        )
        assertEquals(22, card.progress)
    }
}
