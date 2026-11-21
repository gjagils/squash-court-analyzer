package com.squashanalyzer.android.live

import android.content.Context
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.squashanalyzer.android.BuildConfig
import kotlinx.coroutines.launch
import squash.analyzer.core.LiveFollow
import squash.analyzer.core.TeamAlertFollow
import squash.analyzer.core.TeamMatchSupport

/**
 * The live server's pushes: `data = { kind: "live", id, server, event:
 * "update" | "end", snapshot: "<JSON>" }` after every rally of a followed
 * match, or `{ kind: "team", ..., team: "<JSON>" }` after every change of a
 * followed team match; with `alertTitle` / `alertBody` when a game (partij) is
 * won and at the result. Shows the new state; "end" shows the final score (or
 * removes the notification when there is none) and forgets the match.
 * `{ kind: "alert", id, server, slot, alertTitle, alertBody }` (4.0, T6) is a
 * team match this phone takes part in: only the alert, no ongoing notification.
 *
 * "Teamstand vanzelf op je vergrendelscherm" (21 November 2026): a team push
 * with `event: "start"` is the live server putting the team match of the
 * account's team on the lock screen as it starts ("Je team is begonnen"). The
 * phone follows it from then on, as after "Volgen": the server registered this
 * FCM token as a follower already.
 */
class LiveFollowMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (BuildConfig.DEBUG) android.util.Log.d("LiveFollow", "Push ${message.data["event"]} voor ${message.data["id"]}")
        handle(applicationContext, message.data)
    }

    override fun onNewToken(token: String) {
        if (BuildConfig.DEBUG) android.util.Log.d("LiveFollow", "FCM token: $token")
        FcmLiveFollowPresenter.scope.launch { FcmLiveFollowPresenter.tokenChanged(applicationContext, token) }
        // The team matches this phone takes part in (4.0, T6) get the new token too
        FcmLiveFollowPresenter.scope.launch { TeamAlertFollow.shared.tokenChanged() }
    }

    companion object {
        /** Also the entry point of the debug-only sample broadcast */
        fun handle(context: Context, data: Map<String, String>) {
            val kind = data["kind"]
            // 4.0, T6: a team match this phone takes part in (no ongoing notification)
            if (kind == "alert") {
                AndroidTeamAlertPlatform.show(context, data)
                return
            }
            if (kind != "live" && kind != FollowedMatch.TEAM) return
            val match = FollowedMatch.validated(data["id"], data["server"], kind) ?: return
            val followed = FollowedMatches(context)
            // The server starts the team match of the account's team on this phone
            val started = data["event"] == "start"
            if (started && !startTeam(context, match, followed)) return
            // A push for a match this phone stopped following (the server may not know yet)
            if (!followed.contains(match)) return
            val notifier = LiveScoreNotifier(context)
            val ended = data["event"] == "end"
            // "Melding bij elke game": a game (partij) won or the result, as a separate heads-up
            // "Je team is begonnen" comes with a start whatever that setting says
            val alert = LiveAlerts.from(data, started || LiveAlerts.isOn(context))
            if (match.isTeam) {
                val stand = TeamScore.parse(data["team"] ?: return, context) ?: return
                // Ended before all four partijen were decided (stopped, or the alarm): nothing to show any more
                if (ended && !TeamScoreCard(stand, context).isFinished) notifier.cancel(match)
                else notifier.showTeam(match, stand, quiet = alert != null)
                if (started) notifier.fetchTeamPhotos(match, TeamScoreCard(stand, context).slots)
            } else {
                val score = LiveScoreJson.parse(data["snapshot"] ?: return) ?: return
                // Ended without a result (the scorer stopped sharing): nothing to show any more
                if (ended && score.status != "finished") notifier.cancel(match)
                else notifier.show(match, score, quiet = alert != null)
            }
            if (alert != null) notifier.alert(match, alert)
            if (ended) {
                followed.remove(match)
                // The final score keeps its avatars: a notification holds its own copy of the bitmaps
                LivePhotos.delete(context, match)
                FcmLiveFollowPresenter.scope.launch { LiveFollow.shared.forget(match.toTarget()) }
            }
        }

        /**
         * The server starts following a team match for this phone: only a team
         * match, only while "Meldingen van je teamwedstrijd" is on and the
         * phone shows notifications. Otherwise the server is told to forget
         * the token again and nothing shows. True when the match is followed now.
         */
        private fun startTeam(context: Context, match: FollowedMatch, followed: FollowedMatches): Boolean {
            if (followed.contains(match)) return true
            val appContext = context.applicationContext
            if (!match.isTeam || !TeamAlertFollow.shared.isEnabled || !LiveScoreNotifier(appContext).canNotify()) {
                FcmLiveFollowPresenter.scope.launch {
                    // The DELETE needs the token the server used
                    FirebaseConfig.token()?.let { token -> followed.token = token }
                    FcmLiveFollowPresenter.stopFollowing(appContext, match)
                }
                return false
            }
            followed.add(match)
            FcmLiveFollowPresenter.scope.launch {
                // "Stoppen" needs the token after a restart; the photos come once, as after Volgen
                FirebaseConfig.token()?.let { token -> followed.token = token }
                LiveFollow.shared.restore(match.toTarget(), quiet = true)
                // With the app open: the home screen looks for the team match at once
                TeamMatchSupport.noteChange()
            }
            return true
        }
    }
}
