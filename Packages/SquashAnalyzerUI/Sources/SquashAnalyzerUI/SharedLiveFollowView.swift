import SwiftUI
import SquashAnalyzerCore

/// "Wedstrijd volgen": put a live match on the lock screen (Live score op het
/// vergrendelscherm). Opened from the home menu, or by a live link
/// (`squashanalyzer://volg#…`, the button on the viewer page), which is then
/// followed at once. Lists the matches this phone follows, each with Stoppen.
/// Shown only where the platform has a `LiveFollow.presenter`.
public struct SharedLiveFollowView: View {
    private let onClose: () -> Void

    @State private var text: String
    @State private var busy = false
    @State private var message: String? = nil
    @State private var failed = false
    /// A link that came with the screen is followed once, on appear
    @State private var autoFollow: Bool

    public init(initialLink: String = "", onClose: @escaping () -> Void) {
        self.onClose = onClose
        _text = State(initialValue: initialLink)
        _autoFollow = State(initialValue: !initialLink.isEmpty)
    }

    private var follow: LiveFollow { LiveFollow.shared }

    public var body: some View {
        NavigationStack {
            ZStack {
                SharedColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Kun je er niet bij zijn? Plak de live link die in de groep gedeeld is. De stand staat dan op je vergrendelscherm en gaat na elke rally mee, ook als de app dicht is.", bundle: .module)
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField(loc("Live link"), text: $text)
                            .font(SharedFonts.system(14))
                            .foregroundColor(SharedColors.textPrimary)
                            .padding(10)
                            .background(SharedColors.tint(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        ActionButton(busy ? loc("Even geduld…") : loc("Volgen"), style: .filled,
                                     disabled: busy || text.trimmingCharacters(in: .whitespaces).isEmpty) {
                            Task { await start() }
                        }
                        // The server can still refuse the phone's push token after the match was put on the lock screen
                        if let error = follow.lastError, !busy {
                            Text(error.message)
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let message {
                            Text(message)
                                .font(SharedFonts.system(12))
                                .foregroundColor(failed ? SharedColors.error : SharedColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !follow.following.isEmpty {
                            followingList
                        }
                    }
                    .padding(24)
                }
            }
            .pageTitle(loc("Wedstrijd volgen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(title: loc("Sluiten"), action: onClose)
                }
            }
            .task {
                if autoFollow {
                    autoFollow = false
                    await start()
                }
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private var followingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(loc("OP JE VERGRENDELSCHERM"))
            ForEach(follow.following, id: \.self) { target in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(follow.title(of: target) ?? loc("Live wedstrijd"))
                            .font(SharedFonts.system(15, weight: .semibold, design: .rounded))
                            .foregroundColor(SharedColors.textPrimary)
                            .lineLimit(1)
                        Text(LiveFollowLink.host(of: target.server))
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(loc("Stoppen")) {
                        Task { await follow.unfollow(target) }
                    }
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel(loc("Stoppen met volgen"))
                }
                .padding(12)
                .background(SharedColors.tint(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func start() async {
        guard let target = LiveFollowLink.parse(text) else {
            failed = true
            message = loc("Dit is geen live link van SquashAnalyzer. Kopieer de hele link uit het bericht.")
            return
        }
        busy = true
        message = nil
        do {
            try await follow.follow(target)
            failed = false
            let name = follow.title(of: target) ?? loc("de wedstrijd")
            message = loc("Je volgt \(name) op je vergrendelscherm.")
            text = ""
        } catch {
            failed = true
            message = (error as? LiveFollowError)?.message ?? LiveFollowError.noConnection.message
        }
        busy = false
    }
}
