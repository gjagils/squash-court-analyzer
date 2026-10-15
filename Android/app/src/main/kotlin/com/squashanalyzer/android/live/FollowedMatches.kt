package com.squashanalyzer.android.live

import android.content.Context
import squash.analyzer.core.LiveFollowLink
import squash.analyzer.core.LiveFollowTarget

/** A followed match, as plain Kotlin (Core's `LiveFollowTarget`) */
data class FollowedMatch(val id: String, val server: String) {
    fun toTarget(): LiveFollowTarget = LiveFollowTarget(id = id, server = server)

    companion object {
        fun from(target: LiveFollowTarget) = FollowedMatch(target.id, target.server)

        /** Only matches on our own live servers (the same check as the links) */
        fun validated(id: String?, server: String?): FollowedMatch? {
            if (id == null || server == null || !server.startsWith("https://")) return null
            if (!LiveFollowLink.isValidId(id)) return null
            val host = LiveFollowLink.host(of = server)
            if (!LiveFollowLink.isAllowedHost(host) || server != "https://$host") return null
            return FollowedMatch(id, server)
        }
    }
}

/**
 * The matches this phone follows, kept across app restarts: a push arrives
 * while the app is closed, and a new FCM token must reach every match.
 * Core's `LiveFollow.following` only lives as long as the process.
 */
class FollowedMatches(context: Context) {
    private val prefs = context.getSharedPreferences("squash-live-follow", Context.MODE_PRIVATE)

    fun all(): List<FollowedMatch> = prefs.getStringSet(KEY, emptySet()).orEmpty().mapNotNull { entry ->
        val parts = entry.split(" ", limit = 2)
        if (parts.size == 2) FollowedMatch.validated(parts[0], parts[1]) else null
    }

    fun contains(match: FollowedMatch): Boolean = all().contains(match)

    fun add(match: FollowedMatch) = update { set -> set.add(entry(match)) }

    fun remove(match: FollowedMatch) = update { set -> set.remove(entry(match)) }

    /** The last token sent to the servers, so "Stoppen" can delete it after an app restart */
    var token: String?
        get() = prefs.getString(TOKEN_KEY, null)
        set(value) = prefs.edit().putString(TOKEN_KEY, value).apply()

    private fun entry(match: FollowedMatch) = match.id + " " + match.server

    private fun update(change: (MutableSet<String>) -> Unit) {
        val set = prefs.getStringSet(KEY, emptySet()).orEmpty().toMutableSet()
        change(set)
        prefs.edit().putStringSet(KEY, set).apply()
    }

    private companion object {
        const val KEY = "following"
        const val TOKEN_KEY = "token"
    }
}
