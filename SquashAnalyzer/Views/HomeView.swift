import SwiftUI

/// Which live-scoring mode a match starts in
enum SetupMode: Equatable {
    case coach, referee
}

// MARK: - Home screen

/// The app's starting point: the "Mijn team" card, then one tile per thing you
/// can do (start coaching, start refereeing, browse finished matches, manage
/// players). Coach and Scheidsrechter open `MatchStartView` to pick players and
/// begin; the other two tiles go straight to their own screen.
struct HomeView: View {
    let match: Match
    @Binding var isPresented: Bool
    var onViewHistory: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil

    @State private var startMode: SetupMode? = nil
    @State private var showingPlayerManagement = false
    @State private var createdRefereeMatch: RefereeMatch? = nil

    var body: some View {
        ZStack {
            homeContent

            if let startMode {
                MatchStartView(mode: startMode, match: match, isPresented: $isPresented) {
                    withAnimation(.easeInOut(duration: 0.2)) { self.startMode = nil }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: startMode)
        .sheet(isPresented: $showingPlayerManagement) {
            PlayerManagementView()
        }
        .fullScreenCover(item: $createdRefereeMatch) { m in
            RefereeView(match: m) { createdRefereeMatch = nil }
        }
        #if DEBUG
        .onAppear {
            // .setup lands on MatchStartView itself (see there); .referee jumps
            // straight past the tiles into a live referee screen for its screenshot
            if ScreenshotScenario.current == .referee {
                createdRefereeMatch = ScreenshotScenario.makeRefereeMatch()
            } else if ScreenshotScenario.current == .setup {
                startMode = .coach
            }
        }
        #endif
    }

    private var homeContent: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 20) {
                        LeagueTeamCard()

                        tileGrid
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private var header: some View {
        HStack {
            Color.clear.frame(width: 22, height: 22)

            Spacer()

            Text("SQUASH ANALYZER")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            if let onOpenSettings {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 21))
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel("Instellingen")
            } else {
                Color.clear.frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // ── Tiles ────────────────────────────────────────────────────────────────

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
            HomeTile(title: "Coach", icon: "chart.bar.xaxis", color: AppColors.warmOrange) {
                withAnimation(.easeInOut(duration: 0.2)) { startMode = .coach }
            }
            HomeTile(title: "Scheidsrechter", icon: "hand.raised.fill", color: AppColors.warmOrange) {
                withAnimation(.easeInOut(duration: 0.2)) { startMode = .referee }
            }
            HomeTile(title: "Afgeronde wedstrijden", icon: "clock.arrow.circlepath", color: AppColors.steelBlue) {
                onViewHistory?()
            }
            HomeTile(title: "Spelers", icon: "person.2.fill", color: AppColors.accentGold) {
                showingPlayerManagement = true
            }
        }
        .padding(.horizontal, 24)
    }
}

/// One flat, tinted tile on the home screen
private struct HomeTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(color)
                Text(title.uppercased())
                    .font(AppFonts.label(13))
                    .tracking(1)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Match start (players, server, later instappen)

/// Picking players and the starting server for one mode, chosen on the home
/// screen. Coach and Scheidsrechter share this screen; only what happens on
/// "Start" differs.
struct MatchStartView: View {
    let mode: SetupMode
    let match: Match
    @Binding var isPresented: Bool
    var onBack: () -> Void

    @State private var player1Name: String = ""
    @State private var player2Name: String = ""
    @State private var startingServer: Player = .player1
    @State private var player1GamesBefore: Int = 0
    @State private var player2GamesBefore: Int = 0

    @State private var player1CoachingFocus: [String] = []
    @State private var player1CoachingNotes: String = ""
    @State private var player2CoachingFocus: [String] = []
    @State private var player2CoachingNotes: String = ""

    /// Players picked from "Kies speler"; they only count while the name is unchanged
    @State private var player1Pick: PickedPlayer? = nil
    @State private var player2Pick: PickedPlayer? = nil

    @State private var showingPlayer1Picker = false
    @State private var showingPlayer2Picker = false
    @State private var showingPlayerManagement = false
    @State private var createdRefereeMatch: RefereeMatch? = nil

    private var title: String {
        mode == .coach ? "COACH" : "SCHEIDSRECHTER"
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────────
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Home")
                        }
                        .font(AppFonts.body(14))
                        .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(title)
                        .font(AppFonts.title(18))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Button(action: { showingPlayerManagement = true }) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accentGold)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Spacer()

                // ── Player names ────────────────────────────────────────────
                VStack(spacing: 20) {
                    PlayerNameInputWithPicker(
                        title: "Speler 1",
                        name: $player1Name,
                        coachingFocus: mode == .coach ? player1CoachingFocus : [],
                        color: AppColors.warmOrange,
                        placeholder: "Naam speler 1",
                        onPickPlayer: { showingPlayer1Picker = true }
                    )
                    PlayerNameInputWithPicker(
                        title: "Speler 2",
                        name: $player2Name,
                        coachingFocus: mode == .coach ? player2CoachingFocus : [],
                        color: AppColors.steelBlue,
                        placeholder: "Naam speler 2",
                        onPickPlayer: { showingPlayer2Picker = true }
                    )
                }
                .padding(.horizontal, 24)

                // ── First server ─────────────────────────────────────────────
                VStack(spacing: 12) {
                    Text("Wie serveert eerst?")
                        .font(AppFonts.label(14))
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 16) {
                        ServerSelectionButton(
                            name: player1Name.isEmpty ? "Speler 1" : player1Name,
                            color: AppColors.warmOrange,
                            isSelected: startingServer == .player1
                        ) { startingServer = .player1 }

                        ServerSelectionButton(
                            name: player2Name.isEmpty ? "Speler 2" : player2Name,
                            color: AppColors.steelBlue,
                            isSelected: startingServer == .player2
                        ) { startingServer = .player2 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // ── Later instappen (start at game 2–5 with the stand so far) ──
                HeadStartPicker(
                    player1Games: $player1GamesBefore,
                    player2Games: $player2GamesBefore,
                    player1Name: player1Name.isEmpty ? "Speler 1" : player1Name,
                    player2Name: player2Name.isEmpty ? "Speler 2" : player2Name
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // ── Start button ─────────────────────────────────────────────
                if mode == .coach {
                    HardwareButton(
                        title: "Start Wedstrijd",
                        subtitle: nil,
                        color: AppColors.warmOrange,
                        colorDark: AppColors.warmOrangeDark
                    ) {
                        startMatch()
                    }
                    .padding(.horizontal, 24)
                } else {
                    HardwareButton(
                        title: "Start Scheidsrechter",
                        subtitle: nil,
                        color: AppColors.warmOrange,
                        colorDark: AppColors.warmOrangeDark
                    ) {
                        startReferee()
                    }
                    .padding(.horizontal, 24)
                }

                Spacer().frame(height: 28)
            }
        }
        .sheet(isPresented: $showingPlayer1Picker) {
            PlayerManagementView { player in
                player1Pick = PickedPlayer(id: player.id, name: player.name)
                player1Name = player.name
                player1CoachingFocus = player.coachingFocusAreas
                player1CoachingNotes = player.coachingNotes
            }
        }
        .sheet(isPresented: $showingPlayer2Picker) {
            PlayerManagementView { player in
                player2Pick = PickedPlayer(id: player.id, name: player.name)
                player2Name = player.name
                player2CoachingFocus = player.coachingFocusAreas
                player2CoachingNotes = player.coachingNotes
            }
        }
        .sheet(isPresented: $showingPlayerManagement) {
            PlayerManagementView()
        }
        .fullScreenCover(item: $createdRefereeMatch) { m in
            RefereeView(match: m) { createdRefereeMatch = nil }
        }
        #if DEBUG
        .onAppear {
            guard ScreenshotScenario.current == .setup, mode == .coach else { return }
            player1Name = ScreenshotScenario.player1
            player2Name = ScreenshotScenario.player2
        }
        #endif
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    private func startMatch() {
        match.setupMatch(
            player1: player1Name,
            player2: player2Name,
            startingServer: startingServer,
            player1CoachingFocus: player1CoachingFocus,
            player1CoachingNotes: player1CoachingNotes,
            player2CoachingFocus: player2CoachingFocus,
            player2CoachingNotes: player2CoachingNotes,
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore,
            player1Id: player1Pick?.id(for: player1Name),
            player2Id: player2Pick?.id(for: player2Name)
        )
        isPresented = false
    }

    private func startReferee() {
        let p1 = player1Name.trimmingCharacters(in: .whitespaces)
        let p2 = player2Name.trimmingCharacters(in: .whitespaces)
        createdRefereeMatch = RefereeMatch(
            player1Name: p1.isEmpty ? "Speler 1" : p1,
            player2Name: p2.isEmpty ? "Speler 2" : p2,
            bestOf: 5,
            startingServer: startingServer,
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore
        )
        createdRefereeMatch?.player1Id = player1Pick?.id(for: player1Name)
        createdRefereeMatch?.player2Id = player2Pick?.id(for: player2Name)
    }
}

/// A player chosen in "Kies speler". Editing the name afterwards makes it a
/// typed-in player again, which earns no badges.
struct PickedPlayer: Equatable {
    let id: UUID
    let name: String

    func id(for currentName: String) -> UUID? {
        currentName.trimmingCharacters(in: .whitespaces) == name.trimmingCharacters(in: .whitespaces) ? id : nil
    }
}

// MARK: - Head start picker ("Later instappen")

/// Collapsed: one muted line. Expanded: a games-won stepper per player, so a
/// match can be picked up at game 2–5 with the stand so far. Neither player can
/// already have the games needed to win.
struct HeadStartPicker: View {
    @Binding var player1Games: Int
    @Binding var player2Games: Int
    let player1Name: String
    let player2Name: String
    var bestOf: Int = 5

    @State private var expanded = false

    private var maxPerPlayer: Int { (bestOf / 2) }          // 2 for best of 5
    private var firstGame: Int { 1 + player1Games + player2Games }
    private var hasHeadStart: Bool { firstGame > 1 }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "forward.end")
                        .font(.system(size: 11, weight: .semibold))
                    Text(summaryText)
                        .font(AppFonts.caption(12))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(hasHeadStart ? AppColors.accentGold : AppColors.textMuted)
            }
            .buttonStyle(.plain)

            if expanded {
                HStack(spacing: 16) {
                    stepper(name: player1Name, value: $player1Games, color: AppColors.warmOrange)
                    stepper(name: player2Name, value: $player2Games, color: AppColors.steelBlue)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// "Later instappen" until a stand is set, then "Start bij game 3 · stand 1 – 1"
    private var summaryText: String {
        hasHeadStart ? "Start bij game \(firstGame) · stand \(player1Games) – \(player2Games)" : "Later instappen?"
    }

    private func stepper(name: String, value: Binding<Int>, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(AppFonts.caption(11))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 14) {
                stepButton("minus", color: color, enabled: value.wrappedValue > 0) { value.wrappedValue -= 1 }
                Text("\(value.wrappedValue)")
                    .font(AppFonts.score(22))
                    .foregroundColor(value.wrappedValue > 0 ? color : AppColors.textSecondary)
                    .frame(minWidth: 22)
                    .contentTransition(.numericText())
                stepButton("plus", color: color, enabled: value.wrappedValue < maxPerPlayer) { value.wrappedValue += 1 }
            }

            Text("GAMES GEWONNEN")
                .font(AppFonts.caption(8))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func stepButton(_ icon: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(enabled ? color : AppColors.textMuted.opacity(0.5))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(color.opacity(enabled ? 0.12 : 0.03))
                        .overlay(Circle().stroke(color.opacity(enabled ? 0.35 : 0.1), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Player Name Input with Picker
struct PlayerNameInputWithPicker: View {
    let title: String
    @Binding var name: String
    let coachingFocus: [String]
    let color: Color
    let placeholder: String
    let onPickPlayer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(AppFonts.caption(11))
                    .foregroundColor(color)
                    .tracking(1)
                Spacer()
                Button(action: onPickPlayer) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 12))
                        Text("Kies speler")
                            .font(AppFonts.caption(11))
                    }
                    .foregroundColor(AppColors.accentGold)
                }
            }

            HStack(spacing: 0) {
                TextField(placeholder, text: $name)
                    .font(AppFonts.body(16))
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )

            // Show selected coaching focus tags
            if !coachingFocus.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(coachingFocus, id: \.self) { tag in
                            Text(tag)
                                .font(AppFonts.caption(10))
                                .foregroundColor(color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(color.opacity(0.15)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Server Selection Button
struct ServerSelectionButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? color : AppColors.textMuted)

                Text(name)
                    .font(AppFonts.label(13))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
