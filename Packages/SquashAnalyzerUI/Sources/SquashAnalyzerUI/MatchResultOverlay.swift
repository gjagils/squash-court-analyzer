import SwiftUI
import Foundation
import SquashAnalyzerCore

// MatchResult, ResultGame and ResultCaptionLine (what the card shows) live in
// SquashAnalyzerCore/MatchResult.swift, where they are tested.

// MARK: - Buttons

/// A button on the result card
public struct ResultButton {
    public let title: String
    public let icon: String?
    public let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

// MARK: - The card

/// Dimmed scrim with the flat referee-style result card: title, the two
/// players with their score, the winner line, game chips, captions, earned
/// badges, then the buttons (an optional row of two gold ones, the main one,
/// an outlined one, "Undo laatste punt" and a small text link).
public struct MatchResultOverlay: View {
    let result: MatchResult
    let player1Photo: Data?
    let player2Photo: Data?
    let badgeEarnings: [MatchBadgeEarning]
    let onBadges: (() -> Void)?
    let secondary: [ResultButton]
    let primary: ResultButton
    let outlined: ResultButton?
    let onUndo: (() -> Void)?
    let link: ResultButton?

    public init(result: MatchResult, player1Photo: Data? = nil, player2Photo: Data? = nil,
                badgeEarnings: [MatchBadgeEarning] = [], onBadges: (() -> Void)? = nil,
                secondary: [ResultButton] = [], primary: ResultButton, outlined: ResultButton? = nil,
                onUndo: (() -> Void)? = nil, link: ResultButton? = nil) {
        self.result = result
        self.player1Photo = player1Photo
        self.player2Photo = player2Photo
        self.badgeEarnings = badgeEarnings
        self.onBadges = onBadges
        self.secondary = secondary
        self.primary = primary
        self.outlined = outlined
        self.onUndo = onUndo
        self.link = link
    }

    static func color(for player: Player) -> Color {
        player == Player.player1 ? SharedColors.accent : SharedColors.steelBlue
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            ScrollView {
                card
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 22) {
            Text(result.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .tracking(3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 4) {
                side(Player.player1, name: result.player1Name, score: result.player1Score, photo: player1Photo)
                Text("–")
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                    .padding(.bottom, 14)
                side(Player.player2, name: result.player2Name, score: result.player2Score, photo: player2Photo)
            }
            // One sentence instead of four loose pieces ("Jan", "3", "–", "Piet", "1")
            .readAsOne("\(result.player1Name) \(result.player1Score), \(result.player2Name) \(result.player2Score)")

            if let winner = result.winner, let text = result.winnerText {
                Text(text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Self.color(for: winner))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 10) {
                if result.showsChips {
                    chips
                }
                ForEach(result.captions) { line in
                    caption(line)
                }
                if let note = result.savedNote {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(note)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.textMuted)
                    }
                }
            }

            if !badgeEarnings.isEmpty {
                MatchBadgesRow(earnings: badgeEarnings) { onBadges?() }
            }

            VStack(spacing: 12) {
                if !secondary.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(0..<secondary.count, id: \.self) { index in
                            goldButton(secondary[index])
                        }
                    }
                }
                filledButton(primary)
                if let outlined {
                    outlinedButton(outlined)
                }
                if let onUndo {
                    undoButton(onUndo)
                }
                if let link {
                    Button(action: link.action) {
                        Text(link.title)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(SharedColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(result.winner.map { Self.color(for: $0).opacity(0.35) } ?? Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func side(_ player: Player, name: String, score: Int, photo: Data?) -> some View {
        let color = Self.color(for: player)
        let won = result.winner == nil || result.winner == player
        return VStack(spacing: 6) {
            PlayerAvatarPlaceholder(color: color, size: 44, active: won, photo: photo)
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(won ? color : SharedColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(score)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(won ? color : SharedColors.textPrimary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(0..<result.untracked, id: \.self) { index in
                chip(number: index + 1, score: "–", color: SharedColors.textMuted)
            }
            ForEach(result.games) { game in
                chip(number: game.number, score: "\(game.player1Score)-\(game.player2Score)", color: Self.color(for: game.winner))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func chip(number: Int, score: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("G\(number)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(color.opacity(0.7))
                .tracking(1)
            Text(score)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
    }

    private func caption(_ line: ResultCaptionLine) -> some View {
        HStack(spacing: 5) {
            if line.showsTimer {
                AppSymbol("timer", size: 11, color: SharedColors.gold.opacity(0.6))
            }
            Text(line.text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func filledButton(_ button: ResultButton) -> some View {
        ActionButton(button.title.uppercased(), style: .filled, action: button.action)
    }

    private func outlinedButton(_ button: ResultButton) -> some View {
        ActionButton(button.title.uppercased(), color: SharedColors.textSecondary, action: button.action)
    }

    /// Outlined gold button with an icon; two of them share a row
    private func goldButton(_ button: ResultButton) -> some View {
        ActionButton(button.title.uppercased(), icon: button.icon, color: SharedColors.gold, action: button.action)
    }

    /// "Undo laatste punt", so a mis-tap on the final point can still be corrected
    private func undoButton(_ action: @escaping () -> Void) -> some View {
        ActionButton("Undo laatste punt", icon: "arrow.uturn.backward", color: SharedColors.textSecondary, action: action)
    }
}

// MARK: - Earned badges

/// Outlined gold row listing who earned what in this match; tapping it opens
/// the badges. Only shown when a picked player earned something.
public struct MatchBadgesRow: View {
    let earnings: [MatchBadgeEarning]
    let onTap: () -> Void

    public init(earnings: [MatchBadgeEarning], onTap: @escaping () -> Void) {
        self.earnings = earnings
        self.onTap = onTap
    }

    public var body: some View {
        let color = SharedColors.gold
        return Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BADGES VERDIEND")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(color)
                    ForEach(earnings) { earning in
                        earningLine(earning)
                    }
                }
                Spacer(minLength: 0)
                AppSymbol("chevron.right", size: 13, color: color, weight: .semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bekijk badges")
    }

    private func earningLine(_ earning: MatchBadgeEarning) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(earning.badges) { kind in
                    BadgeMedallion(kind: kind, size: 26, showsTitle: false)
                }
            }
            Text("\(earning.name) · " + (earning.badges.count == 1 ? earning.badges[0].tieredTitle : "\(earning.badges.count) badges"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
                .lineLimit(1)
                // Five medallions plus "Bombardino · 5 badges" is wider than
                // the row; Android clips instead of shortening, so shrink
                .minimumScaleFactor(0.7)
        }
    }
}

/// The badges earned in this match, per player, with what each one means.
/// Android's sheet from the result card (iOS opens its own badge screen).
public struct SharedMatchBadgesSheet: View {
    let earnings: [MatchBadgeEarning]
    let onClose: () -> Void

    public init(earnings: [MatchBadgeEarning], onClose: @escaping () -> Void) {
        self.earnings = earnings
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(earnings) { earning in
                            playerSection(earning)
                        }
                    }
                    .padding(20)
                }
            }
            .pageTitle("Badges")
            .toolbar {
                #if os(iOS) && !SKIP
                // iOS: "✕ Sluiten" top left, like every other screen (CloseButton in the app)
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { closeButton }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { closeButton }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { onClose() }
                }
                #endif
            }
        }
    }

    #if os(iOS) && !SKIP
    private var closeButton: some View {
        Button { onClose() } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text("Sluiten")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(SharedColors.textSecondary)
            .lineLimit(1)
            .fixedSize()
            // Toolbars draw icons a size up; keep the ✕ as small as on Spelers
            .imageScale(.medium)
        }
        .buttonStyle(.plain)
    }
    #endif

    private func playerSection(_ earning: MatchBadgeEarning) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(earning.name.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(SharedColors.gold)
            ForEach(earning.badges) { kind in
                HStack(spacing: 14) {
                    BadgeMedallion(kind: kind, size: 52, showsTitle: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kind.tieredTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SharedColors.textPrimary)
                        Text(kind.detail)
                            .font(.system(size: 12))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

extension View {
    /// Read by VoiceOver as one sentence; Skip has no accessibilityElement(children:),
    /// so on Android the label goes on the group as it is
    func readAsOne(_ label: String) -> some View {
        #if SKIP
        return self.accessibilityLabel(label)
        #else
        return self.accessibilityElement(children: .ignore).accessibilityLabel(label)
        #endif
    }
}
