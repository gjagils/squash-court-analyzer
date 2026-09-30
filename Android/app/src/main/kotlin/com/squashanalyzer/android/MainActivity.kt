package com.squashanalyzer.android

import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.room.withTransaction
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import skip.foundation.ProcessInfo
import skip.ui.ColorScheme
import skip.ui.ComposeContext
import skip.ui.PresentationRoot
import skip.ui.UIApplication
import squash.analyzer.core.CardInbox
import squash.analyzer.ui.AndroidHomeView
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.RoomPlayerStore
import com.squashanalyzer.android.data.MatchStore
import com.squashanalyzer.android.data.RoomCoachMatchStore
import com.squashanalyzer.android.data.RefereeMatchStore
import com.squashanalyzer.android.data.RoomRefereeMatchStore
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.RoomMatchHistoryStore

/** Only the Android lifecycle lives here; the screen is shared SwiftUI. */
class SquashApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ProcessInfo.launch(applicationContext)
    }
}

class MainActivity : AppCompatActivity() {
    /** Card links opened from WhatsApp, the browser, … wait here for the import screen */
    private val cardInbox = CardInbox()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        UIApplication.launch(this)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
        )
        val playerStore = RoomPlayerStore(AppDatabase.get(this).playerDao())
        val coachMatchStore = MatchStore(AppDatabase.get(this).matchDao())
        val refereeMatchDataStore = RefereeMatchStore(AppDatabase.get(this).refereeMatchDao())
        val db = AppDatabase.get(this)
        val badgeAwardStore = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(),
            coachMatchStore, refereeMatchDataStore, badgeInstallId(), transaction = { block -> db.withTransaction { block() } })
        // Not again after a rotation: the link was already taken in (or dismissed)
        if (savedInstanceState == null) receiveCardLink(intent)
        val matchStore = RoomCoachMatchStore(coachMatchStore, badgeAwardStore)
        val refereeMatchStore = RoomRefereeMatchStore(refereeMatchDataStore, badgeAwardStore)
        val historyStore = RoomMatchHistoryStore(coachMatchStore, refereeMatchDataStore)
        setContent {
            val stateHolder = rememberSaveableStateHolder()
            stateHolder.SaveableStateProvider(true) {
                PresentationRoot(defaultColorScheme = ColorScheme.dark, context = ComposeContext()) { context ->
                    Box(modifier = context.modifier.fillMaxSize()) {
                        AndroidHomeView(playerStore = playerStore, badgeStore = badgeAwardStore, historyStore = historyStore, matchStore = matchStore, refereeMatchStore = refereeMatchStore, shareText = { startActivity(shareTextIntent(it)) }, cardInbox = cardInbox, cardImportStore = badgeAwardStore).Compose(context = context.content())
                    }
                }
                SideEffect { stateHolder.removeState(true) }
            }
        }
    }

    /** `launchMode="singleTask"`: a link opened while the app runs arrives here */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receiveCardLink(intent)
    }

    private fun receiveCardLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val link = intent.dataString ?: return
        cardInbox.receive(link)
    }

    /** Identifies this install as the awarding coach, like iOS' `BadgeAwarder.installId` */
    private fun badgeInstallId(): String {
        val prefs = getSharedPreferences("squash-analyzer", MODE_PRIVATE)
        prefs.getString("badgeInstallId", null)?.let { return it }
        val id = java.util.UUID.randomUUID().toString().uppercase()
        prefs.edit().putString("badgeInstallId", id).apply()
        return id
    }
}
