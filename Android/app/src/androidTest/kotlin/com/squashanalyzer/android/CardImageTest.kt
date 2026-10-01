package com.squashanalyzer.android

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.AwardValue
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.CardSnapshot

/** "Deel kaart" on Android: a card picture with the badge artwork, shared with the link */
@RunWith(AndroidJUnit4::class)
class CardImageTest {
    @Test fun theCardIsDrawnWithItsBadgesAndSharedAsAPicture() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val card = UUID()
        val award = AwardValue(cardId = card, badge = BadgeKind.fiveInARow, matchId = UUID(), earnedAt = Date(),
                               opponentName = "Thé", awardedBy = "test", deletedAt = null)
        val snapshot = CardSnapshot(cardId = card, name = "Gerard", awards = SwiftArray(listOf(award)))

        val bitmap = CardImage.render(context, snapshot)
        assertEquals(1080, bitmap.width)
        assertTrue(bitmap.height > 400)

        val chooser = CardImage.shareIntent(context, snapshot, "Badgekaart van Gerard: https://squashanalyzer.com/kaart/#x")
        val send = chooser.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)!!
        assertEquals("image/png", send.type)
        assertNotNull(send.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java))
    }
}
