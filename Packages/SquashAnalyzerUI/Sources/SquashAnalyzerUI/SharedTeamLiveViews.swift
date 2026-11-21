import SwiftUI
import SquashAnalyzerCore

// MARK: - Live teamwedstrijd (docs/plan-live-teamwedstrijd.md)
//
// The "Delen" sheet of the team match screen, and the screen to join a live
// team match with a link or code. The logic (create, push, stop, read the page)
// is in Core's `TeamLive`; the screens only call it.

/// E1–E4 as items and as text, for the team match screens
enum TeamLiveCard {
    static let slotItems: [TeamSlotItem] = [TeamSlotItem(slot: 1), TeamSlotItem(slot: 2), TeamSlotItem(slot: 3), TeamSlotItem(slot: 4)]

    /// "E2, E3"
    static func labels(_ slots: [Int]) -> String {
        var parts: [String] = []
        for slot in slots.sorted() { parts.append("E\(slot)") }
        return parts.joined(separator: ", ")
    }
}

/// "Delen" of a team match (Gerd-Jan, 21 November 2026: the banner and the
/// DELEN block showed up to fourteen controls at once). Three rows say who
/// sees the team match, each with its one action:
/// - **Team**: the team (and the opponent) in the app;
/// - **Live**: viewers with the link, and the club screen;
/// - **Volgen**: the team stand on this phone's lock screen.
/// Under "Meer": the invitation for a teammate without an account, which
/// partijen the opponent referees, refresh, and stop. Only presentation; the
/// team match screen does the work.
struct TeamShareOptionsSheet: View {
    let match: TeamMatch
    let busy: Bool
    let canShare: Bool
    /// What is wrong with sending (a refused key, no connection), or nil
    var problem: String? = nil
    /// Owner of a team-only live team match: the partijen the opponent referees now (nil: unknown)
    var refereeSlots: [Int]? = nil
    /// "Deel met mijn team" on a team match that is not shared yet
    let onGoLive: () -> Void
    /// Live on a team-only live team match (club screen and viewers' link)
    let onGoPublic: () -> Void
    /// Shares the viewers' link of a public live team match
    let onShareViewers: () -> Void
    /// The invitation, for teammates without an account or on an older app
    let onInvite: () -> Void
    /// Owner: a partij moves between "wij fluiten" and "tegenstander fluit"
    let onToggleReferee: (Int) -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void
    let onClose: () -> Void

    private var isPublic: Bool { match.isLive && !match.isTeamOnly && !match.isOpponentCopy }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(spacing: 0) {
                            teamRow
                            if !match.isOpponentCopy {
                                divider
                                liveRow
                            }
                            if let liveId = match.liveId, match.isLive, !match.isComplete, LiveFollow.shared.presenter != nil {
                                divider
                                TeamLockScreenRow(target: LiveFollowTarget(id: liveId, server: TeamLive.shared.baseURL, kind: "team"))
                                    .padding(14)
                            }
                        }
                        .background(SharedColors.tint(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        if let problem {
                            Text(problem)
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if match.isLive { more }
                        Text(isPublic ? loc("2 uur na de laatste update wordt alles van de livepagina gewist. Alleen teamnamen, voornamen en de stand gaan mee.")
                             : loc("Alleen teamnamen, voornamen en de stand gaan mee."))
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(24)
                }
            }
            .pageTitle(loc("Delen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: loc("Sluiten"), action: onClose)
                }
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private var divider: some View {
        Rectangle().fill(SharedColors.line(0.12)).frame(height: 1).padding(.leading, 14)
    }

    private func labels(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SharedFonts.system(16, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Text(detail)
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "● Aan" in the live colour
    private var onMark: some View {
        HStack(spacing: 6) {
            Circle().fill(SharedColors.support).frame(width: 8, height: 8)
            Text("Aan", bundle: textBundle)
                .font(SharedFonts.system(13, weight: .semibold))
                .foregroundColor(SharedColors.support)
        }
    }

    private var teamRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                labels(loc("Team"), match.isOpponentCopy
                       ? loc("Je kijkt mee en vult in wat jullie fluiten")
                       : loc("Je team en de tegenstander zien dit in de app"))
                if match.isLive { onMark }
            }
            if !match.isLive {
                ActionButton(busy ? loc("Even geduld…") : loc("Deel met mijn team"), style: .filled, disabled: busy, action: onGoLive)
            }
        }
        .padding(14)
    }

    private var liveRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                labels(loc("Live"), loc("Kijklink voor supporters en het clubscherm"))
                if isPublic { onMark }
            }
            if isPublic {
                if canShare {
                    ActionButton(loc("Deel kijkerslink"), icon: "square.and.arrow.up", style: .filled, disabled: busy, action: onShareViewers)
                }
            } else if match.isTeamOnly {
                if match.isLiveOwner {
                    ActionButton(busy ? loc("Even geduld…") : loc("Zet Live aan"), disabled: busy, action: onGoPublic)
                } else {
                    Text("Wie de teamwedstrijd startte, zet dit aan.", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textMuted)
                }
            } else {
                Text("Deel eerst met je team.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textMuted)
            }
        }
        .padding(14)
    }

    private var more: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(loc("MEER"))
            VStack(alignment: .leading, spacing: 14) {
                if !match.isOpponentCopy {
                    VStack(alignment: .leading, spacing: 8) {
                        labels(loc("Uitnodigen zonder account"), loc("Een link of code voor een teamgenoot zonder account of met een oudere app"))
                        if canShare {
                            ActionButton(loc("Nodig teamleden uit"), icon: "square.and.arrow.up", disabled: busy, action: onInvite)
                        }
                        if let id = match.liveId, let key = match.liveKey {
                            // Also readable when nothing can be shared: the code teammates paste at Deelnemen
                            Text("Code om mee te doen: \(TeamInvite(id: id, key: key).code)", bundle: textBundle)
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if match.isLiveOwner, match.isTeamOnly, let refereeSlots {
                    refereeRow(refereeSlots)
                }
                HStack(spacing: 10) {
                    ActionButton(loc("Vernieuwen"), icon: "arrow.counterclockwise", disabled: busy, action: onRefresh)
                    // Only the phone that started the live page can end it for everyone
                    ActionButton(match.isLiveOwner ? loc("Stoppen met delen") : loc("Niet meer meedoen"), color: SharedColors.textSecondary,
                                 disabled: busy, action: onStop)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.tint(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    /// "Tegenstander fluit": E1–E4, a tap moves a partij between us and them
    private func refereeRow(_ slots: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            labels(loc("Tegenstander fluit"), loc("Tik op de partijen die de tegenstander fluit en invult"))
            HStack(spacing: 8) {
                ForEach(TeamLiveCard.slotItems) { item in
                    refereeChip(item.slot, selected: slots.contains(item.slot))
                }
            }
        }
    }

    private func refereeChip(_ slot: Int, selected: Bool) -> some View {
        Button { onToggleReferee(slot) } label: {
            Text("E\(slot)")
                .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? SharedColors.background : SharedColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? SharedColors.accent : SharedColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}

/// "Volgen" for a live team match on this phone: the team stand on the lock
/// screen, a switch (the same follower as the button on the team page,
/// `LiveFollow`, without the link)
struct TeamLockScreenRow: View {
    let target: LiveFollowTarget

    @State private var busy = false
    @State private var problem: String? = nil

    private var following: Bool { LiveFollow.shared.isFollowing(target) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { following }, set: { on in
                Task {
                    if on { await start() } else { await stop() }
                }
            })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Volgen", bundle: textBundle)
                        .font(SharedFonts.system(16, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Text("De teamstand op je vergrendelscherm", bundle: textBundle)
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.textSecondary)
                }
            }
            .tint(SharedColors.accent)
            .disabled(busy)
            if let problem {
                Text(problem)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func start() async {
        busy = true
        problem = nil
        do {
            try await LiveFollow.shared.follow(target)
        } catch {
            problem = (error as? LiveFollowError)?.message ?? LiveFollowError.noConnection.message
        }
        busy = false
    }

    private func stop() async {
        busy = true
        problem = nil
        await LiveFollow.shared.unfollow(target)
        busy = false
    }
}

/// One of E1–E4 for a `ForEach` (no `indices`: Skip)
struct TeamSlotItem: Identifiable {
    let slot: Int
    var id: Int { slot }
}

/// The texts that go to the group app
enum TeamLiveTexts {
    static func viewers(_ match: TeamMatch, baseURL: String) -> String {
        guard let id = match.liveId else { return "" }
        let url = "\(baseURL)/t/\(id)"
        return loc("Volg \(match.title) live: \(url)")
    }

    static func invite(_ match: TeamMatch) -> String {
        guard let id = match.liveId, let key = match.liveKey else { return "" }
        let invite = TeamInvite(id: id, key: key)
        // TeamInvite.parse reads any word of this text that is a link or code,
        // so the sentences around them may be translated
        let link = invite.link
        let code = invite.code
        let newer = CardInbox.newerAppText
        return loc("Doe mee met onze teamwedstrijd \(match.title) in SquashAnalyzer en zet je eigen partij live: \(link)") + "\n"
            + loc("Of plak deze code in de app (Competitie, Deelnemen): \(code)") + "\n"
            // Someone on an older app sees nothing happen: say why (test, 7 October)
            + loc("Gebeurt er niets? \(newer)")
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
    /// Our own match for this evening that already has partijen: link or take over
    @State private var filledTwin: TeamMatch? = nil

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
                        Text("Een teamgenoot deelde een link of code van de live teamwedstrijd. Plak die hier; je partij komt dan op dezelfde livepagina.", bundle: textBundle)
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField(loc("Link of code"), text: $text)
                            .font(SharedFonts.system(14))
                            .foregroundColor(SharedColors.textPrimary)
                            .padding(10)
                            .background(SharedColors.tint(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        if state == nil {
                            ActionButton(busy ? loc("Even geduld…") : loc("Zoek teamwedstrijd"), style: .filled,
                                         disabled: busy || text.trimmingCharacters(in: .whitespaces).isEmpty) {
                                Task { await lookUp() }
                            }
                        }
                        if let state {
                            found(state)
                        }
                        if let message {
                            Text(message).font(SharedFonts.system(12)).foregroundColor(SharedColors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle(loc("Deelnemen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: loc("Annuleren"), action: onCancel)
                }
            }
            .task {
                if invite == nil, !text.isEmpty, TeamInvite.parse(text) != nil { await lookUp() }
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private func found(_ state: TeamLiveState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(loc("GEVONDEN"))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(state.team.home) – \(state.team.away)")
                    .font(SharedFonts.system(17, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(TeamMatchReport.dayText(Date(timeIntervalSince1970: Double(state.team.date) / 1000.0))) · \(state.partijen.count) van 4 partijen staan erop", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
            }
            Text("Welk team is van jou?", bundle: textBundle)
                .font(SharedFonts.system(13, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            HStack(spacing: 10) {
                sideButton(state.team.home, side: TeamSide.home)
                sideButton(state.team.away, side: TeamSide.away)
            }
            if let twin = filledTwin {
                Text("Je hebt deze teamwedstrijd al op je telefoon, met partijen die je zelf hebt ingevuld. Neem je de partijen van je teamgenoot over, dan gaan jouw ingevulde partijen verloren.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionButton(busy ? loc("Even geduld…") : loc("Partijen van mijn teamgenoot overnemen"), style: .filled, disabled: busy) {
                    Task { await takeOver(twin, state) }
                }
                ActionButton(loc("Annuleren"), style: .text, disabled: busy) {
                    filledTwin = nil
                }
            } else {
                ActionButton(busy ? loc("Even geduld…") : loc("Deelnemen"), style: .filled, disabled: busy) {
                    Task { await join(state) }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.tint(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sideButton(_ name: String, side: TeamSide) -> some View {
        let selected = ownSide == side
        return Button { ownSide = side } label: {
            Text(name)
                .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
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
            message = loc("Dit is geen geldige link of code van een teamwedstrijd.")
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
                ? loc("Deze teamwedstrijd is afgelopen of de link klopt niet.")
                : loc("Geen verbinding. Controleer het internet en probeer het opnieuw.")
        } catch {
            message = loc("Opzoeken lukte niet.")
        }
        busy = false
    }

    /// Kept: the Mijn team card reads the team matches again right away
    /// (on iOS the join sheet closes onto the home screen, 7 November 2026)
    private func finishJoin(_ match: TeamMatch) {
        TeamMatchSupport.noteChange()
        onJoined(match)
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
                message = loc("De code klopt niet: de teamwedstrijd is gevonden, maar de sleutel wordt niet geaccepteerd. Vraag je teamgenoot de uitnodiging opnieuw te sturen.")
            case TeamLiveError.gone:
                message = loc("Deze teamwedstrijd is afgelopen of de link klopt niet.")
            default:
                message = loc("Geen verbinding. Controleer het internet en probeer het opnieuw.")
            }
            return
        } catch {
            busy = false
            message = loc("Controleren van de code lukte niet.")
            return
        }
        do {
            let all = try await store.loadAll()
            // Joined before: that copy, with what the page has now
            for var existing in all where existing.liveId == invite.id {
                // Joined before: the side may have been chosen wrong; joining again sets it right
                if existing.ownSide != ownSide {
                    existing = TeamMatch.joining(fetched, invite: invite, ownSide: ownSide, id: existing.id,
                                                 ownerKey: existing.liveOwnerKey)
                }
                _ = existing.mergeLive(fetched)
                existing.adoptFixture(from: team?.fixtures ?? [])
                try await store.save(existing)
                busy = false
                finishJoin(existing)
                return
            }
            // The same evening made by hand here: no second copy
            switch TeamMatch.twin(of: fetched, in: all) {
            case TeamJoinTwin.empty(let own):
                var linked = own.linked(to: fetched, invite: invite)
                linked.adoptFixture(from: team?.fixtures ?? [])
                try await store.save(linked)
                busy = false
                finishJoin(linked)
                return
            case TeamJoinTwin.filled(let own):
                filledTwin = own
                busy = false
                return
            case TeamJoinTwin.sharedElsewhere:
                busy = false
                message = loc("Je hebt deze teamwedstrijd al, maar gekoppeld aan een andere livepagina. Stop die eerst of gebruik die.")
                return
            case TeamJoinTwin.none:
                break
            }
            var match = TeamMatch.joining(fetched, invite: invite, ownSide: ownSide)
            match.adoptFixture(from: team?.fixtures ?? [])
            try await store.save(match)
            busy = false
            finishJoin(match)
        } catch {
            busy = false
            message = loc("Deelnemen is niet gelukt.")
        }
    }

    private func takeOver(_ own: TeamMatch, _ fetched: TeamLiveState) async {
        guard let invite else { return }
        busy = true
        do {
            let taken = own.takingOver(fetched, invite: invite)
            try await store.save(taken)
            filledTwin = nil
            busy = false
            finishJoin(taken)
        } catch {
            busy = false
            message = loc("Overnemen is niet gelukt.")
        }
    }
}
