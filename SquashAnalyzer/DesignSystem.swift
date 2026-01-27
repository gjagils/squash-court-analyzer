import SwiftUI

// MARK: - Design System
/// Digital Classic Sports Interface - Design System
/// A warm, modern sports interface combining classic LED scoreboards,
/// soft materials, subtle depth, and calm high-contrast action buttons.

// MARK: - Colors
struct AppColors {
    // MARK: Primary Action Colors
    /// Warm orange - Player 1 / Primary action
    static let warmOrange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let warmOrangeDark = Color(red: 0.80, green: 0.42, blue: 0.08)
    static let warmOrangeLight = Color(red: 1.0, green: 0.68, blue: 0.35)
    static let warmOrangeGlow = Color(red: 1.0, green: 0.45, blue: 0.1)

    /// Steel blue - Player 2 / Secondary action
    static let steelBlue = Color(red: 0.35, green: 0.45, blue: 0.55)
    static let steelBlueDark = Color(red: 0.25, green: 0.32, blue: 0.42)
    static let steelBlueLight = Color(red: 0.50, green: 0.58, blue: 0.68)

    // MARK: Background Colors
    /// Dark background with warm undertone
    static let backgroundDark = Color(red: 0.06, green: 0.05, blue: 0.04)
    static let backgroundMedium = Color(red: 0.12, green: 0.10, blue: 0.08)

    // MARK: Panel Colors
    /// Metallic silver/gray panel
    static let panelSilver = Color(red: 0.72, green: 0.70, blue: 0.68)
    static let panelSilverDark = Color(red: 0.55, green: 0.52, blue: 0.50)
    static let panelSilverLight = Color(red: 0.85, green: 0.83, blue: 0.80)

    // MARK: Court Colors - Sand/Wood
    static let courtSand = Color(red: 0.82, green: 0.72, blue: 0.60)
    static let courtSandDark = Color(red: 0.70, green: 0.58, blue: 0.45)
    static let courtSandLight = Color(red: 0.90, green: 0.82, blue: 0.72)

    /// Court lines - Warm terracotta/orange-red
    static let courtLine = Color(red: 0.75, green: 0.42, blue: 0.32)
    static let courtLineLight = Color(red: 0.82, green: 0.50, blue: 0.40)

    // MARK: LED Display Colors
    /// LED segment colors (warm golden glow)
    static let ledActive = Color(red: 1.0, green: 0.88, blue: 0.55)
    static let ledInactive = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let ledBackground = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let ledGlow = Color(red: 1.0, green: 0.75, blue: 0.30)

    // MARK: Text Colors
    static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let textSecondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let textMuted = Color(red: 0.50, green: 0.48, blue: 0.45)

    // MARK: Accent Colors
    static let accentGold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let serverIndicator = Color(red: 1.0, green: 0.60, blue: 0.15)
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
    static func button(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Small caption
    static func caption(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Player name in scoreboard
    static func playerName(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
}

// MARK: - Reusable Components

/// Hardware-style panel with metallic look
struct HardwarePanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Base metallic gradient
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.panelSilverLight,
                                    AppColors.panelSilver,
                                    AppColors.panelSilverDark
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Inner shadow effect
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}

/// LED Display background with inset effect
struct LEDDisplayBackground: View {
    var body: some View {
        ZStack {
            // Dark inset background
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.ledBackground)

            // Inner border (inset effect)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.8), lineWidth: 3)

            // Subtle inner highlight
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .padding(3)
        }
    }
}

/// Hardware-style action button
struct HardwareButton: View {
    let title: String
    let subtitle: String?
    let color: Color
    let colorDark: Color
    let action: () -> Void
    var isSelected: Bool = false

    init(title: String, subtitle: String? = nil, color: Color, colorDark: Color? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.colorDark = colorDark ?? color.opacity(0.7)
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                if let subtitle = subtitle {
                    Text(subtitle.uppercased())
                        .font(AppFonts.caption(10))
                        .foregroundColor(Color.white.opacity(0.85))
                        .tracking(1.5)
                }
                Text(title.uppercased())
                    .font(AppFonts.button(18))
                    .foregroundColor(.white)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    // Base gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [color, colorDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Top highlight shine
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Selection glow
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 2)
                            .blur(radius: 3)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: color.opacity(0.5), radius: isSelected ? 12 : 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// Capsule label (for wall labels)
struct CapsuleLabel: View {
    let text: String
    var color: Color = AppColors.warmOrange.opacity(0.9)

    var body: some View {
        Text(text.uppercased())
            .font(AppFonts.caption(9))
            .foregroundColor(AppColors.textPrimary)
            .tracking(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 2, x: 0, y: 1)
            )
    }
}

/// Server indicator dot
struct ServerIndicator: View {
    var isServing: Bool = true

    var body: some View {
        Circle()
            .fill(isServing ? AppColors.serverIndicator : Color.clear)
            .frame(width: 8, height: 8)
            .shadow(color: isServing ? AppColors.serverIndicator.opacity(0.8) : .clear, radius: 4, x: 0, y: 0)
    }
}

/// Seven-segment LED digit display
struct LEDDigit: View {
    let digit: Int
    let size: CGFloat

    // Segment patterns for 0-9
    private let segments: [[Bool]] = [
        [true, true, true, true, true, true, false],     // 0
        [false, true, true, false, false, false, false], // 1
        [true, true, false, true, true, false, true],    // 2
        [true, true, true, true, false, false, true],    // 3
        [false, true, true, false, false, true, true],   // 4
        [true, false, true, true, false, true, true],    // 5
        [true, false, true, true, true, true, true],     // 6
        [true, true, true, false, false, false, false],  // 7
        [true, true, true, true, true, true, true],      // 8
        [true, true, true, true, false, true, true],     // 9
    ]

    var body: some View {
        let pattern = digit >= 0 && digit <= 9 ? segments[digit] : segments[0]

        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let segmentThickness = h * 0.12
            let gap: CGFloat = 2
            let cornerRadius = segmentThickness * 0.3

            // Segment positions and sizes
            let horizontalWidth = w - segmentThickness * 2 - gap * 2
            let verticalHeight = (h - segmentThickness * 3) / 2 - gap

            // Draw all segments (inactive first, then active on top)
            // Horizontal segments: top (0), middle (6), bottom (3)
            // Vertical segments: top-left (5), top-right (1), bottom-left (4), bottom-right (2)

            let segmentDefs: [(CGRect, Bool, Bool)] = [
                // Top horizontal
                (CGRect(x: segmentThickness + gap, y: 0, width: horizontalWidth, height: segmentThickness), true, pattern[0]),
                // Top-right vertical
                (CGRect(x: w - segmentThickness, y: segmentThickness + gap, width: segmentThickness, height: verticalHeight), false, pattern[1]),
                // Bottom-right vertical
                (CGRect(x: w - segmentThickness, y: h / 2 + gap, width: segmentThickness, height: verticalHeight), false, pattern[2]),
                // Bottom horizontal
                (CGRect(x: segmentThickness + gap, y: h - segmentThickness, width: horizontalWidth, height: segmentThickness), true, pattern[3]),
                // Bottom-left vertical
                (CGRect(x: 0, y: h / 2 + gap, width: segmentThickness, height: verticalHeight), false, pattern[4]),
                // Top-left vertical
                (CGRect(x: 0, y: segmentThickness + gap, width: segmentThickness, height: verticalHeight), false, pattern[5]),
                // Middle horizontal
                (CGRect(x: segmentThickness + gap, y: h / 2 - segmentThickness / 2, width: horizontalWidth, height: segmentThickness), true, pattern[6]),
            ]

            for (rect, _, isOn) in segmentDefs {
                let path = RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
                let color = isOn ? AppColors.ledActive : AppColors.ledInactive
                context.fill(path, with: .color(color))

                // Glow for active segments
                if isOn {
                    context.fill(path, with: .color(AppColors.ledGlow.opacity(0.3)))
                }
            }
        }
        .frame(width: size * 0.55, height: size)
    }
}

/// Two-digit LED score display
struct LEDScoreDisplay: View {
    let score: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.06) {
            LEDDigit(digit: score / 10, size: size)
            LEDDigit(digit: score % 10, size: size)
        }
        .shadow(color: AppColors.ledGlow.opacity(0.4), radius: 8, x: 0, y: 0)
    }
}

/// Colon separator for score display
struct LEDColon: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: size * 0.25) {
            Circle()
                .fill(AppColors.ledActive)
                .frame(width: size * 0.12, height: size * 0.12)
            Circle()
                .fill(AppColors.ledActive)
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .shadow(color: AppColors.ledGlow.opacity(0.4), radius: 4, x: 0, y: 0)
    }
}

// MARK: - Background
struct AppBackground: View {
    var body: some View {
        ZStack {
            // Base dark color
            AppColors.backgroundDark

            // Warm orange radial glow from edges
            RadialGradient(
                colors: [
                    AppColors.warmOrangeGlow.opacity(0.15),
                    AppColors.warmOrangeGlow.opacity(0.08),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 100,
                endRadius: 600
            )

            // Top subtle glow
            RadialGradient(
                colors: [
                    AppColors.warmOrange.opacity(0.05),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )

            // Dark vignette overlay
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                center: .center,
                startRadius: 150,
                endRadius: 500
            )

            // Subtle noise texture
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview
#Preview("Design System") {
    ZStack {
        AppBackground()

        VStack(spacing: 20) {
            // Title
            Text("SQUASH ANALYZER")
                .font(AppFonts.title(20))
                .foregroundColor(AppColors.textPrimary)
                .tracking(3)

            // LED Display
            HardwarePanel {
                VStack(spacing: 0) {
                    Text("SQUASH")
                        .font(AppFonts.caption(10))
                        .foregroundColor(AppColors.textMuted)
                        .tracking(2)
                        .padding(.top, 8)

                    HStack {
                        // Player names
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                ServerIndicator(isServing: false)
                                Text("NIELS")
                                    .font(AppFonts.playerName(16))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            HStack(spacing: 6) {
                                ServerIndicator(isServing: true)
                                Text("PAUL")
                                    .font(AppFonts.playerName(16))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }

                        Spacer()

                        // LED Score
                        HStack(spacing: 8) {
                            LEDScoreDisplay(score: 0, size: 50)
                            LEDColon(size: 50)
                            LEDScoreDisplay(score: 0, size: 50)
                        }
                        .padding(12)
                        .background(LEDDisplayBackground())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 20)

            // Instruction
            Text("Kies wie scoort")
                .font(AppFonts.body(14))
                .foregroundColor(AppColors.textSecondary)

            Spacer().frame(height: 150)

            // Buttons
            HStack(spacing: 16) {
                HardwareButton(
                    title: "Niels",
                    subtitle: "Punt",
                    color: AppColors.warmOrange,
                    colorDark: AppColors.warmOrangeDark
                ) { }

                HardwareButton(
                    title: "Paul",
                    subtitle: "Punt",
                    color: AppColors.steelBlue,
                    colorDark: AppColors.steelBlueDark
                ) { }
            }
            .padding(.horizontal, 24)
        }
    }
}
