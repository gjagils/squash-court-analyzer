package com.squashanalyzer.android

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * The language of the host's own texts (notifications, toasts, share
 * pictures, backup messages): the choice in Instellingen → Taal, else Dutch
 * on a Dutch phone and English on any other.
 * Dutch is the source language and lives in `values/`, English in
 * `values-en/`. Resources alone would get two cases wrong: a German phone
 * would get the Dutch default, and a phone with the languages [nl, en] would
 * get `values-en` (Android prefers any matching qualifier over the default).
 * So the strings come from a context with exactly one locale, chosen from the
 * first language (the per-app language when the user set one, Android 13+).
 *
 * The choice in Instellingen → Taal is read here too: AppCompat applies it to
 * the Activity, but before Android 13 not to the application context the push
 * service and the notifications use, so those would keep the phone's language.
 */
object HostLocale {
    private val dutch: Locale = Locale.forLanguageTag("nl")

    /** Skip's UserDefaults.standard: the SharedPreferences file "defaults"; the same key as Core's AppLanguage.storageKey */
    private const val PREFS = "defaults"
    private const val LANGUAGE_KEY = "appLanguage"

    /** "nl" or "en" from Instellingen → Taal, null for Telefoon (or anything else) */
    fun chosenLanguage(context: Context): String? {
        val chosen = runCatching {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(LANGUAGE_KEY, null)
        }.getOrNull()
        return if (chosen == "nl" || chosen == "en") chosen else null
    }

    fun isDutch(context: Context): Boolean {
        chosenLanguage(context)?.let { return it == "nl" }
        val locales = context.resources.configuration.locales
        return !locales.isEmpty && locales[0].language == "nl"
    }

    /** A context whose resources are in the app's language (Dutch or English) */
    fun texts(context: Context): Context {
        val config = Configuration(context.resources.configuration)
        config.setLocale(if (isDutch(context)) dutch else Locale.ENGLISH)
        return context.createConfigurationContext(config)
    }
}

/** One host text in the app's language (for a single message; keep `HostLocale.texts` for several) */
fun Context.hostText(id: Int, vararg args: Any): String = HostLocale.texts(this).getString(id, *args)
