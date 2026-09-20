import SwiftUI

/// Lets the referee pick one of the WhatsApp layouts, shows how it will read in
/// the chat and hands the text to the system share sheet. The last used layout
/// is remembered.
struct RefereeShareSheet: View {
    let match: RefereeMatch

    @Environment(\.dismiss) private var dismiss
    @AppStorage("refereeShareStyle") private var storedStyle = RefereeShareStyle.compact.rawValue
    @State private var shareItems: ShareItemsWrapper? = nil

    private var style: RefereeShareStyle {
        RefereeShareStyle(rawValue: storedStyle) ?? .compact
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                header

                styleTabs
                    .padding(.horizontal, 20)

                Text(style.subtitle)
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textMuted)

                // The preview hugs its text like a chat bubble; long reports scroll
                ScrollView {
                    WhatsAppPreview(text: match.shareText(style: style))
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
                }
                .scrollBounceBehavior(.basedOnSize)

                HardwareButton(title: "Delen", color: AppColors.warmOrange) {
                    shareItems = ShareItemsWrapper(items: [match.shareText(style: style)])
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $shareItems) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("Sluiten")
                }
                .font(AppFonts.body(14))
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("DEEL SCORE")
                .font(AppFonts.title(14))
                .foregroundColor(AppColors.textPrimary)
                .tracking(2)

            Spacer()

            // Balances the close button so the title sits centred
            Text("Sluiten")
                .font(AppFonts.body(14))
                .hidden()
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    private var styleTabs: some View {
        HStack(spacing: 8) {
            ForEach(RefereeShareStyle.allCases) { option in
                let active = option == style
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { storedStyle = option.rawValue } }) {
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
