package com.squashanalyzer.android.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import android.app.Application
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The team match on the lock screen: texts, rows E1-E4 and the bar (design "Teamwedstrijd · Android") */
class TeamScoreCardTest {
    private fun partij(
        slot: Int, p1: String = "Thuis$slot", p2: String = "Uit$slot", gamesWon: Pair<Int, Int> = 0 to 0,
        score: Pair<Int, Int> = 0 to 0, status: String = "warmup", winner: Int? = null, end: String? = null,
    ) = TeamPartij(slot, p1, p2, 5, gamesWon, score, status, winner, end)

    /** As the design: E1 3–0 home, E2 under way 7–5 (games 1–0), E3 1–3 away, E4 not started */
    private val design = TeamScore(
        "All Inn 8", "Delft 8",
        listOf(
            partij(1, "Gerd-Jan", "Thomas", 3 to 0, 11 to 6, "finished", winner = 1),
            partij(2, "Paul", "Mark", 1 to 0, 7 to 5, "playing"),
            partij(3, "Luis", "Niels", 1 to 3, 7 to 11, "finished", winner = 2),
            partij(4, "Anna", "Bram"),
        ),
    )

    @Test fun theDesignsTexts() {
        val card = TeamScoreCard(design)
        assertEquals("All Inn 8 5 – 3 Delft 8", card.title)
        assertEquals("5–3", card.chipText)
        assertEquals("Competitie · 2 van 4 klaar", card.header)
        assertEquals("E2 bezig: Paul 7–5 Mark · 2 van 4 klaar", card.text)
        assertEquals("E2 bezig 7–5 · 2 van 4 klaar", card.compactText)
        assertFalse(card.isFinished)
        assertEquals(listOf(1, 2, 3, 4), card.slots)
    }

    @Test fun theRows() {
        val rows = TeamScoreCard(design).rows
        assertEquals(4, rows.size)
        assertEquals(TeamScoreCard.Row(1, "E1", "Gerd-Jan", "Thomas", false, "3", "0", "klaar", false, 1), rows[0])
        assertEquals(TeamScoreCard.Row(2, "● E2", "Paul", "Mark", false, "1", "0", "7–5", true, 0), rows[1])
        assertEquals(2, rows[2].winner)
        assertEquals(TeamScoreCard.Row(4, "E4", "Anna", "Bram", false, "–", "–", "–", false, 0), rows[3])
    }

    @Test fun aSlotWithoutAPartijIsGreyedWithTheTeamName() {
        val card = TeamScoreCard(TeamScore("All Inn 8", "Delft 8", listOf(partij(1, gamesWon = 1 to 0, status = "playing"))))
        val row = card.rows[1]
        assertTrue(row.missing)
        assertEquals("All Inn 8 E2", row.home)
        assertEquals("Delft 8 E2", row.away)
        assertEquals("–", row.middle)
        assertEquals(listOf(1), card.slots)
    }

    @Test fun aPartijWithoutNamesUsesTheTeamAndSlot() {
        val card = TeamScoreCard(TeamScore("All Inn 8", "Delft 8", listOf(partij(3, p1 = "", p2 = "", status = "playing", score = 2 to 1))))
        assertEquals("All Inn 8 E3", card.rows[2].home)
        assertEquals("E3 bezig: All Inn 8 E3 2–1 Delft 8 E3 · 0 van 4 klaar", card.text)
    }

    @Test fun betweenGamesAndTwoPartijenAtOnce() {
        val card = TeamScoreCard(TeamScore("A", "B", listOf(
            partij(1, "Paul", "Mark", 1 to 1, 9 to 11, "between"),
            partij(2, "Anna", "Bram", 0 to 0, 3 to 4, "playing"),
        )))
        assertEquals("E1 pauze: Paul – Mark, games 1–1 (+1) · 0 van 4 klaar", card.text)
        assertEquals("E1 pauze · E2 bezig 3–4 · 0 van 4 klaar", card.compactText)
        assertEquals("pauze", card.rows[0].middle)
        assertEquals("● E1", card.rows[0].label)
    }

    @Test fun walkoverAndRetiredAreDecided() {
        val card = TeamScoreCard(TeamScore("A", "B", listOf(
            partij(1, gamesWon = 0 to 3, status = "finished", winner = 2, end = "walkover"),
            partij(2, gamesWon = 1 to 1, status = "playing", end = "retired", winner = 1),
        )))
        assertEquals(2, card.decidedCount)
        assertEquals("w.o.", card.rows[0].middle)
        assertEquals("opgave", card.rows[1].middle)
        assertEquals(1, card.rows[1].winner)
    }

    @Test fun allFourDecidedIsTheResult() {
        val card = TeamScoreCard(TeamScore("All Inn 8", "Delft 8", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1),
            partij(2, gamesWon = 3 to 1, status = "finished", winner = 1),
            partij(3, gamesWon = 1 to 3, status = "finished", winner = 2),
            partij(4, gamesWon = 3 to 2, status = "finished"),
        )))
        assertTrue(card.isFinished)
        assertEquals(3 to 1, card.partijenWon)
        assertEquals("All Inn 8 10 – 6 Delft 8", card.title)
        assertEquals("Uitslag · partijen 3–1", card.header)
        assertEquals("Uitslag · partijen 3–1", card.text)
        assertEquals("Uitslag · partijen 3–1", card.compactText)
    }

    @Test fun theBarHasAPartPerPartijInTheWinnersColour() {
        val card = TeamScoreCard(design)
        assertEquals(
            listOf(
                TeamScoreCard.Segment(100, 1),
                TeamScoreCard.Segment(100, 1, live = true),
                TeamScoreCard.Segment(100, 2),
                TeamScoreCard.Segment(100, 0),
            ),
            card.segments,
        )
    }

    @Test fun aLevelPartijUnderWayIsNeutral() {
        val card = TeamScoreCard(TeamScore("A", "B", listOf(partij(1, status = "playing"), partij(2, gamesWon = 0 to 1, status = "between"))))
        assertEquals(TeamScoreCard.Segment(100, 3, live = true), card.segments[0])
        assertEquals(TeamScoreCard.Segment(100, 2, live = true), card.segments[1])
        assertEquals(4, card.segments.size)
    }
}

/** org.json is part of Android: Robolectric */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class TeamScoreJsonTest {
    @Test fun parsesTheServersPush() {
        val json = """{"home":"All Inn 8","away":"Delft 8","partijen":[
            {"slot":2,"p1":"Paul","p2":"Mark","bestOf":5,"gamesWon":[1,0],"score":[7,5],"status":"playing"},
            {"slot":1,"p1":"Gerd-Jan","p2":"","bestOf":3,"gamesWon":[2,0],"score":[11,3],"status":"finished","winner":1},
            {"slot":4,"p1":"","p2":"","bestOf":5,"gamesWon":[0,3],"score":[0,0],"status":"finished","end":"walkover","winner":2},
            {"slot":9,"p1":"X","p2":"Y"}]}"""
        val score = TeamScore.parse(json)!!
        assertEquals("All Inn 8", score.home)
        assertEquals(listOf(1, 2, 4), score.partijen.map { it.slot })
        assertEquals(TeamPartij(1, "Gerd-Jan", "", 3, 2 to 0, 11 to 3, "finished", 1, null), score.partij(1))
        assertEquals("walkover", score.partij(4)!!.end)
        assertNull(score.partij(3))
        assertNull(TeamScore.parse("geen json"))
    }
}
