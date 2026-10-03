import SwiftUI
import SquashAnalyzerCore

/// "Deel score" on Android: Scorekaart, Verslag or Plaatje (Core's
/// `MatchShareChoice`, the same choices and texts as iOS' `MatchShareSheet`),
/// a preview, and one Delen button. The choice is remembered with the same key
/// as iOS, one setting for coach and referee.
/// The picture on Android: the app sets this at start (it draws Core's
/// `ResultCard` on a Canvas and shares the PNG, `ResultImage.kt`). nil hides
/// the Plaatje choice. A setting at app level instead of yet another init
/// parameter through every screen that shares a score.
public enum ResultImageSharing {
    @MainActor public static var share: ((ResultCard) -> Void)? = nil
}

public struct SharedMatchShareView: View {
    let report: MatchShareReport
    let shareText: (String) -> Void
    let onClose: () -> Void
    let player1Photo: Data?
    let player2Photo: Data?

    @AppStorage(MatchShareChoice.storageKey) private var storedChoice = MatchShareChoice.scorecard.rawValue

    public init(report: MatchShareReport, player1Photo: Data? = nil, player2Photo: Data? = nil,
                shareText: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.report = report
        self.player1Photo = player1Photo
        self.player2Photo = player2Photo
        self.shareText = shareText
        self.onClose = onClose
    }

    private var choices: [MatchShareChoice] {
        ResultImageSharing.share == nil ? MatchShareChoice.allCases.filter { $0 != MatchShareChoice.picture } : MatchShareChoice.allCases
    }

    private var choice: MatchShareChoice {
        let stored = MatchShareChoice.from(stored: storedChoice)
        return choices.contains(stored) ? stored : MatchShareChoice.scorecard
    }

    private var card: ResultCard {
        ResultCard.from(report).withPhotos(player1Photo, player2Photo)
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                styleTabs
                Text(choice.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                ScrollView {
                    if let style = choice.textStyle {
                        // The preview reads like the chat: *bold*, _italic_ and ``` blocks, as on iOS
                        WhatsAppPreview(text: report.text(style: style))
                            .padding(16)
                            .background(Color.white.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    } else {
                        ResultCardPreview(card: card)
                    }
                }
                ActionButton("DELEN", style: .filled) { share() }
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
    }

    private func share() {
        if let style = choice.textStyle {
            shareText(report.text(style: style))
        } else if let shareImage = ResultImageSharing.share {
            shareImage(card)
        }
    }

    /// "✕ Sluiten" left, the title centred, as on iOS
    private var header: some View {
        ZStack {
            Text("DEEL SCORE")
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

    private var styleTabs: some View {
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

/// WhatsApp markup the way the chat shows it: *bold*, _italic_ and ```
/// monospace``` blocks, like iOS' preview. Without Markdown support on
/// Android, each line is split into styled pieces.
struct WhatsAppPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(ChatMarkup.blocks(text)) { block in
                if let mono = block.mono {
                    Text(mono)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(SharedColors.textPrimary)
                        .padding(.vertical, 2)
                } else {
                    line(block.segments)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ segments: [ChatSegment]) -> some View {
        HStack(spacing: 0) {
            ForEach(segments) { segment in
                Text(segment.text)
                    .font(.system(size: 15, weight: segment.bold ? .bold : .regular))
                    .italic(segment.italic)
                    .foregroundColor(SharedColors.textPrimary)
            }
        }
    }
}
