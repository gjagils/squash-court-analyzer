package com.squashanalyzer.android

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * The language of the host's own texts (notifications, toasts, share
 * pictures, backup messages): Dutch on a Dutch phone, English on any other.
 * Dutch is the source language and lives in `values/`, English in
 * `values-en/`. Resources alone would get two cases wrong: a German phone
 * would get the Dutch default, and a phone with the languages [nl, en] would
 * get `values-en` (Android prefers any matching qualifier over the default).
 * So the strings come from a context with exactly one locale, chosen from the
 * first language (the per-app language when the user set one, Android 13+).
 */
object HostLocale {
    private val dutch: Locale = Locale.forLanguageTag("nl")

    fun isDutch(context: Context): Boolean {
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
