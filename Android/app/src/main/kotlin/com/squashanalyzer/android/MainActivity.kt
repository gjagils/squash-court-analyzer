package com.squashanalyzer.android

import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.room.withTransaction
import androidx.lifecycle.lifecycleScope
import squash.analyzer.core.ResultCard
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import squash.analyzer.ui.SamplePlayers
import androidx.activity.compose.setContent
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.appcompat.app.AlertDialog
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
import squash.analyzer.core.LeagueTeamFetcher
import skip.foundation.URL
import squash.analyzer.core.AICoachClient
import squash.analyzer.core.LiveShare
import squash.analyzer.core.TeamLive
import squash.analyzer.core.AppTheme
import squash.analyzer.core.GameNotes
import androidx.compose.foundation.isSystemInDarkTheme
import squash.analyzer.ui.AICoachContext
import squash.analyzer.ui.ResultImageSharing
import squash.analyzer.ui.BackupContext
import com.squashanalyzer.android.backup.ActivityBackupFiles
import com.squashanalyzer.android.backup.AutoBackup
import com.squashanalyzer.android.data.BackgroundTeamMatchStore
import com.squashanalyzer.android.data.RoomBackupStore
import com.squashanalyzer.android.aicoach.HttpAICoachTransport
import com.squashanalyzer.android.live.HttpLiveTransport
import com.squashanalyzer.android.live.FcmLiveFollowPresenter
import com.squashanalyzer.android.live.LiveAlerts
import com.squashanalyzer.android.live.FirebaseConfig
import squash.analyzer.core.LiveFollow
import squash.analyzer.core.LiveFollowError
import squash.analyzer.core.LiveFollowLink
import squash.analyzer.core.LiveFollowTarget
import kotlinx.coroutines.CompletableDeferred
import androidx.activity.result.contract.ActivityResultContracts
import com.squashanalyzer.android.aicoach.KeystoreAPIKeyStore
import com.squashanalyzer.android.league.HttpLeaguePageLoader
import com.squashanalyzer.android.team.RoomTeamImporter
import com.squashanalyzer.android.backup.ActivityPlayerFiles
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
        // Live score on the lock screen: pushes arrive also while no screen is open
        FirebaseConfig.initialize(this)
        LiveFollow.shared.transport = HttpLiveTransport()
        LiveFollow.shared.presenter = FcmLiveFollowPresenter(applicationContext)
        // "Melding bij elke game" (shared settings screen): sent with every registration
        LiveAlerts.start(applicationContext)
    }
}

class MainActivity : AppCompatActivity() {
    /** Card links opened from WhatsApp, the browser, … wait here for the import screen */
    private val cardInbox = CardInbox()
    private lateinit var autoBackup: AutoBackup

    /** Live score on the lock screen: the notification permission, asked when following (Android 13+) */
    private var notificationAnswer: CompletableDeferred<Boolean>? = null
    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        notificationAnswer?.complete(granted)
        notificationAnswer = null
    }
    private val askNotificationPermission: suspend () -> Boolean = {
        if (android.os.Build.VERSION.SDK_INT < 33) {
            false
        } else {
            val answer = CompletableDeferred<Boolean>()
            notificationAnswer?.complete(false)
            notificationAnswer = answer
            notificationPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            answer.await()
        }
    }

    @OptIn(ExperimentalMaterial3Api::class) // material3TopAppBar options (page title size)
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
        (LiveFollow.shared.presenter as? FcmLiveFollowPresenter)?.requestNotificationPermission = askNotificationPermission
        // Not again after a rotation: the link was already taken in (or dismissed)
        if (savedInstanceState == null) receiveCardLink(intent)
        val matchStore = RoomCoachMatchStore(coachMatchStore, badgeAwardStore)
        val refereeMatchStore = RoomRefereeMatchStore(refereeMatchDataStore, badgeAwardStore)
        val historyStore = RoomMatchHistoryStore(coachMatchStore, refereeMatchDataStore, matchStore, refereeMatchStore, badgeAwardStore)
        val leagueTeamFetcher = LeagueTeamFetcher(loader = HttpLeaguePageLoader())
        // Competitie: team matches in one JSON file in the app's files directory (Core's file, off the main thread)
        val teamDirectory = URL(fileURLWithPath = filesDir.absolutePath, isDirectory = true)
        val teamMatchStore = BackgroundTeamMatchStore(directory = teamDirectory)
        // The coach's notes per game live next to the team matches (GameNotes)
        GameNotes.shared.configure(directory = teamDirectory)
        // Registers activity-result launchers, so it must exist before the activity starts
        val appVersion = "Android " + (packageManager.getPackageInfo(packageName, 0).versionName ?: "?")
        val backupStore = RoomBackupStore(db, teamDirectory)
        autoBackup = AutoBackup(this, backupStore, appVersion)
        val backup = BackupContext(store = backupStore, files = ActivityBackupFiles(this), appVersion = appVersion, auto = autoBackup)
        val teamImporter = RoomTeamImporter(db)
        // Bombardino and Whiskey for everyone, as on iOS (SamplePlayers): once
        // per install, also next to existing players, never during instrumented tests
        if (SamplePlayers.isPending && !isInstrumentedTest()) {
            lifecycleScope.launch {
                try {
                    val zip = SamplePlayers.zipData()
                    if (zip != null) teamImporter.importTeam(zip = zip)
                } catch (e: Exception) {
                    android.util.Log.w("SamplePlayers", "Voorbeeldspelers niet toegevoegd", e)
                }
                SamplePlayers.markDone()
            }
        }
        val playerFiles = ActivityPlayerFiles(this)
        val aiCoach = AICoachContext(keyStore = KeystoreAPIKeyStore(this), client = AICoachClient(transport = HttpAICoachTransport()))
        // Live meekijken: the shared LiveShare sends the state through this (server/live)
        LiveShare.shared.transport = HttpLiveTransport()
        // "Deel als plaatje" in Deel score: the result card as a PNG (ResultImage)
        // The PNG is drawn and written off the main thread; the static hook is
        // cleared in onDestroy so it never keeps an old Activity alive
        ResultImageSharing.share = resultImageShare
        setContent {
            val stateHolder = rememberSaveableStateHolder()
            stateHolder.SaveableStateProvider(true) {
                // Weergave (Systeem, Licht, Donker): the base scheme of every screen and top
                // bar is the app's choice; only under Systeem does it follow the phone
                val systemDark = isSystemInDarkTheme()
                val theme = AppTheme.shared
                val light = if (theme.followsSystem) !systemDark else theme.isLight
                // Status and navigation bar icons dark on the light theme, light on the dark one
                SideEffect {
                    val bar = if (light) SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)
                        else SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
                    enableEdgeToEdge(statusBarStyle = bar, navigationBarStyle = bar)
                }
                PresentationRoot(defaultColorScheme = if (light) ColorScheme.light else ColorScheme.dark, context = ComposeContext()) { context ->
                    Box(modifier = context.modifier.fillMaxSize()) {
                        AndroidHomeView(playerStore = playerStore, badgeStore = badgeAwardStore, historyStore = historyStore, matchStore = matchStore, refereeMatchStore = refereeMatchStore, shareText = { startActivity(shareTextIntent(it)) }, cardInbox = cardInbox, cardImportStore = badgeAwardStore, leagueTeamFetcher = leagueTeamFetcher, aiCoach = aiCoach, backup = backup, teamImporter = teamImporter, photoStore = playerStore, filePicker = playerFiles, shareCard = { snapshot, text -> shareOffMainThread { CardImage.shareIntent(this@MainActivity, snapshot, text) } }, teamMatchStore = teamMatchStore)
                            // Page titles 20 sp semibold on every top bar, as PageTitleStyle on iOS (docs/style/README.md)
                            .material3TopAppBar { options ->
                                val title = options.title
                                options.copy(title = {
                                    ProvideTextStyle(MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp, fontWeight = FontWeight.SemiBold)) { title() }
                                })
                            }
                            .Compose(context = context.content())
                    }
                }
                SideEffect { stateHolder.removeState(true) }
            }
        }
    }

    /** Automatic backup, at most once a week, when the app goes to the background (after the evening's matches) */
    /** A live final score that could not be sent (no network) goes now */
    override fun onResume() {
        super.onResume()
        lifecycleScope.launch { LiveShare.shared.retryPending() }
        lifecycleScope.launch { TeamLive.shared.retryPending() }
    }

    private val resultImageShare: (ResultCard) -> Unit = { card -> shareOffMainThread { ResultImage.shareIntent(this, card) } }

    /** Renders a share picture on Dispatchers.IO, then opens the share sheet */
    private fun shareOffMainThread(makeIntent: () -> Intent) {
        lifecycleScope.launch {
            val intent = withContext(Dispatchers.IO) { runCatching(makeIntent).getOrNull() } ?: return@launch
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        if (ResultImageSharing.share === resultImageShare) ResultImageSharing.share = null
        val presenter = LiveFollow.shared.presenter as? FcmLiveFollowPresenter
        if (presenter?.requestNotificationPermission === askNotificationPermission) presenter.requestNotificationPermission = null
        super.onDestroy()
    }

    override fun onStop() {
        super.onStop()
        autoBackup.runIfDueInBackground()
    }

    /** `launchMode="singleTask"`: a link opened while the app runs arrives here */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receiveCardLink(intent)
    }

    /** Decoded off the main thread (a link is untrusted input), handed over on it */
    private fun receiveCardLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val link = intent.dataString ?: return
        // A live match to follow on the lock screen (squashanalyzer://volg#<id>)
        if (link.startsWith("squashanalyzer://volg")) {
            val target = LiveFollowLink.parse(link)
            if (target == null) showNewerAppNeeded() else followLive(target)
            return
        }
        lifecycleScope.launch {
            // An invitation to a live team match is checked first: it is small and no card
            val invite = withContext(Dispatchers.Default) { CardInbox.invite(from = link) }
            if (invite != null) {
                cardInbox.acceptTeam(invite)
                return@launch
            }
            val snapshot = withContext(Dispatchers.Default) { CardInbox.snapshot(from = link) }
            if (snapshot != null) {
                cardInbox.accept(snapshot)
            } else if (CardInbox.needsNewerApp(link)) {
                showNewerAppNeeded()
            }
        }
    }

    /** Live score on the lock screen: follow the match, and say how it went */
    private fun followLive(target: LiveFollowTarget) {
        lifecycleScope.launch {
            val message = try {
                LiveFollow.shared.follow(target)
                // "Jan – Piet", or the teams of a team match
                val title = LiveFollow.shared.title(of = target)
                if (title == null) "Je volgt de wedstrijd op je vergrendelscherm"
                else "Je volgt $title op je vergrendelscherm"
            } catch (e: LiveFollowError) {
                when (e) {
                    is LiveFollowError.NotFoundCase -> "Deze wedstrijd is al afgelopen"
                    is LiveFollowError.NotAllowedCase -> "Meldingen staan uit voor SquashAnalyzer"
                    is LiveFollowError.NoConnectionCase -> "Geen verbinding"
                    is LiveFollowError.PushUnavailableCase -> "Deze server kan (nog) geen meldingen sturen"
                    else -> "Volgen lukt nu niet"
                }
            } catch (e: Exception) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                "Volgen lukt nu niet"
            }
            android.widget.Toast.makeText(this@MainActivity, message, android.widget.Toast.LENGTH_LONG).show()
        }
    }

    /** A link of ours this version cannot open (made by a newer app): say so instead of nothing */
    private fun showNewerAppNeeded() {
        AlertDialog.Builder(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert)
            .setTitle("Link niet te openen")
            .setMessage(CardInbox.newerAppText + " Werk de app bij in Google Play.")
            .setPositiveButton("Naar Google Play") { _, _ ->
                startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(CardInbox.playStoreLink)))
            }
            .setNegativeButton("Later", null)
            .show()
    }

    /** Identifies this install as the awarding coach, like iOS' `BadgeAwarder.installId` */
    private fun badgeInstallId(): String {
        // Its own preferences file, left out of the cloud backup and device transfer:
        // a restore onto another phone must not give two phones the same id
        val prefs = getSharedPreferences("squash-analyzer-install", MODE_PRIVATE)
        prefs.getString("badgeInstallId", null)?.let { return it }
        // An id that was kept with the other settings before moves here (and leaves the backed-up file)
        val old = getSharedPreferences("squash-analyzer", MODE_PRIVATE)
        val id = old.getString("badgeInstallId", null) ?: java.util.UUID.randomUUID().toString().uppercase()
        prefs.edit().putString("badgeInstallId", id).apply()
        old.edit().remove("badgeInstallId").apply()
        return id
    }

    private fun isInstrumentedTest(): Boolean = try {
        Class.forName("androidx.test.platform.app.InstrumentationRegistry")
        true
    } catch (e: ClassNotFoundException) {
        false
    }
}
