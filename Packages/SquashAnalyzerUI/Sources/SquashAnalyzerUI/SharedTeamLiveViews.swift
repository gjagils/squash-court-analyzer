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
    /// 4.0, owner of a team-only live team match: the partijen the opponent referees now (nil: unknown)
    var refereeSlots: [Int]? = nil
    /// 4.0: Live delen on a team-only live team match (club screen and viewers' link)
    var onGoPublic: () -> Void = {}
    /// 4.0: the invitation of a team-only live team match, for teammates without an account or on an older app
    var onInvite: () -> Void = {}
    /// 4.0, owner: a partij moves between "wij fluiten" and "tegenstander fluit"
    var onToggleReferee: (Int) -> Void = { _ in }
    /// "Deel met mijn team" on a team match that is not shared yet
    let onGoLive: () -> Void
    /// Opens the share screen (viewers' link and invitation)
    let onShare: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionHeader(loc("DELEN"))
                if match.isTeamOnly {
                    Text(loc("TEAM"))
                        .font(SharedFonts.system(10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(SharedColors.background)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(SharedColors.support)
                        .clipShape(Capsule())
                } else if match.isLive {
                    HStack(spacing: 5) {
                        Circle().fill(Color.white).frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(SharedFonts.system(10, weight: .bold, design: .rounded))
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
            if match.isOpponentCopy {
                Text("Je ziet alle partijen van deze teamwedstrijd. De partijen die jullie fluiten zet je erop door ze bij te houden of in te vullen.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let problem {
                    Text(problem)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    ActionButton(loc("Vernieuwen"), icon: "arrow.counterclockwise", disabled: busy, action: onRefresh)
                    ActionButton(loc("Live verlaten"), color: SharedColors.textSecondary, disabled: busy, action: onStop)
                }
            } else if match.isTeamOnly {
                Text("Je team en de tegenstander zien deze teamwedstrijd in de app. Niet op het clubscherm en zonder kijkerslink, tot je Live delen aanzet.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Found only with 4.0 and an account: everyone else needs the invitation
                Text("Teamgenoten zonder account of met een oudere app doen mee met de uitnodiging.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if canShare {
                    ActionButton(loc("Nodig teamleden uit"), icon: "square.and.arrow.up", disabled: busy, action: onInvite)
                }
                if let id = match.liveId, let key = match.liveKey {
                    Text("Code om mee te doen: \(TeamInvite(id: id, key: key).code)", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if match.isLiveOwner {
                    ActionButton(busy ? loc("Even geduld…") : loc("Live delen"), style: .filled, disabled: busy, action: onGoPublic)
                    if let refereeSlots {
                        refereeRow(refereeSlots)
                    }
                }
                if let problem {
                    Text(problem)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    ActionButton(loc("Vernieuwen"), icon: "arrow.counterclockwise", disabled: busy, action: onRefresh)
                    ActionButton(match.isLiveOwner ? loc("Live stoppen") : loc("Live verlaten"), color: SharedColors.textSecondary,
                                 disabled: busy, action: onStop)
                }
            } else if match.isLive {
                Text("Kijkers volgen de hele teamavond op één pagina. Teamgenoten die de uitnodiging openen, zetten hun eigen partij erop. 2 uur na de laatste update wordt alles gewist.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // The share screen also shows the code (readable when nothing can be shared)
                ActionButton(loc("Deel met team en supporters"), icon: canShare ? "square.and.arrow.up" : nil, style: .filled, disabled: busy, action: onShare)
                if let problem {
                    Text(problem)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    ActionButton(loc("Vernieuwen"), icon: "arrow.counterclockwise", disabled: busy, action: onRefresh)
                    // Only the phone that started the live page can end it for everyone
                    ActionButton(match.isLiveOwner ? loc("Live stoppen") : loc("Live verlaten"), color: SharedColors.textSecondary,
                                 disabled: busy, action: onStop)
                }
            } else {
                Text("Deel deze teamwedstrijd met je team: teamgenoten zetten hun eigen partij erop en supporters volgen de stand van de hele avond, per partij ook punt voor punt. Alleen teamnamen, voornamen en de stand gaan mee.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionButton(busy ? loc("Even geduld…") : loc("Deel met mijn team"), style: .filled, disabled: busy, action: onGoLive)
            }
            // Whoever takes part gets plain notifications by itself; the card
            // on the lock screen is a choice, here (a team-only match has no viewers' link to follow)
            if let liveId = match.liveId, match.isLive, !match.isComplete, LiveFollow.shared.presenter != nil {
                TeamLockScreenRow(target: LiveFollowTarget(id: liveId, server: TeamLive.shared.baseURL, kind: "team"))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.tint(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// "Tegenstander fluit": E1–E4, a tap moves a partij between us and them
    private func refereeRow(_ slots: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tegenstander fluit en vult in:", bundle: textBundle)
                .font(SharedFonts.system(12, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
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
                .padding(.vertical, 8)
                .background(selected ? SharedColors.accent : SharedColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    static let slotItems: [TeamSlotItem] = [TeamSlotItem(slot: 1), TeamSlotItem(slot: 2), TeamSlotItem(slot: 3), TeamSlotItem(slot: 4)]

    /// "E2, E3"
    static func labels(_ slots: [Int]) -> String {
        var parts: [String] = []
        for slot in slots.sorted() { parts.append("E\(slot)") }
        return parts.joined(separator: ", ")
    }
}

/// "Volg op vergrendelscherm" for a live team match on this phone: the same
/// follower as the button on the team page (`LiveFollow`), without the link
struct TeamLockScreenRow: View {
    let target: LiveFollowTarget

    @State private var busy = false
    @State private var problem: String? = nil

    private var following: Bool { LiveFollow.shared.isFollowing(target) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if following {
                Text("Deze teamwedstrijd staat op je vergrendelscherm en gaat na elke rally mee.", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionButton(loc("Stoppen met volgen"), color: SharedColors.textSecondary, disabled: busy) {
                    Task { await stop() }
                }
            } else {
                ActionButton(busy ? loc("Even geduld…") : loc("Volg op vergrendelscherm"), disabled: busy) {
                    Task { await start() }
                }
            }
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
