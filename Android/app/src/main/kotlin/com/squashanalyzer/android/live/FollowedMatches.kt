package com.squashanalyzer.android.live

import android.content.Context
import squash.analyzer.core.LiveFollowLink
import squash.analyzer.core.LiveFollowTarget

/**
 * A followed match, as plain Kotlin (Core's `LiveFollowTarget`); `kind`
 * "team" for a team match (Competitie), null for a single match.
 */
data class FollowedMatch(val id: String, val server: String, val kind: String? = null) {
    val isTeam: Boolean get() = kind == TEAM

    fun toTarget(): LiveFollowTarget = LiveFollowTarget(id = id, server = server, kind = kind)

    /** "<server>/api/live/<id>" or "<server>/api/team/<id>" */
    val apiUrl: String get() = server + (if (isTeam) "/api/team/" else "/api/live/") + id

    companion object {
        const val TEAM = "team"

        fun from(target: LiveFollowTarget) = FollowedMatch(target.id, target.server, if (target.isTeam) TEAM else null)

        /** Only matches on our own live servers (the same check as the links); any other kind is a single match */
        fun validated(id: String?, server: String?, kind: String? = null): FollowedMatch? {
            if (id == null || server == null || !server.startsWith("https://")) return null
            if (!LiveFollowLink.isValidId(id)) return null
            val host = LiveFollowLink.host(of = server)
            if (!LiveFollowLink.isAllowedHost(host) || server != "https://$host") return null
            return FollowedMatch(id, server, if (kind == TEAM) TEAM else null)
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

    fun all(): List<FollowedMatch> = prefs.getStringSet(KEY, emptySet()).orEmpty().mapNotNull { entry -> parse(entry) }

    fun contains(match: FollowedMatch): Boolean = all().contains(match)

    fun add(match: FollowedMatch) = update { set -> set.add(entry(match)) }

    fun remove(match: FollowedMatch) = update { set -> set.remove(entry(match)) }

    /** The last token sent to the servers, so "Stoppen" can delete it after an app restart */
    var token: String?
        get() = prefs.getString(TOKEN_KEY, null)
        set(value) = prefs.edit().putString(TOKEN_KEY, value).apply()

    private fun update(change: (MutableSet<String>) -> Unit) {
        val set = prefs.getStringSet(KEY, emptySet()).orEmpty().toMutableSet()
        change(set)
        prefs.edit().putStringSet(KEY, set).apply()
    }

    companion object {
        private const val KEY = "following"
        private const val TOKEN_KEY = "token"

        /**
         * "<id> <server>" for a single match (as stored before team matches
         * existed), "<id> <server> team" for a team match
         */
        fun entry(match: FollowedMatch) = match.id + " " + match.server + (if (match.isTeam) " " + FollowedMatch.TEAM else "")

        fun parse(entry: String): FollowedMatch? {
            val parts = entry.split(" ")
            if (parts.size != 2 && parts.size != 3) return null
            if (parts.size == 3 && parts[2] != FollowedMatch.TEAM) return null
            return FollowedMatch.validated(parts[0], parts[1], parts.getOrNull(2))
        }
    }
}
