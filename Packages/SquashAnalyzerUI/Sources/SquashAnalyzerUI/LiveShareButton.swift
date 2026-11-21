import SwiftUI
import SquashAnalyzerCore

/// The share control in the header of the coach and referee screens (iOS and
/// Android). One button since 21 November 2026 (Gerd-Jan: a grey LIVE next to
/// a separate share icon was confusing, above all for a partij that already
/// goes to the team live): a share icon that opens "Delen", with next to it
/// where the score goes now:
/// - `TEAM` (sea green outline): the match is a partij of a live team match,
///   the team sees it in the app;
/// - `LIVE` (sea green, filled): viewers follow it with the link.
/// "Delen" offers Live voor kijkers (start and share the link; only with
/// "Live aanbieden bij het scoren" on in Instellingen), Deel de stand (text
/// or picture, when the screen has it), and while live the link again or
/// stop. The state itself is sent by `LiveShareSync` after every rally; see
/// docs/archief/plan-live-meekijken.md. Brings its own leading gap, so a
/// hidden control leaves none.
public struct LiveShareButton: View {
    let matchId: UUID
    let snapshot: () -> LiveSnapshot
    let share: ((String) -> Void)?
    /// Both players' photos (as stored); sent as thumbnails when "Foto's meesturen" is on
    let photos: (() -> [Data?])?
    /// "Deel de stand": the score as text or picture (the referee screen)
    let onShareScore: (() -> Void)?
    /// False once the match is over: live can no longer start
    let canGoLive: Bool

    @State private var busy = false
    @State private var showingMenu = false
    @State private var failed = false
    @AppStorage(LiveShare.enabledKey) private var enabled = true
    @AppStorage(LiveShare.photosKey) private var sendPhotos = true

    public init(matchId: UUID, snapshot: @escaping () -> LiveSnapshot, photos: (() -> [Data?])? = nil, share: ((String) -> Void)?,
                canGoLive: Bool = true, onShareScore: (() -> Void)? = nil) {
        self.matchId = matchId
        self.snapshot = snapshot
        self.photos = photos
        self.share = share
        self.canGoLive = canGoLive
        self.onShareScore = onShareScore
    }

    private var live: LiveShare { LiveShare.shared }
    /// Live can be started from here
    private var offersLive: Bool { enabled && canGoLive && share != nil }

    public var body: some View {
        let isLive = live.isLive(matchId)
        if offersLive || isLive || onShareScore != nil {
            button(isLive: isLive)
                .padding(.leading, 8.0)
        }
    }

    private func button(isLive: Bool) -> some View {
        let newLink = isLive && live.linkChanged
        // Live is the support colour, sea green (since 1 November 2026; red is
        // for errors): green always means someone can follow along
        let green = SharedColors.support
        let inTeam = TeamLive.shared.isBound(matchId)
        return Button(action: tap) {
            HStack(spacing: 6) {
                if isLive {
                    status(busy ? "…" : (newLink ? loc("NIEUWE LINK") : "LIVE"), text: SharedColors.onAccent, fill: green, line: green.opacity(0.6))
                        .opacity(live.offline ? 0.6 : 1.0)
                } else if inTeam {
                    status("TEAM", text: green, fill: green.opacity(0.10), line: green.opacity(0.8))
                }
                AppSymbol("square.and.arrow.up", size: 20, color: SharedColors.accent)
                    .frame(width: 36, height: 32)
            }
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(isLive ? loc("Delen, live voor kijkers") : (inTeam ? loc("Delen, je team ziet deze partij") : loc("Delen")))
        .alert(loc("Delen"), isPresented: $showingMenu) {
            if isLive {
                Button(loc("Link opnieuw delen")) { shareLink() }
            } else if offersLive {
                Button(loc("Live voor kijkers")) { startLive() }
            }
            if let onShareScore {
                Button(loc("Deel de stand")) { onShareScore() }
            }
            if isLive {
                Button(loc("Live stoppen"), role: .destructive) {
                    Task { await live.stop() }
                }
            }
            Button(loc("Annuleren"), role: .cancel) {}
        } message: {
            Text(menuText(isLive: isLive, inTeam: inTeam))
        }
        .alert(loc("Live delen lukte niet"), isPresented: $failed) {
            // No .cancel role: with only a cancel button Skip adds its own "OK" (two OKs on Android)
            Button(loc("OK")) {}
        } message: {
            Text("Controleer de internetverbinding en probeer het opnieuw.", bundle: textBundle)
        }
    }

    /// `● LIVE` or `● TEAM`: where the score goes now
    private func status(_ title: String, text: Color, fill: Color, line: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(text)
                .frame(width: 7, height: 7)
            Text(title)
                .font(SharedFonts.system(11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        // .background(colour) + clipShape: filled shapes behind text misbehave on Android
        .background(fill)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(line, lineWidth: 1))
    }

    private func menuText(isLive: Bool, inTeam: Bool) -> String {
        if isLive {
            return live.offline ? loc("Geen verbinding: de stand gaat weer mee zodra er netwerk is.")
                : loc("Kijkers volgen de stand via de link. 2 uur na de wedstrijd wordt alles gewist (ook de foto's); Live stoppen wist het meteen.")
        }
        if inTeam { return loc("Je team ziet deze partij al in de app. Live is voor kijkers met de link.") }
        return loc("Met Live deel je een link; wie erop tikt ziet de stand in de browser.")
    }

    private func tap() {
        // A new link (the old one expired) is shared at once
        if live.isLive(matchId) && live.linkChanged {
            shareLink()
            return
        }
        // Nothing to choose: only the score can be shared
        if !live.isLive(matchId) && !offersLive, let onShareScore {
            onShareScore()
            return
        }
        showingMenu = true
    }

    private func startLive() {
        busy = true
        let state = snapshot()
        let stored = sendPhotos ? photos?() : nil
        Task {
            do {
                // Small thumbnails, made only when the photos go along
                var thumbnails: LivePhotos? = nil
                if let stored, stored.count == 2 {
                    thumbnails = LivePhotoThumbnail.photos(player1: stored[0], player2: stored[1])
                }
                _ = try await live.start(matchId: matchId, snapshot: state, photos: thumbnails)
                busy = false
                shareLink()
            } catch {
                busy = false
                failed = true
            }
        }
    }

    private func shareLink() {
        guard let link = live.link else { return }
        live.acknowledgeLink()
        let state = snapshot()
        share?(loc("Volg \(state.p1) – \(state.p2) live: \(link)"))
    }
}

/// Sends the match state to the live server after a change (the scoring
/// screens call this where they save the match). The final state deletes the
/// session at once. Nothing happens when the match is not live.
public enum LiveShareSync {
    /// Platform hook for "Stand op vergrendelscherm": the score of the match
    /// this phone is scoring, with the start of the match timer when known
    /// (iOS: a Live Activity updated locally; nil on Android for now)
    @MainActor public static var localActivity: ((UUID, LiveSnapshot, Date?) -> Void)? = nil
    /// The scoring screen closed: take the match off the lock screen
    @MainActor public static var localActivityEnded: ((UUID) -> Void)? = nil
    /// Both players' photos (as stored) for the lock screen's avatars; the
    /// platform keeps them once per match (iOS; nil on Android for now)
    @MainActor public static var localActivityPhotos: ((UUID, [Data?]) -> Void)? = nil

    /// `photos` is only read when the platform shows the own match on the lock screen
    @MainActor
    public static func send(matchId: UUID, snapshot: LiveSnapshot, startedAt: Date? = nil, photos: (() -> [Data?])? = nil) {
        if let photos, let storePhotos = localActivityPhotos {
            storePhotos(matchId, photos())
        }
        localActivity?(matchId, snapshot, startedAt)
        // A match played for a partij of a live team match also goes to the team page
        TeamLive.shared.forward(matchId: matchId, snapshot: snapshot)
        sendTeamPhotos(matchId: matchId, photos: photos)
        let live = LiveShare.shared
        guard live.isLive(matchId) else { return }
        if snapshot.status == LiveStatus.finished {
            Task { await live.finish(matchId: matchId, snapshot: snapshot) }
        } else {
            live.update(matchId: matchId, snapshot: snapshot)
        }
    }

    /// The scoring screen of `matchId` appeared: a match played for a partij of
    /// a live team match puts its first state (warm-up) and the players'
    /// photos on the team page right away, instead of after the first point
    @MainActor
    public static func started(matchId: UUID, snapshot: LiveSnapshot, photos: (() -> [Data?])? = nil) {
        guard TeamLive.shared.isBound(matchId) else { return }
        TeamLive.shared.forward(matchId: matchId, snapshot: snapshot)
        sendTeamPhotos(matchId: matchId, photos: photos)
    }

    /// The players' photos go to the partij of the team page once per match
    /// (as thumbnails), when "Foto's meesturen" is on
    @MainActor
    static func sendTeamPhotos(matchId: UUID, photos: (() -> [Data?])?) {
        guard let photos, TeamLive.shared.wantsPhotos(matchId) else { return }
        let defaults = UserDefaults.standard
        let allowed = defaults.object(forKey: LiveShare.photosKey) == nil || defaults.bool(forKey: LiveShare.photosKey)
        guard allowed else { return }
        let stored = photos()
        guard stored.count == 2, stored[0] != nil || stored[1] != nil else { return }
        TeamLive.shared.sendPhotos(matchId: matchId, photos: LivePhotoThumbnail.photos(player1: stored[0], player2: stored[1]))
    }

    /// The scoring screen of `matchId` closed (finished, saved for later or
    /// dropped): the lock screen no longer shows it
    @MainActor
    public static func endLocal(matchId: UUID) {
        // A single optional call is an expression body in Kotlin (Unit? ≠ Unit)
        guard let ended = localActivityEnded else { return }
        ended(matchId)
    }
}
