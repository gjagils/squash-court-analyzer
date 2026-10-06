import SwiftUI
import SquashAnalyzerCore

// MARK: - Verslag delen

/// "Deel verslag": the same three choices as "Deel score" of a match
/// (Scorekaart, Verslag, Plaatje), with a preview and one Delen button. The
/// choice is the same setting as for a match.
struct TeamMatchShareView: View {
    let match: TeamMatch
    let shareText: (String) -> Void
    let onClose: () -> Void

    @AppStorage(MatchShareChoice.storageKey) private var storedChoice = MatchShareChoice.scorecard.rawValue

    private var choices: [MatchShareChoice] {
        ResultImageSharing.share == nil ? MatchShareChoice.allCases.filter { $0 != MatchShareChoice.picture } : MatchShareChoice.allCases
    }

    private var choice: MatchShareChoice {
        let stored = MatchShareChoice.from(stored: storedChoice)
        return choices.contains(stored) ? stored : MatchShareChoice.scorecard
    }

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                tabs
                Text(choice.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                ScrollView {
                    if let style = choice.textStyle {
                        WhatsAppPreview(text: TeamMatchReport.text(match, style: style))
                            .padding(16)
                            .background(Color.white.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    } else {
                        ResultCardPreview(card: ResultCard.from(match))
                    }
                }
                ActionButton("DELEN", style: .filled) { share() }
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
        .preferredColorScheme(.dark)
    }

    private func share() {
        if let style = choice.textStyle {
            shareText(TeamMatchReport.text(match, style: style))
        } else if let shareImage = ResultImageSharing.share {
            shareImage(ResultCard.from(match))
        }
    }

    private var header: some View {
        ZStack {
            Text("DEEL VERSLAG")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(SharedColors.textPrimary)
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        AppSymbol("xmark", size: 14, color: SharedColors.textSecondary)
                        Text("Sluiten")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sluiten")
                Spacer()
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(choices) { option in
                let active = option == choice
                Button { storedChoice = option.rawValue } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(active ? SharedColors.background : SharedColors.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(active ? SharedColors.gold : SharedColors.gold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SharedColors.gold.opacity(active ? 0.0 : 0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
