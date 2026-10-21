package com.squashanalyzer.android

import android.app.Application
import android.content.Context
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** Instellingen → Taal wins over the phone's language for the host's own texts (a Dutch phone here) */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, qualifiers = "nl")
class HostLocaleTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun choose(code: String?) {
        val prefs = context.getSharedPreferences("defaults", Context.MODE_PRIVATE).edit()
        if (code == null) prefs.remove("appLanguage") else prefs.putString("appLanguage", code)
        prefs.commit()
    }

    @After fun phoneLanguage() = choose(null)

    @Test fun telefoonFollowsThePhone() {
        choose(null)
        assertNull(HostLocale.chosenLanguage(context))
        assertTrue(HostLocale.isDutch(context))
        assertEquals("Pauze", HostLocale.texts(context).getString(R.string.live_chip_break))
    }

    @Test fun englishChosenOnADutchPhone() {
        choose("en")
        assertEquals("en", HostLocale.chosenLanguage(context))
        assertFalse(HostLocale.isDutch(context))
        assertEquals("Break", HostLocale.texts(context).getString(R.string.live_chip_break))
        assertEquals("Stop", context.hostText(R.string.notification_stop))
    }

    @Test fun dutchChosenStaysDutch() {
        choose("nl")
        assertTrue(HostLocale.isDutch(context))
        assertEquals("Stoppen", context.hostText(R.string.notification_stop))
    }

    @Test fun anUnknownValueCountsAsTelefoon() {
        choose("de")
        assertNull(HostLocale.chosenLanguage(context))
        assertTrue(HostLocale.isDutch(context))
    }
}
