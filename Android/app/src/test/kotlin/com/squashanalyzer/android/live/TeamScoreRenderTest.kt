package com.squashanalyzer.android.live

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import java.io.File
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Not a check but a picture: renders the Android 9-15 team notification
 * (collapsed and expanded, light and dark) to PNG for a design review,
 * without an emulator. Skipped unless TEAM_RENDER_DIR is set:
 *
 *   TEAM_RENDER_DIR=/tmp/team ./gradlew testDebugUnitTest --tests '*TeamScoreRenderTest*'
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [34], qualifiers = "w392dp-h850dp-xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TeamScoreRenderTest {
    private fun partij(
        slot: Int, p1: String, p2: String, gamesWon: Pair<Int, Int>, score: Pair<Int, Int>, status: String,
        winner: Int? = null, end: String? = null, server: Int? = null,
    ) = TeamPartij(slot, p1, p2, 5, gamesWon, score, status, winner, end, server)

    private val home = "Squash Delft 8"
    private val away = "All Inn Squash 8"
    private val e1 = partij(1, "Gerard", "Thé", 3 to 0, 11 to 4, "finished", winner = 1)
    private val e2 = partij(2, "Sanne", "Mila", 1 to 3, 8 to 11, "finished", winner = 2)

    private val states = listOf(
        "tijdens" to TeamScore(home, away, listOf(e1, e2, partij(3, "Bas", "Tim", 1 to 1, 7 to 5, "playing", server = 1))),
        "pauze" to TeamScore(home, away, listOf(e1, e2, partij(3, "Bas", "Tim", 1 to 1, 9 to 11, "between"))),
        "twee-tegelijk" to TeamScore(home, away, listOf(
            e1, partij(2, "Sanne", "Mila", 1 to 0, 4 to 6, "playing", server = 2), partij(3, "Bas", "Tim", 1 to 1, 7 to 5, "playing", server = 1),
        )),
        "tussen-partijen" to TeamScore(home, away, listOf(e1, e2, partij(3, "Bas", "Tim", 0 to 0, 0 to 0, "warmup"))),
        "na-afloop" to TeamScore(home, away, listOf(
            e1, e2, partij(3, "Bas", "Tim", 3 to 1, 11 to 6, "finished", winner = 1),
            partij(4, "Niels", "", 3 to 0, 0 to 0, "finished", winner = 1, end = "walkover"),
        )),
    )

    @Test fun render() {
        val dir = System.getenv("TEAM_RENDER_DIR")
        assumeTrue(dir != null)
        val out = File(dir!!).apply { mkdirs() }
        val match = FollowedMatch("render", "https://live.squashanalyzer.com", FollowedMatch.TEAM)
        val texts = StringBuilder()
        for (night in listOf(false, true)) {
            RuntimeEnvironment.setQualifiers(if (night) "+night" else "+notnight")
            val context: Context = RuntimeEnvironment.getApplication()
            for ((name, score) in states) {
                val card = TeamScoreCard(score)
                val shade = if (night) "donker" else "licht"
                save(context, TeamScoreViews.expanded(context, match, card), File(out, "android-$name-$shade.png"), night)
                save(context, TeamScoreViews.collapsed(context, card), File(out, "android-$name-$shade-ingeklapt.png"), night)
                if (!night) texts.append("$name\n  titel: ${card.title}\n  tekst: ${card.text}\n  chip:  ${card.chipText}\n")
            }
        }
        File(out, "android16-teksten.txt").writeText(texts.toString())
    }

    /** As in the notification shade: 16 dp side padding on a card of the phone's width */
    private fun save(context: Context, views: RemoteViews, file: File, night: Boolean) {
        val density = context.resources.displayMetrics.density
        val parent = FrameLayout(context)
        val view = views.apply(context, parent)
        val pad = (16 * density).toInt()
        val width = (392 * density).toInt()
        val holder = FrameLayout(context).apply {
            setPadding(pad, pad, pad, pad)
            setBackgroundColor(if (night) 0xFF2B2A28.toInt() else 0xFFF7F3EF.toInt())
            addView(view)
        }
        holder.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        holder.layout(0, 0, holder.measuredWidth, holder.measuredHeight)
        val bitmap = Bitmap.createBitmap(holder.measuredWidth, holder.measuredHeight, Bitmap.Config.ARGB_8888)
        holder.draw(Canvas(bitmap))
        file.outputStream().use { stream -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream) }
    }
}
