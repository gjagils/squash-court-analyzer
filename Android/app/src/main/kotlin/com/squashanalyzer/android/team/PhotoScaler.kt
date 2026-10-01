package com.squashanalyzer.android.team

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Rect
import java.io.ByteArrayOutputStream

/** Player photos as small square JPEGs, like iOS' `PlayerPhoto`: keeps Room and backups compact */
object PhotoScaler {
    const val MAX_SIDE = 512

    /** Center-cropped square, at most 512px, JPEG; null when it is not an image */
    fun squareJpeg(bytes: ByteArray): ByteArray? {
        val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val side = minOf(image.width, image.height)
        if (side <= 0) return null
        val target = minOf(side, MAX_SIDE)
        val square = Bitmap.createBitmap(target, target, Bitmap.Config.ARGB_8888)
        val left = (image.width - side) / 2
        val top = (image.height - side) / 2
        Canvas(square).drawBitmap(image, Rect(left, top, left + side, top + side), Rect(0, 0, target, target), null)
        val out = ByteArrayOutputStream()
        square.compress(Bitmap.CompressFormat.JPEG, 82, out)
        return out.toByteArray()
    }
}
