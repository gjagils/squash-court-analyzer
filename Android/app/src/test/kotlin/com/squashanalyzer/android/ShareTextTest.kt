package com.squashanalyzer.android

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class ShareTextTest {
    @Test fun opensTheShareSheetWithPlainText() {
        val chooser = shareTextIntent("Badgekaart van Hugo: https://squashanalyzer.com/kaart/#abc")
        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        @Suppress("DEPRECATION")
        val send = chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND, send.action)
        assertEquals("text/plain", send.type)
        assertEquals("Badgekaart van Hugo: https://squashanalyzer.com/kaart/#abc", send.getStringExtra(Intent.EXTRA_TEXT))
    }
}
