import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

/// The app's root: the home screen, with the shared coach and referee
/// sessions, Afgeronde wedstrijden and the analysis on top of it (the same
/// screens as on Android, over SwiftData; see Services/SwiftDataStores.swift).
/// Also the app-wide work: player card links, the weekly backup and live
/// scores that still have to go out.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let startupPersistenceWarning: String?

    init(startupPersistenceWarning: String? = nil) {
        self.startupPersistenceWarning = startupPersistenceWarning
    }

    @State private var showingCoach = false
    @State private var showingReferee = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    /// A finished coach match opened for its analysis from Afgeronde wedstrijden
    @State private var analysedMatch: Match? = nil
    @State private var showingStartupPersistenceWarning = false
    /// A player card link that was opened and waits for the import sheet (shared with Android)
    @State private var cardInbox = CardInbox()
    /// The join sheet for `cardInbox.pendingTeam` is on screen (not while a full-screen cover is up)
    @State private var showingTeamJoin = false
    /// A link of ours this version cannot open (made by a newer app)
    @State private var showingNewerAppNeeded = false
    @Environment(\.openURL) private var openURL
    #if DEBUG
    /// App Store screenshots (scripts/screenshots.sh): a scoring screen in a prepared state
    @State private var screenshotCoach: Match? = nil
    @State private var screenshotReferee: RefereeMatch? = nil
    #endif

    var body: some View {
        HomeView(onCoach: { showingCoach = true },
                 onReferee: { showingReferee = true },
                 onViewHistory: { showingHistory = true },
                 onOpenSettings: { showingSettings = true })
        .fullScreenCover(isPresented: $showingCoach) {
            let players = SwiftDataPlayerStore(context: modelContext)
            CoachSessionView(store: SwiftDataCoachMatchStore(context: modelContext), playerStore: players, photoStore: players,
                             aiCoach: IOSAICoach.context, shareText: { IOSShare.text($0) },
                             historyStore: SwiftDataMatchHistoryStore(context: modelContext),
                             settings: SettingsContext(aiCoach: IOSAICoach.context, backup: nil),
                             teamMatchStore: TeamMatchStorage.store,
                             onExit: { showingCoach = false })
        }
        .fullScreenCover(isPresented: $showingReferee) {
            let players = SwiftDataPlayerStore(context: modelContext)
            RefereeSessionView(store: SwiftDataRefereeMatchStore(context: modelContext), playerStore: players,
                               photoStore: players, shareText: { IOSShare.text($0) },
                               teamMatchStore: TeamMatchStorage.store,
                               onExit: { showingReferee = false })
        }
        .fullScreenCover(isPresented: $showingHistory) {
            NavigationStack {
                SharedMatchHistoryView(store: SwiftDataMatchHistoryStore(context: modelContext), aiCoach: IOSAICoach.context,
                                       shareText: { IOSShare.text($0) }) { match in
                    // As before: the list closes and the analysis opens
                    showingHistory = false
                    analysedMatch = match
                }
                .toolbar {
                    CloseToolbarItem { showingHistory = false }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
        }
        .fullScreenCover(isPresented: Binding(get: { analysedMatch != nil }, set: { if !$0 { analysedMatch = nil } })) {
            if let match = analysedMatch {
                SharedCoachDashboardView(match: match, game: match.games.last ?? match.currentGame, aiCoach: IOSAICoach.context,
                                         shareText: { IOSShare.text($0) }) { analysedMatch = nil }
            }
        }
        #if DEBUG
        .fullScreenCover(isPresented: Binding(get: { screenshotCoach != nil }, set: { if !$0 { screenshotCoach = nil } })) {
            if let match = screenshotCoach {
                CoachScoringView(match: match, onMatchChanged: { _ in }, onExit: { screenshotCoach = nil })
            }
        }
        .fullScreenCover(isPresented: Binding(get: { screenshotReferee != nil }, set: { if !$0 { screenshotReferee = nil } })) {
            if let match = screenshotReferee {
                RefereeScoringView(match: match, onMatchChanged: { _ in }, onExit: { screenshotReferee = nil })
            }
        }
        #endif
        .onAppear {
            #if DEBUG
            ScreenshotScenario.importTeamIfRequested(context: modelContext)
            if let scenario = ScreenshotScenario.current {
                applyScreenshotScenario(scenario)
                return
            }
            #endif
            TeamImportService.addSamplePlayersIfNew(context: modelContext)
            showingStartupPersistenceWarning = startupPersistenceWarning != nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                AutomaticBackup.runIfDue(context: modelContext)
            }
            // A link that arrived during a cold start, before there was a window
            if phase == .active {
                presentPendingCard()
                presentPendingTeam()
                // A live final score that could not be sent (no network) goes now
                Task { await LiveShare.shared.retryPending() }
                Task { @MainActor in TeamLive.shared.retryPending() }
            }
        }
        // A player card link (website or squashanalyzer://kaart#…)
        .onOpenURL { url in
            if !cardInbox.receive(url.absoluteString) && CardInbox.needsNewerApp(url.absoluteString) {
                showingNewerAppNeeded = true
            }
        }
        .onChange(of: cardInbox.pending) { _, _ in
            presentPendingCard()
        }
        .onChange(of: cardInbox.pendingTeam) { _, _ in
            presentPendingTeam()
        }
        // A card or an invitation that came in during a match waits for the screen to be free
        .onChange(of: anyCoverOpen) { _, open in
            if !open {
                presentPendingCard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { presentPendingTeam() }
            }
        }
        // A link to a live team match (Competitie): join it
        .sheet(isPresented: $showingTeamJoin, onDismiss: { cardInbox.pendingTeam = nil }) {
            if let invite = cardInbox.pendingTeam {
                SharedTeamJoinView(store: TeamMatchStorage.store, team: TeamMatchSupport.cachedTeam(), initialCode: invite.code) { _ in
                    showingTeamJoin = false
                } onCancel: { showingTeamJoin = false }
            }
        }
        .alert("Link niet te openen", isPresented: $showingNewerAppNeeded) {
            Button("Naar de App Store") {
                if let url = URL(string: CardInbox.appStoreLink) { openURL(url) }
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text(CardInbox.newerAppText + " Testers vinden de nieuwe versie in TestFlight.")
        }
        .alert("Veilige tijdelijke opslag actief", isPresented: $showingStartupPersistenceWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(startupPersistenceWarning ?? "")
        }
    }

    /// A full-screen cover is up: a sheet cannot open over it from here
    private var anyCoverOpen: Bool {
        showingCoach || showingReferee || showingHistory || showingSettings || analysedMatch != nil
    }

    /// The join sheet for a pending invitation, as soon as no cover is up
    private func presentPendingTeam() {
        showingTeamJoin = cardInbox.pendingTeam != nil && !anyCoverOpen
    }

    /// Shows the import sheet for a pending card link. At a cold start there is
    /// no window yet: tried again a few times, and whenever the app becomes active.
    private func presentPendingCard(attempt: Int = 0) {
        // Asked what is really on screen, not a flag that goes stale when UIKit
        // takes the sheet away with a closing cover
        guard let snapshot = cardInbox.pending, !CardImportPresenter.isShowing else { return }
        let shown = CardImportPresenter.present(snapshot, container: modelContext.container) {
            cardInbox.pending = nil
        }
        if !shown, attempt < 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { presentPendingCard(attempt: attempt + 1) }
        }
    }

    #if DEBUG
    // MARK: - App Store screenshots (see scripts/screenshots.sh)
    private func applyScreenshotScenario(_ scenario: ScreenshotScenario) {
        switch scenario {
        case .home:
            break
        case .setup:
            showingCoach = true
        case .referee:
            screenshotReferee = ScreenshotScenario.makeRefereeMatch()
        case .coachMatch:
            screenshotCoach = ScreenshotScenario.makeCoachMatch()
        case .coachZone:
            screenshotCoach = ScreenshotScenario.makeCoachZoneMatch()
        case .coachGameOver:
            screenshotCoach = ScreenshotScenario.makeCoachGameOverMatch()
        case .badges:
            screenshotCoach = ScreenshotScenario.makeCoachBadgesMatch(context: modelContext)
        case .history:
            _ = ScreenshotScenario.seededSampleMatch(context: modelContext)
            showingHistory = true
        case .dashboard:
            guard let saved = ScreenshotScenario.seededSampleMatch(context: modelContext) else { return }
            analysedMatch = saved.toMatch()
        }
    }
    #endif
}
