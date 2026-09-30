package com.squashanalyzer.android

import android.content.Intent

/**
 * The Android share sheet for a plain text, such as a card link. Kept apart
 * from `MainActivity` so "Deel score" can reuse it and tests can inspect it.
 */
fun shareTextIntent(text: String): Intent {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    return Intent.createChooser(send, null)
}
