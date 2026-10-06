import SwiftUI
import SquashAnalyzerCore

// The editor of one partij of a team match (players, games, linking to a tracked match).

// MARK: - Partij invullen of koppelen

struct TeamPartijEditor: View {
    @State private var partij: TeamPartij
    let match: TeamMatch
    let roster: [String]
    let historyStore: any MatchHistoryStore
    let onSave: (TeamPartij) -> Void
    /// A new tracked match for this partij: the partij as edited and "coach" or "referee"
    let onTrack: (TeamPartij, String) -> Void
    let onCancel: () -> Void

    @State private var ownText = ""
    @State private var theirText = ""
    @State private var scoreError: String? = nil
    /// The game in progress when a player gave up (optional)
    @State private var stoppedOwnText = ""
    @State private var stoppedTheirText = ""
    @State private var endError: String? = nil
    @State private var choosingMatch = false
    @State private var history: [MatchHistorySummary] = []
    @State private var historyLoaded = false
    /// A tracked match chosen; which of its players is ours is asked next
    @State private var chosen: MatchHistorySummary? = nil

    init(partij: TeamPartij, match: TeamMatch, roster: [String], historyStore: any MatchHistoryStore,
         onSave: @escaping (TeamPartij) -> Void, onTrack: @escaping (TeamPartij, String) -> Void,
         onCancel: @escaping () -> Void) {
        _partij = State(initialValue: partij)
        self.match = match
        self.roster = roster
        self.historyStore = historyStore
        self.onSave = onSave
        self.onTrack = onTrack
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        playersSection
                        linkSection
                        gamesSection
                        endingSection
                        orderSection
                    }
                    .padding(24)
                }
            }
            .pageTitle("Partij \(partij.label)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") { onSave(partij) }.fontWeight(.bold).foregroundColor(SharedColors.accent)
                }
            }
            .sheet(isPresented: $choosingMatch) {
                TrackedMatchPicker(entries: history, loaded: historyLoaded, matchDate: match.date,
                                   homeIsOurs: match.ownSide == TeamSide.home) { summary in
                    choosingMatch = false
                    chosen = summary
                } onNew: { kind in
                    choosingMatch = false
                    onTrack(partij, kind)
                } onCancel: { choosingMatch = false }
            }
            .alert("Wie is onze speler?", isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } })) {
                if let chosen {
                    Button(chosen.player1Name) { link(chosen, ownIsPlayer1: true) }
                    Button(chosen.player2Name) { link(chosen, ownIsPlayer1: false) }
                }
                Button("Annuleer", role: .cancel) { chosen = nil }
            } message: {
                Text("De games komen uit die wedstrijd, gezien vanuit onze speler.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var playersSection: some View {
        section("SPELERS") {
            field(match.defaultOwnName(partij.slot), text: $partij.ownPlayer)
            if !roster.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(roster, id: \.self) { name in
                            Button { partij.ownPlayer = name } label: {
                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(partij.ownPlayer == name ? SharedColors.background : SharedColors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(partij.ownPlayer == name ? SharedColors.accent : SharedColors.accent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 999))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 2)
            }
            field(match.defaultOpponentName(partij.slot), text: $partij.opponentPlayer)
                .padding(.top, 8)
        }
    }

    private var linkSection: some View {
        section("BIJGEHOUDEN WEDSTRIJD") {
            if partij.isLinked {
                Text("Gekoppeld aan een \(partij.linkedKind == "referee" ? "scheidsrechter" : "coach")wedstrijd uit Afgeronde wedstrijden.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ActionButton("Vernieuwen", icon: "arrow.counterclockwise") { Task { await refreshLink() } }
                    ActionButton("Ontkoppel", color: SharedColors.textSecondary) { partij.unlink() }
                }
                .padding(.top, 8)
            } else {
                Text("Hield je deze partij bij als coach of scheidsrechter? Dan komen de games vanzelf mee.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionButton("Kies wedstrijd", icon: "arrow.right") {
                    choosingMatch = true
                    Task { await loadHistory() }
                }
                .padding(.top, 8)
            }
        }
    }

    private var gamesSection: some View {
        section("GAMES") {
            if partij.games.isEmpty {
                Text("Nog geen games.").font(.system(size: 12)).foregroundColor(SharedColors.textMuted)
            } else {
                ForEach(0..<partij.games.count, id: \.self) { index in
                    let game = partij.games[index]
                    HStack {
                        Text("Game \(index + 1)").font(.system(size: 13)).foregroundColor(SharedColors.textSecondary)
                        Spacer()
                        Text(game.text)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(game.ownWon ? SharedColors.accent : SharedColors.steelBlueLight)
                        Text(game.ownWon ? "wij" : "zij")
                            .font(.system(size: 11))
                            .foregroundColor(SharedColors.textMuted)
                            .frame(width: 26, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    Text("Stand \(partij.standText)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(partij.isOver ? SharedColors.gold : SharedColors.textPrimary)
                    Spacer()
                    Button("Laatste game wissen") { partij.removeLastGame() }
                        .font(.system(size: 12))
                        .foregroundColor(SharedColors.textSecondary)
                }
                .padding(.top, 4)
            }
            if partij.canAddGame {
                Divider().overlay(Color.white.opacity(0.09)).padding(.vertical, 6)
                Text("Game \(partij.games.count + 1) toevoegen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                HStack(spacing: 10) {
                    scoreField("wij", text: $ownText)
                    Text("–").foregroundColor(SharedColors.textMuted)
                    scoreField("zij", text: $theirText)
                    ActionButton("Voeg toe", style: .filled) { addScoredGame() }
                }
                if let scoreError {
                    Text(scoreError).font(.system(size: 11)).foregroundColor(SharedColors.error)
                }
                Text("Stand niet bekend? Dan alleen wie won:")
                    .font(.system(size: 11))
                    .foregroundColor(SharedColors.textMuted)
                    .padding(.top, 4)
                HStack(spacing: 10) {
                    winnerButton("Wij wonnen", own: true, color: SharedColors.accent)
                    winnerButton("Zij wonnen", own: false, color: SharedColors.steelBlueLight)
                }
            } else if partij.isOver {
                Text("Partij beslist.").font(.system(size: 12)).foregroundColor(SharedColors.textMuted).padding(.top, 4)
            }
        }
    }

    /// Opgave or niet verschenen: the rest of the partij goes to the opponent
    @ViewBuilder
    private var endingSection: some View {
        if partij.endedBy != nil || (!partij.isOver && partij.games.count < partij.bestOf) {
            section("OPGAVE OF NIET VERSCHENEN") {
                if let text = partij.endText {
                    let winner = partij.ownWon == true ? "Wij winnen" : "Zij winnen"
                    Text("\(winner) deze partij door \(text == "opgave" ? "de opgave van de tegenstander" : "het wegblijven van de tegenstander"): alle resterende punten gaan naar de winnaar.")
                        .font(.system(size: 12))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ActionButton("Maak ongedaan", color: SharedColors.textSecondary) {
                        partij.clearEnd()
                        endError = nil
                    }
                    .padding(.top, 6)
                } else {
                    Text("Geeft een speler op, dan gaan alle resterende punten naar de tegenstander. Kwam een speler niet opdagen, dan wint de ander met 3 keer 11-0.")
                        .font(.system(size: 12))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Opgave: stand van de game waarin het gebeurde (optioneel)")
                        .font(.system(size: 11))
                        .foregroundColor(SharedColors.textMuted)
                        .padding(.top, 4)
                    HStack(spacing: 10) {
                        scoreField("wij", text: $stoppedOwnText)
                        Text("–").foregroundColor(SharedColors.textMuted)
                        scoreField("zij", text: $stoppedTheirText)
                    }
                    HStack(spacing: 10) {
                        endButton("Onze speler geeft op", color: SharedColors.accent) { giveUp(ownGivesUp: true) }
                        endButton("Hun speler geeft op", color: SharedColors.steelBlueLight) { giveUp(ownGivesUp: false) }
                    }
                    if partij.games.isEmpty {
                        HStack(spacing: 10) {
                            endButton("Onze speler kwam niet", color: SharedColors.accent) { endWalkover(ownWins: false) }
                            endButton("Hun speler kwam niet", color: SharedColors.steelBlueLight) { endWalkover(ownWins: true) }
                        }
                    }
                }
                if let endError {
                    Text(endError).font(.system(size: 11)).foregroundColor(SharedColors.error)
                }
            }
        }
    }

    private func endButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func giveUp(ownGivesUp: Bool) {
        let ownTrimmed = stoppedOwnText.trimmingCharacters(in: .whitespaces)
        let theirTrimmed = stoppedTheirText.trimmingCharacters(in: .whitespaces)
        var own: Int? = nil
        var their: Int? = nil
        if !ownTrimmed.isEmpty || !theirTrimmed.isEmpty {
            guard let a = Int(ownTrimmed), let b = Int(theirTrimmed), a >= 0, b >= 0 else {
                endError = "Vul beide punten in, bijvoorbeeld 7 en 9, of laat ze allebei leeg."
                return
            }
            own = a
            their = b
        }
        if partij.giveUp(ownGivesUp: ownGivesUp, currentOwn: own, currentTheir: their) {
            endError = nil
            stoppedOwnText = ""
            stoppedTheirText = ""
        } else {
            endError = "Dat kan niet bij deze partij."
        }
    }

    private func endWalkover(ownWins: Bool) {
        endError = partij.walkover(ownWins: ownWins) ? nil : "Dat kan alleen bij een partij zonder games."
    }

    private var orderSection: some View {
        section("SPEELVOLGORDE (OPTIONEEL)") {
            HStack(spacing: 8) {
                ForEach(1..<5, id: \.self) { order in
                    Button { partij.playOrder = partij.playOrder == order ? nil : order } label: {
                        Text("\(order)e")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(partij.playOrder == order ? SharedColors.background : SharedColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(partij.playOrder == order ? SharedColors.accent : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(SharedColors.accent)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14))
            .foregroundColor(SharedColors.textPrimary)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }

    private func scoreField(_ placeholder: String, text: Binding<String>) -> some View {
        let field = TextField(placeholder, text: text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(SharedColors.textPrimary)
            .multilineTextAlignment(.center)
        #if os(iOS) || SKIP
        return field
            .keyboardType(.numberPad)
            .lineLimit(1)
            .padding(8)
            .frame(width: 76)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        #else
        return field
            .lineLimit(1)
            .padding(8)
            .frame(width: 76)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        #endif
    }

    private func winnerButton(_ title: String, own: Bool, color: Color) -> some View {
        Button {
            _ = partij.addGame(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: own))
            scoreError = nil
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func addScoredGame() {
        guard let own = Int(ownText.trimmingCharacters(in: .whitespaces)),
              let their = Int(theirText.trimmingCharacters(in: .whitespaces)) else {
            scoreError = "Vul beide standen in, bijvoorbeeld 11 en 8."
            return
        }
        guard TeamGame.isValidScore(own, their) else {
            scoreError = "Geen squashstand: tot 11 met twee punten verschil (11-9, 12-10, 15-13)."
            return
        }
        if partij.addGame(TeamGame(own: own, their: their)) {
            ownText = ""
            theirText = ""
            scoreError = nil
        }
    }

    private func loadHistory() async {
        guard !historyLoaded else { return }
        if let entries = try? await historyStore.loadHistory() {
            history = entries
        }
        historyLoaded = true
    }

    private func link(_ summary: MatchHistorySummary, ownIsPlayer1: Bool) {
        partij.link(summary, ownIsPlayer1: ownIsPlayer1)
        chosen = nil
        scoreError = nil
    }

    /// Reads the linked match again, e.g. after its result was completed
    private func refreshLink() async {
        guard let id = partij.linkedMatchId else { return }
        historyLoaded = false
        await loadHistory()
        for entry in history where entry.id == id {
            partij.refreshLink(from: entry)
        }
    }
}

/// Coach and referee matches on this phone, the ones of the match day on top
struct TrackedMatchPicker: View {
    let entries: [MatchHistorySummary]
    let loaded: Bool
    let matchDate: Date
    /// Our team plays at home: our player starts as Speler 1
    let homeIsOurs: Bool
    let onPick: (MatchHistorySummary) -> Void
    /// "coach" or "referee": a new match to track for this partij
    let onNew: (String) -> Void
    let onCancel: () -> Void

    private var sorted: [MatchHistorySummary] {
        let calendar = Calendar.current
        let sameDay = entries.filter { entry in calendar.isDate(entry.updatedAt, inSameDayAs: matchDate) }
        let others = entries.filter { entry in !calendar.isDate(entry.updatedAt, inSameDayAs: matchDate) }
        return sameDay + others
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NIEUWE WEDSTRIJD BIJHOUDEN")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(SharedColors.accent)
                        HStack(spacing: 10) {
                            ActionButton("Coach") { onNew("coach") }
                            ActionButton("Scheidsrechter") { onNew("referee") }
                        }
                        Text(homeIsOurs ? "Wij spelen thuis: onze speler start als Speler 1." : "Wij spelen uit: onze speler start als Speler 2.")
                            .font(.system(size: 11))
                            .foregroundColor(SharedColors.textMuted)
                        Text("OF EEN BIJGEHOUDEN WEDSTRIJD")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(SharedColors.accent)
                            .padding(.top, 10)
                        if !loaded {
                            ProgressView().frame(maxWidth: .infinity)
                        } else if entries.isEmpty {
                            Text("Nog geen bijgehouden wedstrijden.").font(.system(size: 13)).foregroundColor(SharedColors.textMuted)
                        } else {
                            Text("Wedstrijden van de speeldag staan bovenaan.")
                                .font(.system(size: 12))
                                .foregroundColor(SharedColors.textMuted)
                            ForEach(sorted) { entry in
                                Button { onPick(entry) } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(entry.player1Name) – \(entry.player2Name)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(SharedColors.textPrimary)
                                                .lineLimit(1)
                                            Text("\(TeamMatchReport.dayText(entry.updatedAt)) · \(entry.kind == "referee" ? "scheidsrechter" : "coach") · \(entry.player1Games)-\(entry.player2Games)" + (entry.status == "abandoned" ? " · incompleet" : ""))
                                                .font(.system(size: 11))
                                                .foregroundColor(SharedColors.textSecondary)
                                        }
                                        Spacer()
                                        AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle("Kies wedstrijd")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer", action: onCancel).foregroundColor(SharedColors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
