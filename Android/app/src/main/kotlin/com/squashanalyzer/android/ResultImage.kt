package com.squashanalyzer.android

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Rect
import android.graphics.Path
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import androidx.core.content.FileProvider
import squash.analyzer.core.Player
import squash.analyzer.core.ResultCard
import java.io.File

/**
 * "Deel als plaatje": the result of a game or match as a PNG, laid out like
 * the result card at the end of a game (Core's `ResultCard`, the same picture
 * as iOS' `ResultCardImage`). Drawn on a Canvas because Skip has no
 * ImageRenderer, like `CardImage`.
 */
object ResultImage {
    private const val WIDTH = 1080
    private const val PADDING = 72f

    private val background = Color.rgb(31, 27, 23)
    private val chipBackground = Color.rgb(43, 42, 43)
    private val textPrimary = Color.rgb(242, 237, 230)
    private val textSecondary = Color.rgb(179, 173, 166)
    private val muted = Color.rgb(143, 138, 133)
    private val orange = Color.rgb(242, 140, 38)
    private val blue = Color.rgb(128, 148, 173)
    private val gold = Color.rgb(230, 184, 89)

    fun shareIntent(context: Context, card: ResultCard): Intent {
        val file = File(context.cacheDir, "kaart").apply { mkdirs() }.resolve("uitslag.png")
        file.outputStream().use { render(card).compress(Bitmap.CompressFormat.PNG, 100, it) }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return Intent.createChooser(send, null)
    }

    private fun color(player: Player) = if (player == Player.player1) orange else blue

    private fun paint(size: Float, color: Int, bold: Boolean = false, align: Paint.Align = Paint.Align.CENTER) =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = size
            this.color = color
            textAlign = align
            typeface = Typeface.create(Typeface.SANS_SERIF, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }

    fun render(card: ResultCard): Bitmap {
        val chips = card.chips.toList()
        val rows = card.rows.toList()
        // A team match picture has a line per partij under the score and is taller for it
        val rowHeight = 150f
        val height = if (rows.isEmpty()) 1180 else (1000f + rows.size * rowHeight + 150f).toInt()
        val bitmap = Bitmap.createBitmap(WIDTH, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(background)
        val centre = WIDTH / 2f

        // Title, wide letter spacing as on the card
        val title = paint(64f, textPrimary, bold = true).apply { letterSpacing = 0.22f }
        shrinkToFit(title, card.title, WIDTH - PADDING * 2)
        canvas.drawText(card.title, centre, 150f, title)

        // Both players: a ring with a person and the name under it
        val sides = listOf(Player.player1, Player.player2)
        sides.forEachIndexed { index, player ->
            val x = WIDTH * (if (index == 0) 0.27f else 0.73f)
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; strokeWidth = 7f; color = color(player); alpha = 180
            }
            // The player's photo (Spelers) in the circle, else a person
            val photo = card.photo(for_ = player)?.platformValue?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
            if (photo != null) {
                drawCirclePhoto(canvas, photo, x, 300f, 80f)
            } else {
                val person = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = color(player); alpha = 180 }
                canvas.drawCircle(x, 282f, 22f, person)
                canvas.drawRoundRect(RectF(x - 40f, 312f, x + 40f, 346f), 20f, 20f, person)
            }
            canvas.drawCircle(x, 300f, 84f, ring)
            val name = paint(42f, if (player == Player.player1) textSecondary else color(player), bold = true)
            val lines = wrapTwo(card.name(for_ = player), name, WIDTH * 0.42f)
            lines.forEachIndexed { line, text -> canvas.drawText(text, x, 450f + line * 50f, name) }
        }

        // The big score: the winner in their colour, the other side muted
        fun scoreColor(player: Player): Int {
            val winner = card.winner ?: return textPrimary
            return if (winner == player) color(player) else muted
        }
        val score = paint(230f, textPrimary, bold = true)
        score.color = scoreColor(Player.player1)
        canvas.drawText("${card.player1Score}", WIDTH * 0.27f, 760f, score)
        score.color = scoreColor(Player.player2)
        canvas.drawText("${card.player2Score}", WIDTH * 0.73f, 760f, score)
        canvas.drawRoundRect(RectF(centre - 34f, 676f, centre + 34f, 692f), 8f, 8f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = muted })

        card.winnerText?.let { text ->
            val winner = paint(48f, card.winner?.let(::color) ?: textSecondary)
            shrinkToFit(winner, text, WIDTH - PADDING * 2)
            canvas.drawText(text, centre, 880f, winner)
        }

        // A chip per game, coloured by who won it
        if (chips.isNotEmpty()) {
            val gap = 20f
            val chipWidth = minOf(170f, (WIDTH - PADDING * 2 - gap * (chips.size - 1)) / chips.size)
            var x = centre - (chipWidth * chips.size + gap * (chips.size - 1)) / 2f
            for (chip in chips) {
                val wonByOne = chip.winner == Player.player1
                val tint = chip.winner?.let(::color) ?: textSecondary
                val rect = RectF(x, 950f, x + chipWidth, 1060f)
                val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (wonByOne) Color.argb(41, 242, 140, 38) else chipBackground }
                canvas.drawRoundRect(rect, 24f, 24f, fill)
                val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE; strokeWidth = 3f
                    color = if (wonByOne) Color.argb(128, 242, 140, 38) else Color.argb(20, 255, 255, 255)
                }
                canvas.drawRoundRect(rect, 24f, 24f, stroke)
                val label = paint(28f, tint).apply { alpha = 200; letterSpacing = 0.1f }
                canvas.drawText(chip.label, rect.centerX(), 992f, label)
                val value = paint(40f, tint, bold = true)
                shrinkToFit(value, chip.score, chipWidth - 16f)
                canvas.drawText(chip.score, rect.centerX(), 1040f, value)
                x += chipWidth + gap
            }
        }

        // Team match: a quiet line per partij (who played whom, the games, the stand),
        // only a hairline between them
        if (rows.isNotEmpty()) {
            val header = paint(26f, muted, bold = true, align = Paint.Align.LEFT).apply { letterSpacing = 0.25f }
            canvas.drawText("PARTIJEN", PADDING, 985f, header)
            val hairline = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(20, 255, 255, 255); strokeWidth = 2f }
            val nameX = PADDING + 78f
            val scoreWidth = 150f
            val room = WIDTH - PADDING - scoreWidth - nameX
            var y = 1000f
            for (row in rows) {
                canvas.drawLine(PADDING, y, WIDTH - PADDING, y, hairline)
                val baseline = y + 66f
                canvas.drawText(row.label, PADDING, baseline, paint(26f, muted, align = Paint.Align.LEFT))
                // The winner of the partij in their colour, the other side muted; open: both calm
                fun tone(player: Player): Int {
                    val winner = row.winner ?: return textSecondary
                    return if (winner == player) color(player) else muted
                }
                val home = paint(42f, tone(Player.player1), bold = row.winner == Player.player1, align = Paint.Align.LEFT)
                val dash = paint(42f, muted, align = Paint.Align.LEFT)
                val away = paint(42f, tone(Player.player2), bold = row.winner == Player.player2, align = Paint.Align.LEFT)
                val between = "  –  "
                val total = home.measureText(row.home) + dash.measureText(between) + away.measureText(row.away)
                if (total > room) {
                    val factor = room / total
                    home.textSize *= factor; dash.textSize *= factor; away.textSize *= factor
                }
                canvas.drawText(row.home, nameX, baseline, home)
                var x = nameX + home.measureText(row.home)
                canvas.drawText(between, x, baseline, dash)
                x += dash.measureText(between)
                canvas.drawText(row.away, x, baseline, away)
                val scorePaint = paint(46f, row.winner?.let(::color) ?: textPrimary, bold = true, align = Paint.Align.RIGHT)
                canvas.drawText(row.score, WIDTH - PADDING, baseline, scorePaint)
                val games = paint(32f, muted, align = Paint.Align.LEFT)
                shrinkToFit(games, row.games, WIDTH - PADDING - nameX)
                canvas.drawText(row.games, nameX, baseline + 48f, games)
                y += rowHeight
            }
        }

        // Footer
        val footer = paint(30f, muted, bold = true).apply { letterSpacing = 0.15f }
        val footerWidth = footer.measureText(card.footer)
        canvas.drawCircle(centre - footerWidth / 2f - 24f, height - 51f, 9f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = gold })
        canvas.drawText(card.footer, centre + 8f, height - 40f, footer)
        return bitmap
    }

    /** The photo cropped to a circle (centre square, scaled to fill) */
    private fun drawCirclePhoto(canvas: Canvas, photo: Bitmap, cx: Float, cy: Float, radius: Float) {
        val side = minOf(photo.width, photo.height)
        val source = Rect((photo.width - side) / 2, (photo.height - side) / 2, (photo.width + side) / 2, (photo.height + side) / 2)
        val target = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val save = canvas.save()
        canvas.clipPath(Path().apply { addCircle(cx, cy, radius, Path.Direction.CW) })
        canvas.drawBitmap(photo, source, target, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        canvas.restoreToCount(save)
    }

    private fun shrinkToFit(paint: Paint, text: String, width: Float) {
        while (paint.textSize > 12f && paint.measureText(text) > width) paint.textSize -= 2f
    }

    /** A name on one line, or over two at a word ("Niels van / Sevenhoven") */
    private fun wrapTwo(text: String, paint: Paint, width: Float): List<String> {
        if (paint.measureText(text) <= width) return listOf(text)
        val words = text.split(" ")
        var first = ""
        var index = 0
        while (index < words.size) {
            val next = if (first.isEmpty()) words[index] else "$first ${words[index]}"
            if (paint.measureText(next) > width && first.isNotEmpty()) break
            first = next
            index++
        }
        val rest = words.drop(index).joinToString(" ")
        if (rest.isEmpty()) {
            shrinkToFit(paint, first, width)
            return listOf(first)
        }
        return listOf(first, rest)
    }
}
