import SwiftUI
import SwiftData
import SquashAnalyzerCore

/// "Deel score": Scorekaart, Verslag or Plaatje, a preview of how it will look
/// in the chat, and one Delen button for the system share sheet. The choice is
/// remembered (one setting for coach and referee, the same on Android).
struct MatchShareSheet: View {
    let report: MatchShareReport

    @Environment(\.dismiss) private var dismiss
    @AppStorage(MatchShareChoice.storageKey) private var storedChoice = MatchShareChoice.scorecard.rawValue
    @Query private var players: [SavedPlayer]
    @State private var shareItems: ShareItemsWrapper? = nil

    private var choice: MatchShareChoice { MatchShareChoice.from(stored: storedChoice) }

    /// The result card with the players' photos, as on the end-of-game card
    private var card: ResultCard {
        ResultCard.from(report).withPhotos(players.photo(named: report.player1Name),
                                           players.photo(named: report.player2Name))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                header

                choiceTabs
                    .padding(.horizontal, 20)

                Text(choice.subtitle)
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textMuted)

                ScrollView {
                    if let style = choice.textStyle {
                        // The preview hugs its text like a chat bubble; long reports scroll
                        WhatsAppPreview(text: report.text(style: style))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.055))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                    } else {
                        // The picture as it will be sent
                        ResultCardImage(card: card, width: nil)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                            .padding(.horizontal, 20)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                HardwareButton(title: "Delen", color: AppColors.warmOrange) { share() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .sheet(item: $shareItems) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    private func share() {
        if let style = choice.textStyle {
            shareItems = ShareItemsWrapper(items: [report.text(style: style)])
        } else if let image = ResultCardImage.render(card) {
            shareItems = ShareItemsWrapper(items: [image])
        }
    }

    private var header: some View {
        HStack {
            CloseButton { dismiss() }

            Spacer()

            Text("DEEL SCORE")
                .font(AppFonts.title(14))
                .foregroundColor(AppColors.textPrimary)
                .tracking(2)

            Spacer()

            // Balances the close button so the title sits centred
            CloseButton {}
                .hidden()
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    private var choiceTabs: some View {
        HStack(spacing: 8) {
            ForEach(MatchShareChoice.allCases) { option in
                let active = option == choice
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { storedChoice = option.rawValue } }) {
                    Text(option.title)
                        .font(AppFonts.label(13))
                        .foregroundColor(active ? AppColors.backgroundDark : AppColors.accentGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(active ? AppColors.accentGold : AppColors.accentGold.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.accentGold.opacity(active ? 0 : 0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

/// Renders WhatsApp markup the way the chat will show it: *bold*, _italic_ and
/// ```monospace``` blocks. Anything the parser rejects falls back to plain text.
private struct WhatsAppPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .mono(let lines):
                    Text(lines.joined(separator: "\n"))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.vertical, 2)
                case .line(let line):
                    // Regular weight like the chat, so *bold* actually stands out
                    Text(styled(line))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Block {
        case line(String)
        case mono([String])
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var mono: [String]? = nil
        for line in text.components(separatedBy: "\n") {
            if line == "```" {
                if let m = mono { result.append(.mono(m)); mono = nil } else { mono = [] }
            } else if mono != nil {
                mono?.append(line)
            } else {
                result.append(.line(line))
            }
        }
        if let m = mono { result.append(.mono(m)) }
        return result
    }

    /// WhatsApp's single-asterisk bold becomes Markdown's double asterisk
    private func styled(_ line: String) -> AttributedString {
        guard !line.isEmpty else { return AttributedString(" ") }
        let markdown = line.replacingOccurrences(
            of: #"\*([^*]+)\*"#, with: "**$1**", options: .regularExpression
        )
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(line)
    }
}
