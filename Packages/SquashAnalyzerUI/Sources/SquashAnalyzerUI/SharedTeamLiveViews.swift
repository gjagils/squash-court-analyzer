import SwiftUI
import SquashAnalyzerCore

// MARK: - Live teamwedstrijd (docs/plan-live-teamwedstrijd.md)
//
// The live card on the team match screen, and the screen to join a live team
// match with a link or code. The logic (create, push, stop, read the page)
// is in Core's `TeamLive`; the screens only call it.

/// "LIVE" on a team match: start it, share the viewers' link, invite fellow
/// coaches, refresh from the page, stop. Only presentation; the team match
/// screen does the work.
struct TeamLiveCard: View {
    let match: TeamMatch
    let busy: Bool
    let canShare: Bool
    /// What is wrong with sending (a refused key, no connection), or nil
    var problem: String? = nil
    let onGoLive: () -> Void
    let onShareViewers: () -> Void
    let onShareInvite: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("LIVE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(SharedColors.accent)
                if match.isLive {
                    HStack(spacing: 5) {
                        Circle().fill(Color.white).frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(Color.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(SharedColors.warmRed)
                    .clipShape(Capsule())
                }
                Spacer()
            }
            if match.isLive {
                Text("Kijkers volgen de hele teamavond op één pagina. Teamgenoten die de uitnodiging openen, zetten hun eigen partij erop. 2 uur na de laatste update wordt alles gewist.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if canShare {
                    ActionButton("Deel kijkerslink", icon: "square.and.arrow.up", style: .filled, disabled: busy, action: onShareViewers)
                    ActionButton("Nodig teamgenoten uit", icon: "square.and.arrow.up", disabled: busy, action: onShareInvite)
                }
                if let problem {
                    Text(problem)
                        .font(.system(size: 12))
                        .foregroundColor(SharedColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    ActionButton("Vernieuwen", icon: "arrow.counterclockwise", disabled: busy, action: onRefresh)
                    // Only the phone that started the live page can end it for everyone
                    ActionButton(match.isLiveOwner ? "Live stoppen" : "Live verlaten", color: SharedColors.textSecondary,
                                 disabled: busy, action: onStop)
                }
            } else {
                Text("Laat je team en de groepsapp de stand van de hele avond live volgen, per partij ook punt voor punt. Alleen teamnamen, voornamen en de stand gaan mee.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionButton(busy ? "Even geduld…" : "Live delen", style: .filled, disabled: busy, action: onGoLive)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// The texts that go to the group app
enum TeamLiveTexts {
    static func viewers(_ match: TeamMatch, baseURL: String) -> String {
        guard let id = match.liveId else { return "" }
        return "Volg \(match.title) live: \(baseURL)/t/\(id)"
    }

    static func invite(_ match: TeamMatch) -> String {
        guard let id = match.liveId, let key = match.liveKey else { return "" }
        let invite = TeamInvite(id: id, key: key)
        return "Doe mee met onze teamwedstrijd \(match.title) in SquashAnalyzer en zet je eigen partij live: \(invite.link)\n"
            + "Of plak deze code in de app (Competitie, Deelnemen): \(invite.code)"
    }
}

// MARK: - Deelnemen

/// Join a live team match with the link or the code a team mate shared. Asks
/// which of the two teams is ours, and makes a local copy that follows the
/// live page and puts our own partij on it.
public struct SharedTeamJoinView: View {
    private let store: any TeamMatchStore
    private let team: LeagueTeamSnapshot?
    private let onJoined: (TeamMatch) -> Void
    private let onCancel: () -> Void

    @State private var text: String
    @State private var invite: TeamInvite? = nil
    @State private var state: TeamLiveState? = nil
    @State private var ownSide: TeamSide = TeamSide.home
    @State private var busy = false
    @State private var message: String? = nil

    public init(store: any TeamMatchStore, team: LeagueTeamSnapshot? = nil, initialCode: String = "",
                onJoined: @escaping (TeamMatch) -> Void, onCancel: @escaping () -> Void) {
        self.store = store
        self.team = team
        self.onJoined = onJoined
        self.onCancel = onCancel
        _text = State(initialValue: initialCode)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Een teamgenoot deelde een link of code van de live teamwedstrijd. Plak die hier; je partij komt dan op dezelfde livepagina.")
                            .font(.system(size: 13))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("Link of code", text: $text)
                            .font(.system(size: 14))
                            .foregroundColor(SharedColors.textPrimary)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        if state == nil {
                            ActionButton(busy ? "Even geduld…" : "Zoek teamwedstrijd", style: .filled,
                                         disabled: busy || text.trimmingCharacters(in: .whitespaces).isEmpty) {
                                Task { await lookUp() }
                            }
                        }
                        if let state {
                            found(state)
                        }
                        if let message {
                            Text(message).font(.system(size: 12)).foregroundColor(SharedColors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle("Deelnemen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
            }
            .task {
                if invite == nil, !text.isEmpty, TeamInvite.parse(text) != nil { await lookUp() }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func found(_ state: TeamLiveState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GEVONDEN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(SharedColors.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(state.team.home) – \(state.team.away)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(TeamMatchReport.dayText(Date(timeIntervalSince1970: Double(state.team.date) / 1000.0))) · \(state.partijen.count) van 4 partijen staan erop")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
            }
            Text("Welk team is van jou?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            HStack(spacing: 10) {
                sideButton(state.team.home, side: TeamSide.home)
                sideButton(state.team.away, side: TeamSide.away)
            }
            ActionButton(busy ? "Even geduld…" : "Deelnemen", style: .filled, disabled: busy) {
                Task { await join(state) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sideButton(_ name: String, side: TeamSide) -> some View {
        let selected = ownSide == side
        return Button { ownSide = side } label: {
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? SharedColors.background : SharedColors.accent)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background(selected ? SharedColors.accent : SharedColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func lookUp() async {
        guard let parsed = TeamInvite.parse(text) else {
            message = "Dit is geen geldige link of code van een teamwedstrijd."
            return
        }
        busy = true
        message = nil
        do {
            let fetched = try await TeamLive.shared.fetch(id: parsed.id)
            invite = parsed
            state = fetched
            // Our own team by name, when Mijn team has one
            if let team {
                if TeamMatch.sameTeam(fetched.team.away, team.name) { ownSide = TeamSide.away }
                if TeamMatch.sameTeam(fetched.team.home, team.name) { ownSide = TeamSide.home }
            }
        } catch let error as TeamLiveError {
            message = error == TeamLiveError.gone
                ? "Deze teamwedstrijd is afgelopen of de link klopt niet."
                : "Geen verbinding. Controleer het internet en probeer het opnieuw."
        } catch {
            message = "Opzoeken lukte niet."
        }
        busy = false
    }

    private func join(_ fetched: TeamLiveState) async {
        guard let invite else { return }
        busy = true
        message = nil
        // The code must work before we keep it: a mistyped key would otherwise
        // never show anywhere
        do {
            _ = try await TeamLive.shared.verify(id: invite.id, key: invite.key)
        } catch let error as TeamLiveError {
            busy = false
            switch error {
            case TeamLiveError.keyRejected:
                message = "De code klopt niet: de teamwedstrijd is gevonden, maar de sleutel wordt niet geaccepteerd. Vraag je teamgenoot de uitnodiging opnieuw te sturen."
            case TeamLiveError.gone:
                message = "Deze teamwedstrijd is afgelopen of de link klopt niet."
            default:
                message = "Geen verbinding. Controleer het internet en probeer het opnieuw."
            }
            return
        } catch {
            busy = false
            message = "Controleren van de code lukte niet."
            return
        }
        do {
            let all = try await store.loadAll()
            // Joined before: that copy, with what the page has now
            for var existing in all where existing.liveId == invite.id {
                _ = existing.mergeLive(fetched)
                try await store.save(existing)
                busy = false
                onJoined(existing)
                return
            }
            let match = TeamMatch.joining(fetched, invite: invite, ownSide: ownSide)
            try await store.save(match)
            busy = false
            onJoined(match)
        } catch {
            busy = false
            message = "Deelnemen is niet gelukt."
        }
    }
}
