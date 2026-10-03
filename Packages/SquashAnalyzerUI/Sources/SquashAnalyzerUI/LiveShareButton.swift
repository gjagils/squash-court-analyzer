import SwiftUI
import SquashAnalyzerCore

/// "LIVE" in the header of the coach and referee screens (iOS and Android).
/// Not live: tap to start live sharing and share the link (WhatsApp). Live: a
/// red ● LIVE; tap to share the link again or stop. The state itself is sent
/// by `LiveShareSync` after every rally; see docs/plan-live-meekijken.md.
public struct LiveShareButton: View {
    let matchId: UUID
    let snapshot: () -> LiveSnapshot
    let share: ((String) -> Void)?

    @State private var busy = false
    @State private var showingMenu = false
    @State private var failed = false

    public init(matchId: UUID, snapshot: @escaping () -> LiveSnapshot, share: ((String) -> Void)?) {
        self.matchId = matchId
        self.snapshot = snapshot
        self.share = share
    }

    private var live: LiveShare { LiveShare.shared }

    public var body: some View {
        let isLive = live.isLive(matchId)
        let newLink = isLive && live.linkChanged
        let red = Color(red: 0.90, green: 0.28, blue: 0.30)
        Button(action: tap) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isLive ? Color.white : red)
                    .frame(width: 7, height: 7)
                Text(busy ? "…" : (newLink ? "NIEUWE LINK" : "LIVE"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(isLive ? Color.white : red)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // .background(colour) + clipShape: filled shapes behind text misbehave on Android
            .background(isLive ? red : red.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(red.opacity(0.6), lineWidth: 1))
            .opacity(live.offline && isLive ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(isLive ? "Live: link delen of stoppen" : "Live delen")
        .alert("Live meekijken", isPresented: $showingMenu) {
            Button("Link opnieuw delen") { shareLink() }
            Button("Live stoppen", role: .destructive) {
                Task { await live.stop() }
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text(live.offline ? "Geen verbinding: de stand gaat weer mee zodra er netwerk is." : "Kijkers volgen de stand via de link. Na de wedstrijd wordt alles gewist.")
        }
        .alert("Live delen lukte niet", isPresented: $failed) {
            // No .cancel role: with only a cancel button Skip adds its own "OK" (two OKs on Android)
            Button("OK") {}
        } message: {
            Text("Controleer de internetverbinding en probeer het opnieuw.")
        }
    }

    private func tap() {
        if live.isLive(matchId) {
            if live.linkChanged {
                shareLink()
            } else {
                showingMenu = true
            }
            return
        }
        busy = true
        let state = snapshot()
        Task {
            do {
                _ = try await live.start(matchId: matchId, snapshot: state)
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
        share?("Volg \(state.p1) – \(state.p2) live: \(link)")
    }
}

/// Sends the match state to the live server after a change (the scoring
/// screens call this where they save the match). The final state deletes the
/// session at once. Nothing happens when the match is not live.
public enum LiveShareSync {
    @MainActor
    public static func send(matchId: UUID, snapshot: LiveSnapshot) {
        let live = LiveShare.shared
        guard live.isLive(matchId) else { return }
        if snapshot.status == LiveStatus.finished {
            Task { await live.finish(matchId: matchId, snapshot: snapshot) }
        } else {
            live.update(matchId: matchId, snapshot: snapshot)
        }
    }
}
