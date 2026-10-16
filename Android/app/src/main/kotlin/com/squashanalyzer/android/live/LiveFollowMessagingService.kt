package com.squashanalyzer.android.live

import android.content.Context
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.squashanalyzer.android.BuildConfig
import kotlinx.coroutines.launch
import squash.analyzer.core.LiveFollow

/**
 * The live server's pushes: `data = { kind: "live", id, server, event:
 * "update" | "end", snapshot: "<JSON>" }` after every rally of a followed
 * match. Shows the new state; "end" shows the final score (or removes the
 * notification when there is none) and forgets the match.
 */
class LiveFollowMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (BuildConfig.DEBUG) android.util.Log.d("LiveFollow", "Push ${message.data["event"]} voor ${message.data["id"]}")
        handle(applicationContext, message.data)
    }

    override fun onNewToken(token: String) {
        if (BuildConfig.DEBUG) android.util.Log.d("LiveFollow", "FCM token: $token")
        FcmLiveFollowPresenter.scope.launch { FcmLiveFollowPresenter.tokenChanged(applicationContext, token) }
    }

    companion object {
        /** Also the entry point of the debug-only sample broadcast */
        fun handle(context: Context, data: Map<String, String>) {
            if (data["kind"] != "live") return
            val match = FollowedMatch.validated(data["id"], data["server"]) ?: return
            val followed = FollowedMatches(context)
            // A push for a match this phone stopped following (the server may not know yet)
            if (!followed.contains(match)) return
            val score = LiveScoreJson.parse(data["snapshot"] ?: return) ?: return
            val notifier = LiveScoreNotifier(context)
            if (data["event"] == "end") {
                // Ended without a result (the scorer stopped sharing): nothing to show any more
                if (score.status == "finished") notifier.show(match, score) else notifier.cancel(match)
                followed.remove(match)
                // The final score keeps its avatars: a notification holds its own copy of the bitmaps
                LivePhotos.delete(context, match)
                FcmLiveFollowPresenter.scope.launch { LiveFollow.shared.forget(match.toTarget()) }
            } else {
                notifier.show(match, score)
            }
        }
    }
}
