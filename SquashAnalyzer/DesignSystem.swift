import SwiftUI
import SquashAnalyzerCore
import SquashAnalyzerUI

// MARK: - Design System
/// The iPhone screens' names for the shared style tokens. The values live in
/// SquashAnalyzerUI's `SharedColors` (docs/style/tokens.json), so iOS and
/// Android cannot drift apart (T17).

// MARK: - Colors
@MainActor
enum AppColors {
    /// Brand orange, player 1, primary action
    static var warmOrange: Color { SharedColors.accent }
    /// Player 2
    static var steelBlue: Color { SharedColors.steelBlue }
    static var steelBlueLight: Color { SharedColors.steelBlueLight }

    static var backgroundDark: Color { SharedColors.background }
    static var backgroundMedium: Color { SharedColors.surface }

    static var courtSand: Color { SharedColors.courtSand }

    static var textPrimary: Color { SharedColors.textPrimary }
    static var textSecondary: Color { SharedColors.textSecondary }
    static var textMuted: Color { SharedColors.textMuted }

    static var accentGold: Color { SharedColors.gold }

    /// Referee actions of the right-hand player, and STROKE of the left-hand one
    static var coolBlue: Color { SharedColors.coolBlue }
    static var coolIndigo: Color { SharedColors.coolIndigo }
    static var warmRed: Color { SharedColors.warmRed }
    static var positive: Color { SharedColors.positive }

    /// Player 1 orange, player 2 steel blue
    static func player(_ player: Player) -> Color {
        player == .player1 ? warmOrange : steelBlue
    }
}

// MARK: - Typography
struct AppFonts {
    /// Main title font
    static func title(_ size: CGFloat = 18) -> Font {
        SharedFonts.system(size, weight: .bold, design: .rounded)
    }

    /// Label font (uppercase tracking)
    static func label(_ size: CGFloat = 12) -> Font {
        SharedFonts.system(size, weight: .semibold, design: .rounded)
    }

    /// Body text
    static func body(_ size: CGFloat = 14) -> Font {
        SharedFonts.system(size, weight: .medium, design: .rounded)
    }

    /// Score/LED display font
    static func score(_ size: CGFloat = 48) -> Font {
        SharedFonts.system(size, weight: .bold, design: .monospaced)
    }

    /// Button text

    /// Small caption
    static func caption(_ size: CGFloat = 10) -> Font {
        SharedFonts.system(size, weight: .medium, design: .rounded)
    }

    /// Player name in scoreboard

    /// Monospace font for timers
}

// MARK: - Referee-style surfaces

/// The calm, dark card surface used by both referee and coach flows.
struct SportsPanel<Content: View>: View {
    var accent: Color? = nil
    let content: Content

    init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SharedColors.tint(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                accent?.opacity(0.28) ?? SharedColors.tint(0.10),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - Reusable Components


// MARK: - Close button

/// `CloseButton` top left in a navigation bar, without the glass capsule
/// iOS 26 puts around toolbar buttons, so it looks like the one on Spelers
struct CloseToolbarItem: ToolbarContent {
    var title: String = "Sluiten"
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                CloseButton(title: title, action: action)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                CloseButton(title: title, action: action)
            }
        }
    }
}

// MARK: - Background
/// Screen background: true black (docs/style/tokens.json)
struct AppBackground: View {
    var body: some View {
        SharedColors.background
            .ignoresSafeArea()
    }
}

// MARK: - Preview
#Preview("Design System") {
    ZStack {
        AppBackground()
        VStack(spacing: 20) {
            Text("Coach")
                .font(PageTitleStyle.font)
                .foregroundColor(AppColors.textPrimary)
            SportsPanel(accent: AppColors.warmOrange) {
                Text("Kies wie scoort")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(20)
            }
            HStack(spacing: 16) {
                ActionButton("NIELS", style: .filled) { }
                ActionButton("PAUL", color: AppColors.steelBlue) { }
            }
        }
        .padding(20)
    }
}
