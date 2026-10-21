package com.squashanalyzer.android.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import android.app.Application
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The team match on the lock screen: texts, rows E1-E4 and the bar (design
 * "Teamwedstrijd · Android"). The texts come from the resources (Dutch: values/), so Robolectric.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, qualifiers = "nl")
class TeamScoreCardTest {
    private fun cardOf(score: TeamScore) = TeamScoreCard(score, RuntimeEnvironment.getApplication())

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
        val card = cardOf(design)
        assertEquals("All Inn 8 1 – 1 Delft 8", card.title)
        assertEquals("1–1", card.chipText)
        assertEquals("E2 bezig: Paul 7–5 Mark (1–0) · games 5–3", card.text)
        assertEquals("E2 bezig 7–5 · 2 van 4 klaar", card.compactText)
        assertFalse(card.isFinished)
        assertEquals(listOf(1, 2, 3, 4), card.slots)
    }

    @Test fun theRows() {
        val rows = cardOf(design).rows
        assertEquals(4, rows.size)
        assertEquals(TeamScoreCard.Row(1, "E1", "Gerd-Jan", "Thomas", false, "3", "0", "–", false, 1), rows[0])
        assertEquals(TeamScoreCard.Row(2, "● E2", "Paul", "Mark", false, "1", "0", "7–5", true, 0), rows[1])
        assertEquals(2, rows[2].winner)
        assertEquals(TeamScoreCard.Row(4, "E4", "Anna", "Bram", false, "–", "–", "–", false, 0), rows[3])
    }

    @Test fun aSlotWithoutAPartijIsGreyedWithTheTeamName() {
        val card = cardOf(TeamScore("All Inn 8", "Delft 8", listOf(partij(1, gamesWon = 1 to 0, status = "playing"))))
        val row = card.rows[1]
        assertTrue(row.missing)
        assertEquals("All Inn 8 E2", row.home)
        assertEquals("Delft 8 E2", row.away)
        assertEquals("–", row.middle)
        assertEquals(listOf(1), card.slots)
    }

    @Test fun aPartijWithoutNamesUsesTheTeamAndSlot() {
        val card = cardOf(TeamScore("All Inn 8", "Delft 8", listOf(partij(3, p1 = "", p2 = "", status = "playing", score = 2 to 1))))
        assertEquals("All Inn 8 E3", card.rows[2].home)
        assertEquals("E3 bezig: All Inn 8 E3 2–1 Delft 8 E3 (0–0) · games 0–0", card.text)
    }

    @Test fun betweenGamesAndTwoPartijenAtOnce() {
        val card = cardOf(TeamScore("A", "B", listOf(
            partij(1, "Paul", "Mark", 1 to 1, 9 to 11, "between"),
            partij(2, "Anna", "Bram", 0 to 0, 3 to 4, "playing"),
        )))
        assertEquals("E1 pauze: Paul – Mark (1–1) (+1) · games 1–1", card.text)
        assertEquals("E1 pauze · E2 bezig 3–4 · 0 van 4 klaar", card.compactText)
        assertEquals("pauze", card.rows[0].middle)
        assertEquals("● E1", card.rows[0].label)
    }

    @Test fun walkoverAndRetiredAreDecided() {
        val card = cardOf(TeamScore("A", "B", listOf(
            partij(1, gamesWon = 0 to 3, status = "finished", winner = 2, end = "walkover"),
            partij(2, gamesWon = 1 to 1, status = "playing", end = "retired", winner = 1),
        )))
        assertEquals(2, card.decidedCount)
        assertEquals("w.o.", card.rows[0].middle)
        assertEquals("opgave", card.rows[1].middle)
        assertEquals(1, card.rows[1].winner)
    }

    @Test fun allFourDecidedIsTheResult() {
        val card = cardOf(TeamScore("All Inn 8", "Delft 8", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1),
            partij(2, gamesWon = 3 to 1, status = "finished", winner = 1),
            partij(3, gamesWon = 1 to 3, status = "finished", winner = 2),
            partij(4, gamesWon = 3 to 2, status = "finished"),
        )))
        assertTrue(card.isFinished)
        assertEquals(3 to 1, card.partijenWon)
        assertEquals("All Inn 8 3 – 1 Delft 8", card.title)
        assertEquals("Uitslag · partijen 3–1 · games 10–6", card.text)
        assertEquals("Uitslag · partijen 3–1 · games 10–6", card.compactText)
    }

    @Test fun theBarHasAPartPerPartijInTheWinnersColour() {
        val card = cardOf(design)
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
        val card = cardOf(TeamScore("A", "B", listOf(partij(1, status = "playing"), partij(2, gamesWon = 0 to 1, status = "between"))))
        assertEquals(TeamScoreCard.Segment(100, 3, live = true), card.segments[0])
        assertEquals(TeamScoreCard.Segment(100, 2, live = true), card.segments[1])
        assertEquals(4, card.segments.size)
    }

    // Design B (20 October 2026)

    @Test fun onePartijUnderWayIsTheFocusWithTheStrip() {
        val card = cardOf(TeamScore("All Inn 8", "Delft 8", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1),
            partij(2, gamesWon = 1 to 3, status = "finished", winner = 2),
            TeamPartij(3, "Bas", "Tim", 5, 1 to 1, 7 to 5, "playing", server = 2),
        )))
        assertEquals(TeamScoreCard.Focus.Live(listOf(card.score.partij(3)!!)), card.focus)
        assertEquals("E3 · bezig", card.focusHeading(3))
        assertEquals("games 1–1", card.gamesText(card.score.partij(3)!!))
        assertTrue(card.score.partij(3)!!.isServing(2))
        assertFalse(card.score.partij(3)!!.isServing(1))
        assertEquals("All Inn 8 1 – 1 Delft 8", card.title)
        assertEquals("E3 bezig: Bas 7–5 Tim (1–1) · games 5–4", card.text)
        assertEquals(
            listOf(
                TeamScoreCard.Tile(1, 1, "E1  3–0"),
                TeamScoreCard.Tile(2, 2, "E2  1–3"),
                TeamScoreCard.Tile(3, 4, "E3  bezig"),
                TeamScoreCard.Tile(4, 0, "E4  –"),
            ),
            card.tiles,
        )
    }

    @Test fun aPauseHasNoServeDot() {
        val paused = TeamPartij(3, "Bas", "Tim", 5, 1 to 1, 9 to 11, "between", server = 1)
        val card = cardOf(TeamScore("A", "B", listOf(paused)))
        assertEquals("E3 · pauze", card.focusHeading(3))
        assertFalse(paused.isServing(1))
        assertEquals("pauze", card.rows[2].middle)
    }

    @Test fun twoCourtsAtOnceAreTwoRows() {
        val card = cardOf(TeamScore("A", "B", listOf(
            partij(2, gamesWon = 1 to 0, score = 7 to 5, status = "playing"),
            partij(3, gamesWon = 0 to 1, score = 4 to 6, status = "playing"),
        )))
        val focus = card.focus as TeamScoreCard.Focus.Live
        assertEquals(listOf(2, 3), focus.partijen.map { it.slot })
    }

    @Test fun betweenPartijenTheNextOne() {
        var card = cardOf(TeamScore("A", "B", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1),
            partij(4, status = "warmup"),
        )))
        assertEquals(TeamScoreCard.Focus.Next(4), card.focus)
        assertEquals("E4 · inspelen", card.focusHeading(4))
        assertEquals("1 van 4 klaar · games 3–0", card.text)
        // Else the first not decided in the playing order E4, E2, E1, E3
        assertEquals(TeamScoreCard.Focus.Next(4), cardOf(TeamScore("A", "B", emptyList())).focus)
        card = cardOf(TeamScore("A", "B", listOf(partij(4, gamesWon = 3 to 0, status = "finished", winner = 1))))
        assertEquals(TeamScoreCard.Focus.Next(2), card.focus)
        assertEquals("Volgende partij · E2", card.focusHeading(2))
        card = cardOf(TeamScore("A", "B", listOf(
            partij(4, gamesWon = 3 to 0, status = "finished", winner = 1),
            partij(2, gamesWon = 1 to 3, status = "finished", winner = 2),
            partij(1, gamesWon = 3 to 1, status = "finished", winner = 1),
        )))
        assertEquals(TeamScoreCard.Focus.Next(3), card.focus)
    }

    @Test fun theResultAndItsWinnerByTheSbnRule() {
        // 2–2 in partijen: the away team lost a walkover, so home wins despite fewer games
        val card = cardOf(TeamScore("A", "B", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1, end = "walkover"),
            partij(2, gamesWon = 0 to 3, status = "finished", winner = 2),
            partij(3, gamesWon = 0 to 3, status = "finished", winner = 2),
            partij(4, gamesWon = 3 to 2, status = "finished", winner = 1),
        )))
        assertEquals(TeamScoreCard.Focus.Finished, card.focus)
        assertEquals(1, card.teamWinner)
        assertEquals("w.o.", card.rows[0].middle)
        assertEquals("–", card.rows[1].middle)
        assertEquals(TeamScoreCard.Tile(1, 1, "E1  w.o."), card.tiles[0])
        // Equal partijen and line-up: most games
        val games = cardOf(TeamScore("A", "B", listOf(
            partij(1, gamesWon = 3 to 2, status = "finished", winner = 1),
            partij(2, gamesWon = 0 to 3, status = "finished", winner = 2),
        )))
        assertEquals(2, games.teamWinner)
    }

    /** Any phone whose first language is not Dutch gets English (HostLocale); team names stay as they are */
    @Test @Config(qualifiers = "en")
    fun englishTexts() {
        val card = cardOf(design)
        assertEquals("All Inn 8 1 – 1 Delft 8", card.title)
        assertEquals("E2 in play: Paul 7–5 Mark (1–0) · games 5–3", card.text)
        assertEquals("E2 in play 7–5 · 2 of 4 done", card.compactText)
        assertEquals("E2 · in play", card.focusHeading(2))
        assertEquals("Next match · E3", cardOf(TeamScore("A", "B", emptyList())).focusHeading(3))
        assertEquals(TeamScoreCard.Tile(2, 4, "E2  in play"), card.tiles[1])
        val ended = cardOf(TeamScore("A", "B", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1, end = "walkover"),
            partij(2, gamesWon = 0 to 1, status = "between"),
        )))
        assertEquals("w/o", ended.rows[0].middle)
        assertEquals("break", ended.rows[1].middle)
        assertTrue(ended.rows[1].isPause)
        assertEquals("E2 · break", ended.focusHeading(2))
    }

    @Test @Config(qualifiers = "de")
    fun englishOnAGermanPhone() {
        val card = cardOf(TeamScore("All Inn 8", "Delft 8", listOf(
            partij(1, gamesWon = 3 to 0, status = "finished", winner = 1),
            partij(2, gamesWon = 3 to 1, status = "finished", winner = 1),
            partij(3, gamesWon = 1 to 3, status = "finished", winner = 2),
            partij(4, gamesWon = 3 to 2, status = "finished", end = "retired"),
        )))
        assertEquals("Result · matches 3–1 · games 10–6", card.text)
        assertEquals("retired", card.rows[3].middle)
    }
}

/** org.json is part of Android: Robolectric */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, qualifiers = "nl")
class TeamScoreJsonTest {
    @Test fun parsesTheServersPush() {
        val json = """{"home":"All Inn 8","away":"Delft 8","partijen":[
            {"slot":2,"p1":"Paul","p2":"Mark","bestOf":5,"gamesWon":[1,0],"score":[7,5],"status":"playing","server":2},
            {"slot":1,"p1":"Gerd-Jan","p2":"","bestOf":3,"gamesWon":[2,0],"score":[11,3],"status":"finished","winner":1},
            {"slot":4,"p1":"","p2":"","bestOf":5,"gamesWon":[0,3],"score":[0,0],"status":"finished","end":"walkover","winner":2},
            {"slot":9,"p1":"X","p2":"Y"}]}"""
        val score = TeamScore.parse(json, RuntimeEnvironment.getApplication())!!
        assertEquals("All Inn 8", score.home)
        assertEquals(listOf(1, 2, 4), score.partijen.map { it.slot })
        assertEquals(TeamPartij(1, "Gerd-Jan", "", 3, 2 to 0, 11 to 3, "finished", 1, null), score.partij(1))
        assertEquals("walkover", score.partij(4)!!.end)
        assertEquals(2, score.partij(2)!!.server)
        assertNull(score.partij(1)!!.server)
        assertNull(score.partij(3))
        assertNull(TeamScore.parse("geen json", RuntimeEnvironment.getApplication()))
    }

    /** Gerd-Jan's pool (21 October 2026): in full up to 16 characters, else short, as iOS */
    @Test fun teamNamesOnTheLockScreen() {
        assertEquals("All Inn Squash 8", TeamNames.short("All Inn Squash 8"))
        assertEquals("All Inn Squash 9", TeamNames.short("All Inn Squash 9"))
        assertEquals("Squash Delft 5", TeamNames.short("Squash Delft 5"))
        assertEquals("Squash Delft 7", TeamNames.short("Squash Delft 7"))
        assertEquals("Squash Delft 8", TeamNames.short("Squash Delft 8"))
        assertEquals("Sluipers 1", TeamNames.short("Sluipers, RLT & SV De 1"))
        assertEquals("Leiden 4", TeamNames.short("Sportcity Leiden 4"))
        assertEquals("Utrecht 11", TeamNames.short("Squash Utrecht 11"))
        assertEquals("Woerden 1", TeamNames.short("Sportcity Woerden 1"))
        assertEquals("Gouda 1", TeamNames.short("Sportcity Gouda 1"))
        assertEquals("Squash Squash Squash 1", TeamNames.short("Squash Squash Squash 1"))
    }
}
