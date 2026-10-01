import SwiftUI
import SquashAnalyzerCore

/// A badge medallion. Android has no badge artwork yet (see BadgeView.swift on
/// iOS, which tries `UIImage(named:)` first), so this shared version always
/// renders the plain gold placeholder — same scope-cut as
/// `PlayerAvatarPlaceholder` for player photos.
public struct BadgeMedallion: View {
    let kind: BadgeKind
    var size: CGFloat = 64.0
    var showsTitle = true
    var isLocked = false

    public init(kind: BadgeKind, size: CGFloat = 64.0, showsTitle: Bool = true, isLocked: Bool = false) {
        self.kind = kind
        self.size = size
        self.showsTitle = showsTitle
        self.isLocked = isLocked
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(BadgePalette.gold.opacity(0.18))
                Circle().strokeBorder(BadgePalette.gold, lineWidth: size * 0.05)
                AppSymbol("medal.fill", size: size * 0.4, color: BadgePalette.gold)
            }
            .frame(width: size, height: size)
            .grayscale(isLocked ? 1.0 : 0.0)
            .opacity(isLocked ? 0.35 : 1.0)

            if showsTitle {
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isLocked ? BadgePalette.textMuted : BadgePalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel("Badge \(kind.title)\(isLocked ? ", nog niet verdiend" : "")")
    }
}

enum BadgePalette {
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let textSecondary = Color(red: 0.75, green: 0.73, blue: 0.70)
    static let textMuted = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let backgroundDark = Color(red: 0.06, green: 0.05, blue: 0.04)
}

/// The full badge catalog: every badge there is, locked/unlocked state aside.
/// No player or award data needed, so this is reachable without any setup.
/// Named `Shared...` (not `BadgeCatalogView`) because the iOS app target
/// already has its own `BadgeCatalogView` with real artwork; the two must
/// not collide once both are in scope via `import SquashAnalyzerUI`.
public struct SharedBadgeCatalogView: View {
    public init() {}

    public var body: some View {
        List {
            Section {
                Text("Spelers die je kiest via \"Kies speler\" verdienen badges tijdens een wedstrijd, in coach- en scheidsrechtermodus. Badges met het label Coach vragen om de slagen die alleen coachmodus bijhoudt.")
                    .font(.system(size: 12))
                    .foregroundColor(BadgePalette.textSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(BadgeKind.Category.allCases, id: \.self) { category in
                Section {
                    ForEach(BadgeKind.allCases.filter { $0.category == category }) { kind in
                        HStack(spacing: 14) {
                            BadgeMedallion(kind: kind, size: 56, showsTitle: false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(BadgePalette.textPrimary)
                                Text(kind.detail)
                                    .font(.system(size: 12))
                                    .foregroundColor(BadgePalette.textSecondary)
                                HStack(spacing: 6) {
                                    if kind.coachOnly { tag("Coach") }
                                    if kind.isOnce { tag("Eén keer") }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                } header: {
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(BadgePalette.gold)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BadgePalette.backgroundDark.ignoresSafeArea())
        .navigationTitle("Alle badges")
    }

    private func tag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .foregroundColor(BadgePalette.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().stroke(BadgePalette.gold.opacity(0.5), lineWidth: 1))
    }
}
