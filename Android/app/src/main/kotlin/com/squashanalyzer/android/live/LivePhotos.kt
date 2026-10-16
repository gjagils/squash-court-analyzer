package com.squashanalyzer.android.live

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import com.squashanalyzer.android.HttpRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import skip.foundation.URL
import skip.lib.Dictionary
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * The players' thumbnails of a followed match, for the avatars in the live
 * score notification. The FCM pushes carry no photos: they are downloaded once
 * per match from the live server (`GET /api/live/:id` says which exist, then
 * `GET /api/live/:id/photo/1|2`), cropped round, and kept in the app's files
 * (`live-photos/<id>-1.png`) until the follow ends. Without a photo the
 * avatar is the first letter of the name.
 */
object LivePhotos {
    /** Side of a cropped photo in pixels: a 40dp avatar on a xxhdpi screen is about 120 */
    const val SIZE = 112

    private const val DIR = "live-photos"
    private const val TIMEOUT_MILLIS = 10_000

    /** Matches whose photos are being fetched right now, so two pushes do not both download */
    private val busy = ConcurrentHashMap.newKeySet<String>()

    private fun dir(context: Context) = File(context.filesDir, DIR)

    private fun file(context: Context, match: FollowedMatch, player: Int) = File(dir(context), "${match.id}-$player.png")

    /** Written once the server was asked, photos or not, so every rally does not ask again */
    private fun marker(context: Context, match: FollowedMatch) = File(dir(context), "${match.id}.checked")

    /** The round photo of a player, or null */
    fun load(context: Context, match: FollowedMatch, player: Int): Bitmap? {
        val file = file(context, match, player)
        if (!file.exists()) return null
        return try {
            BitmapFactory.decodeFile(file.path)
        } catch (e: Exception) {
            null
        }
    }

    fun needsFetch(context: Context, match: FollowedMatch): Boolean = !marker(context, match).exists()

    /**
     * Downloads the players' photos when that has not been done for this match.
     * True when at least one photo arrived (the notification can be shown again).
     * No network: false without the marker, so the next push tries again.
     */
    suspend fun fetch(context: Context, match: FollowedMatch): Boolean {
        if (!needsFetch(context, match) || !busy.add(match.id)) return false
        try {
            val base = match.server + "/api/live/" + match.id
            val state = HttpRequest.send("GET", URL(string = base), headers(), null, TIMEOUT_MILLIS)
            val flags = if (state.status == 200) photoFlags(String(state.body.platformValue)) else listOf(false, false)
            var any = false
            for (player in 1..2) {
                if (!flags[player - 1]) continue
                val photo = HttpRequest.send("GET", URL(string = "$base/photo/$player"), headers(), null, TIMEOUT_MILLIS)
                if (photo.status != 200) continue
                val saved = withContext(Dispatchers.IO) {
                    val bytes = photo.body.platformValue
                    val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return@withContext false
                    val round = round(decoded, SIZE)
                    dir(context).mkdirs()
                    file(context, match, player).outputStream().use { out ->
                        round.compress(Bitmap.CompressFormat.PNG, 100, out)
                    }
                    true
                }
                any = any || saved
            }
            withContext(Dispatchers.IO) {
                dir(context).mkdirs()
                marker(context, match).writeText("")
            }
            return any
        } catch (e: Exception) {
            return false
        } finally {
            busy.remove(match.id)
        }
    }

    private fun headers(): Dictionary<String, String> {
        val headers = Dictionary<String, String>()
        headers["User-Agent"] = "SquashAnalyzer-Android"
        return headers
    }

    /** `photos: [true, false]` of the server's state; both false when it is missing */
    fun photoFlags(json: String): List<Boolean> = try {
        val photos = JSONObject(json).optJSONArray("photos")
        listOf(photos?.optBoolean(0) ?: false, photos?.optBoolean(1) ?: false)
    } catch (e: Exception) {
        listOf(false, false)
    }

    /** The follow ended: the photos go with it */
    fun delete(context: Context, match: FollowedMatch) {
        for (player in 1..2) file(context, match, player).delete()
        marker(context, match).delete()
    }

    /** Photos of matches no longer followed (an app killed before it could clean up) */
    fun deleteAllExcept(context: Context, keep: Collection<FollowedMatch>) {
        val ids = keep.map { match -> match.id }.toSet()
        dir(context).listFiles()?.forEach { file ->
            val id = file.name.substringBefore('-').substringBefore('.')
            if (id !in ids) file.delete()
        }
    }

    /** A centre square of `source`, scaled to `size` and cut round */
    fun round(source: Bitmap, size: Int): Bitmap {
        val side = minOf(source.width, source.height)
        val left = (source.width - side) / 2
        val top = (source.height - side) / 2
        val square = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(square).drawBitmap(source, Rect(left, top, left + side, top + side), Rect(0, 0, size, size), Paint(Paint.FILTER_BITMAP_FLAG))
        val result = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = BitmapShader(square, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
        Canvas(result).drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return result
    }

    // The Live Update (Android 16+) has no custom views: its large icon shows
    // both avatars, drawn here. They stand on a dark disc, as on the website's
    // dark viewer page, so they read on a light and a dark shade alike.

    private const val DISC = 0xFF1C130A.toInt()
    private val RING = intArrayOf(0xFFF28C26.toInt(), 0xFF59738C.toInt())
    private val LETTER = intArrayOf(0xFFF28C26.toInt(), 0xFF8094AD.toInt())

    /** One avatar of `size`: the photo or the initial, with a ring in the player's colour */
    fun avatar(photo: Bitmap?, initial: String, player: Int, size: Int): Bitmap {
        val result = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val ring = size * 0.06f
        val centre = size / 2f
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = DISC }
        canvas.drawCircle(centre, centre, centre, fill)
        if (photo != null) {
            val inner = (size - 2 * ring).toInt()
            canvas.drawBitmap(round(photo, inner), ring, ring, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        } else {
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = LETTER[player - 1]
                textSize = size * 0.46f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val bounds = Rect()
            text.getTextBounds(initial, 0, initial.length, bounds)
            canvas.drawText(initial, centre, centre - bounds.exactCenterY(), text)
        }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = ring
            color = RING[player - 1]
        }
        canvas.drawCircle(centre, centre, centre - ring / 2, stroke)
        return result
    }

    /**
     * Both avatars in one square: player 1 top left in front, player 2 bottom
     * right behind it, with a transparent gap between them.
     */
    fun pair(first: Bitmap, second: Bitmap, size: Int): Bitmap {
        val result = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val avatar = size * 0.66f
        val offset = size - avatar
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(second, null, RectF(offset, offset, size.toFloat(), size.toFloat()), paint)
        val clear = Paint(Paint.ANTI_ALIAS_FLAG).apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR) }
        canvas.drawCircle(avatar / 2, avatar / 2, avatar / 2 + size * 0.03f, clear)
        canvas.drawBitmap(first, null, RectF(0f, 0f, avatar, avatar), paint)
        return result
    }
}
