package com.squashanalyzer.android.live

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import squash.analyzer.core.LiveFollow

/**
 * "Melding bij elke game": the live server adds `alertTitle` / `alertBody` to
 * a push when a game is won (team match: a partij is decided) and at the
 * result, only for followers registered with alerts on. The phone shows it
 * like a goal in a football app: a separate heads-up notification on its own
 * channel, next to the ongoing score, one per match (the next alert replaces it).
 */
object LiveAlerts {
    data class Alert(val title: String, val body: String)

    /**
     * The alert of this push, or null: none in the push, or the setting is
     * off here (the server may not know yet, when re-registering failed).
     */
    fun from(data: Map<String, String>, enabled: Boolean): Alert? {
        if (!enabled) return null
        val title = data["alertTitle"]?.trim().orEmpty()
        if (title.isEmpty()) return null
        return Alert(title.take(MAX_LENGTH), data["alertBody"]?.trim().orEmpty().take(MAX_LENGTH))
    }

    private const val MAX_LENGTH = 200

    // The setting itself lives in the shared settings screen (SwiftUI,
    // @AppStorage(LiveFollow.alertsKey)). Skip's UserDefaults.standard is the
    // SharedPreferences file "defaults"; a Bool is stored with putBoolean.

    private const val PREFS = "defaults"

    private fun prefs(context: Context): SharedPreferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** The stored setting, on by default */
    fun isOn(context: Context): Boolean = read(prefs(context))

    private fun read(prefs: SharedPreferences): Boolean {
        val value = prefs.all[LiveFollow.alertsKey] ?: return true
        return when (value) {
            is Boolean -> value
            is Number -> value.toDouble() != 0.0
            is String -> value.lowercase() in listOf("true", "yes", "1")
            else -> true
        }
    }

    /** Kept here: SharedPreferences holds its listeners weakly */
    private var listener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    /**
     * At app start: Core sends the stored setting with every registration,
     * and a change in the settings reaches the matches followed on this phone
     * (also those followed before a restart, which Core no longer knows).
     */
    fun start(context: Context) {
        val appContext = context.applicationContext
        val prefs = prefs(appContext)
        LiveFollow.shared.alerts = read(prefs)
        val watch = SharedPreferences.OnSharedPreferenceChangeListener { changed, key ->
            if (key != LiveFollow.alertsKey) return@OnSharedPreferenceChangeListener
            val on = read(changed)
            if (on == LiveFollow.shared.alerts) return@OnSharedPreferenceChangeListener
            FcmLiveFollowPresenter.scope.launch { changed(appContext, on) }
        }
        listener = watch
        prefs.registerOnSharedPreferenceChangeListener(watch)
    }

    private suspend fun changed(context: Context, on: Boolean) {
        LiveFollow.shared.alerts = on
        val followed = FollowedMatches(context)
        val token = followed.token ?: return
        for (match in followed.all()) {
            // Best effort: the server keeps the setting per registration
            try {
                LiveFollow.shared.register(token, for_ = match.toTarget())
            } catch (e: Exception) {
                if (e is CancellationException) throw e
            }
        }
    }
}
