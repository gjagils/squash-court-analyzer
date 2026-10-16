package com.squashanalyzer.android.live

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.launch

/** "Stoppen" on the live score notification, or the notification swiped away: stop following */
class LiveFollowActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_STOP = "com.squashanalyzer.android.live.STOP"
        const val ACTION_DISMISSED = "com.squashanalyzer.android.live.DISMISSED"
        const val EXTRA_ID = "id"
        const val EXTRA_SERVER = "server"
        const val EXTRA_KIND = "kind"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_STOP && intent.action != ACTION_DISMISSED) return
        val match = FollowedMatch.validated(intent.getStringExtra(EXTRA_ID), intent.getStringExtra(EXTRA_SERVER), intent.getStringExtra(EXTRA_KIND)) ?: return
        // A final score that is swiped away was already forgotten
        if (!FollowedMatches(context).contains(match)) {
            LiveScoreNotifier(context).cancel(match)
            return
        }
        val pending = goAsync()
        val appContext = context.applicationContext
        FcmLiveFollowPresenter.scope.launch {
            try {
                FcmLiveFollowPresenter.stopFollowing(appContext, match)
            } finally {
                pending.finish()
            }
        }
    }
}
