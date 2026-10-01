package com.squashanalyzer.android

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import androidx.core.content.FileProvider
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.CardSnapshot
import java.io.File

/**
 * "Deel kaart" with a picture, like iOS' `PlayerCardImage`: the player's name,
 * how many of the 31 badges, and every earned badge with its artwork and
 * count, drawn on a Canvas (Skip has no ImageRenderer). The artwork comes from
 * SquashAnalyzerUI's asset catalog, which Skip ships in the APK's assets.
 */
object CardImage {
    private const val WIDTH = 1080
    private const val PADDING = 64
    private const val PER_ROW = 4
    private const val BADGE = 190
    private const val CELL_HEIGHT = 330

    fun shareIntent(context: Context, snapshot: CardSnapshot, text: String): Intent {
        val file = File(context.cacheDir, "kaart").apply { mkdirs() }.resolve("badgekaart.png")
        file.outputStream().use { render(context, snapshot).compress(Bitmap.CompressFormat.PNG, 100, it) }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return Intent.createChooser(send, null)
    }

    /** Earned badges with how often, in catalogue order */
    private fun earned(snapshot: CardSnapshot): List<Pair<BadgeKind, Int>> {
        val active = snapshot.awards.toList().filter { it.deletedAt == null }
        return BadgeKind.allCases.toList().mapNotNull { kind ->
            val count = active.count { it.badge == kind }
            if (count > 0) kind to count else null
        }
    }

    fun render(context: Context, snapshot: CardSnapshot): Bitmap {
        val items = earned(snapshot)
        val rows = (items.size + PER_ROW - 1) / PER_ROW
        val height = PADDING * 2 + 220 + maxOf(rows, 1) * CELL_HEIGHT
        val bitmap = Bitmap.createBitmap(WIDTH, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.rgb(18, 15, 12))

        val gold = Color.rgb(232, 184, 87)
        val text = Paint(Paint.ANTI_ALIAS_FLAG)
        text.color = gold
        text.textSize = 34f
        text.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        text.letterSpacing = 0.15f
        canvas.drawText("BADGEKAART", PADDING.toFloat(), PADDING + 30f, text)
        text.letterSpacing = 0f
        text.typeface = Typeface.DEFAULT
        text.color = Color.rgb(128, 124, 117)
        text.textSize = 30f
        val brand = "Squash Analyzer"
        canvas.drawText(brand, WIDTH - PADDING - text.measureText(brand), PADDING + 30f, text)

        text.color = Color.rgb(242, 239, 234)
        text.textSize = 76f
        text.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText(snapshot.name, PADDING.toFloat(), PADDING + 130f, text)
        text.typeface = Typeface.DEFAULT
        text.textSize = 34f
        text.color = Color.rgb(179, 175, 168)
        canvas.drawText("${items.size} van ${BadgeKind.allCases.count} badges", PADDING.toFloat(), PADDING + 185f, text)

        val top = PADDING + 240
        if (items.isEmpty()) {
            canvas.drawText("Nog geen badges verdiend", PADDING.toFloat(), top + 60f, text)
        }
        val cell = (WIDTH - PADDING * 2) / PER_ROW
        items.forEachIndexed { index, (kind, count) ->
            val x = PADDING + (index % PER_ROW) * cell
            val y = top + (index / PER_ROW) * CELL_HEIGHT
            val left = x + (cell - BADGE) / 2
            artwork(context, kind)?.let { canvas.drawBitmap(it, null, Rect(left, y, left + BADGE, y + BADGE), null) }
            val centre = (x + cell / 2).toFloat()
            val small = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textAlign = Paint.Align.CENTER; color = gold; textSize = 36f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            canvas.drawText("${count}×", centre, y + BADGE + 46f, small)
            small.typeface = Typeface.DEFAULT
            small.color = Color.rgb(179, 175, 168)
            small.textSize = 26f
            // Up to two lines, as iOS' card picture
            wrapTwo(kind.title, small, cell - 12f).forEachIndexed { line, part ->
                canvas.drawText(part, centre, y + BADGE + 84f + line * 30f, small)
            }
        }
        return bitmap
    }

    /** The title on one line, or split over two at a word; a second line too long is shortened */
    private fun wrapTwo(title: String, paint: Paint, width: Float): List<String> {
        if (paint.measureText(title) <= width) return listOf(title)
        val words = title.split(" ")
        var first = ""
        var index = 0
        while (index < words.size) {
            val next = if (first.isEmpty()) words[index] else "$first ${words[index]}"
            if (paint.measureText(next) > width && first.isNotEmpty()) break
            first = next
            index++
        }
        val rest = words.drop(index).joinToString(" ")
        return if (rest.isEmpty()) listOf(shorten(first, paint, width)) else listOf(shorten(first, paint, width), shorten(rest, paint, width))
    }

    private fun shorten(title: String, paint: Paint, width: Float): String {
        if (paint.measureText(title) <= width) return title
        var cut = title
        while (cut.isNotEmpty() && paint.measureText("$cut…") > width) cut = cut.dropLast(1)
        return "$cut…"
    }

    private fun artwork(context: Context, kind: BadgeKind): Bitmap? = runCatching {
        val name = kind.imageName
        context.assets.open("squash/analyzer/ui/Resources/Module.xcassets/$name.imageset/$name.png").use(BitmapFactory::decodeStream)
    }.getOrNull()
}
