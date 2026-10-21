import SwiftUI
import SquashAnalyzerCore

// Instellingen in the style of the home screen (Gerd-Jan, 21 October 2026):
// the manual in an orange outlined card, then one line per part with an
// orange icon, as Afgeronde wedstrijden and Competitie on the home screen; a
// line opens underneath instead of going to another screen. iOS and Android.

/// What a line of Instellingen looks like: icon, title and a chevron (down or
/// up for a part that opens, right for an action). No button of its own, so
/// a Link or ShareLink can wear it too.
public struct SettingsRowLabel: View {
    let title: String
    let icon: String
    /// true open, false closed, nil an action (chevron to the right)
    let open: Bool?

    public init(_ title: String, icon: String, open: Bool? = nil) {
        self.title = title
        self.icon = icon
        self.open = open
    }

    private var chevron: String {
        guard let open else { return "chevron.right" }
        return open ? "chevron.up" : "chevron.down"
    }

    public var body: some View {
        HStack(spacing: 12) {
            AppSymbol(icon, size: 21, color: SharedColors.accent, weight: .medium)
                .frame(width: 23, height: 23)
            Text(title).font(SharedFonts.system(14))
            Spacer()
            AppSymbol(chevron, size: 12, color: SharedColors.textPrimary)
        }
        .foregroundColor(SharedColors.textPrimary)
        .frame(minHeight: 50)
        // Apple only: a no-op in SkipUI, and Compose's clickable already covers the row (docs/bewuste-keuzes.md)
        #if !SKIP
        .contentShape(Rectangle())
        #endif
    }
}

/// A line that opens or closes its part (or does its action)
public struct SettingsRow: View {
    let title: String
    let icon: String
    let open: Bool?
    let action: () -> Void

    public init(_ title: String, icon: String, open: Bool? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.open = open
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            SettingsRowLabel(title, icon: icon, open: open)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(open == nil ? title : (open == true ? loc("\(title), open") : loc("\(title), dicht")))
    }
}

/// The thin line between two rows, as on the home screen
public struct SettingsDivider: View {
    public init() {}
    public var body: some View {
        Divider().overlay(SharedColors.line(0.09))
    }
}

/// The manual on top, in an orange outlined card
public struct SettingsManualCard: View {
    let manual: URL

    public init(manual: URL) { self.manual = manual }

    public var body: some View {
        Link(destination: manual) {
            HStack(spacing: 14) {
                AppSymbol("book", size: 20, color: SharedColors.accent, weight: .medium)
                    .frame(width: 44, height: 44)
                    .background(SharedColors.brandCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Handleiding", bundle: textBundle)
                        .font(SharedFonts.system(16, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Text("Per tegel uitgelegd hoe alles werkt, op squashanalyzer.com.", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Open de handleiding", bundle: textBundle)
                        .font(SharedFonts.system(13, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(SharedColors.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
        }
        .accessibilityLabel(loc("Open de handleiding"))
    }
}
