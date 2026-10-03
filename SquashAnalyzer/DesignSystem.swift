import SwiftUI
import SquashAnalyzerCore
import SquashAnalyzerUI

// MARK: - Design System
/// The iPhone screens' names for the shared style tokens. The values live in
/// SquashAnalyzerUI's `SharedColors` (docs/style/tokens.json), so iOS and
/// Android cannot drift apart (T17).

// MARK: - Colors
enum AppColors {
    /// Brand orange, player 1, primary action
    static let warmOrange = SharedColors.accent
    /// Player 2
    static let steelBlue = SharedColors.steelBlue
    static let steelBlueLight = SharedColors.steelBlueLight

    static let backgroundDark = SharedColors.background
    static let backgroundMedium = SharedColors.surface

    static let courtSand = SharedColors.courtSand

    static let textPrimary = SharedColors.textPrimary
    static let textSecondary = SharedColors.textSecondary
    static let textMuted = SharedColors.textMuted

    static let accentGold = SharedColors.gold

    /// Referee actions of the right-hand player, and STROKE of the left-hand one
    static let coolBlue = SharedColors.coolBlue
    static let coolIndigo = SharedColors.coolIndigo
    static let warmRed = SharedColors.warmRed
}

// MARK: - Typography
struct AppFonts {
    /// Main title font
    static func title(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Label font (uppercase tracking)
    static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    /// Body text
    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Score/LED display font
    static func score(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    /// Button text

    /// Small caption
    static func caption(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
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
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                accent?.opacity(0.28) ?? Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - Reusable Components

/// Hardware-style action button
struct HardwareButton: View {
    enum Style {
        /// Solid accent fill with dark text – primary call to action
        case filled
        /// Low-opacity tint with a thin stroke and coloured text – secondary action
        case outlined
    }

    let title: String
    let subtitle: String?
    let color: Color
    let style: Style
    let action: () -> Void
    var isSelected: Bool = false

    init(title: String, subtitle: String? = nil, color: Color,
         style: Style = .filled, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.style = style
        self.isSelected = isSelected
        self.action = action
    }

    private var foreground: Color {
        style == .filled ? AppColors.backgroundDark : color
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let subtitle = subtitle {
                    Text(subtitle.uppercased())
                        .font(AppFonts.caption(9))
                        .foregroundColor(foreground.opacity(0.7))
                        .tracking(1.5)
                }
                Text(title.uppercased())
                    .font(AppFonts.label(14))
                    .foregroundColor(foreground)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style == .filled ? color : color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.white.opacity(0.8) : color.opacity(style == .filled ? 0 : 0.35),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Close button

/// "✕ Sluiten" as on Spelers: the one close button of the app (also for
/// "Annuleren"). Grey text, no capsule.
struct CloseButton: View {
    var title: String = "Sluiten"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text(title)
            }
            .font(AppFonts.body(14))
            .foregroundColor(AppColors.textSecondary)
            .lineLimit(1)
            .fixedSize()
            // Toolbars draw icons a size up; keep the ✕ as small as on Spelers
            .imageScale(.medium)
        }
        .buttonStyle(.plain)
    }
}

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
        Color.black
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
                HardwareButton(title: "Niels", subtitle: "Punt", color: AppColors.warmOrange) { }
                HardwareButton(title: "Paul", subtitle: "Punt", color: AppColors.steelBlue, style: .outlined) { }
            }
        }
        .padding(20)
    }
}
