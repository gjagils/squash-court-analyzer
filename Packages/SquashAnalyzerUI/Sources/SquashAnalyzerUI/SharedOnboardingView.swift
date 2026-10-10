import SwiftUI
import SquashAnalyzerCore

/// De rondleiding (docs/voorstel-rondleiding.md): six pages with a symbol, a
/// title and a few lines, on iOS and Android. Swipe or tap Volgende; Overslaan
/// is always there. Own paging (a drag and the buttons), not a paged TabView:
/// how Skip turns that into Compose is uncertain.
public struct SharedOnboardingView: View {
    /// "Teamlink invullen" on the Competitie page; nil leaves the button out
    let onTeamLink: (() -> Void)?
    let manual: URL
    /// Finished or skipped
    let onDone: () -> Void

    @State private var page = 0

    public init(manual: URL, onTeamLink: (() -> Void)? = nil, onDone: @escaping () -> Void) {
        self.manual = manual
        self.onTeamLink = onTeamLink
        self.onDone = onDone
    }

    private var isLast: Bool { page == Onboarding.pages.count - 1 }

    public var body: some View {
        let current = Onboarding.pages[page]
        return ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Overslaan") { onDone() }
                        .font(SharedFonts.system(15, weight: .semibold))
                        .foregroundColor(SharedColors.textSecondary)
                        .accessibilityLabel("Rondleiding overslaan")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer(minLength: 16)

                VStack(spacing: 22) {
                    AppSymbol(current.symbol, size: 54, color: SharedColors.accent)
                        .frame(width: 112, height: 112)
                        .background(SharedColors.brandCard)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
                    Text(current.title)
                        .font(SharedFonts.system(26, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(current.text)
                        .font(SharedFonts.system(16))
                        .foregroundColor(SharedColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if page == Onboarding.competitionPage, let onTeamLink {
                        ActionButton("TEAMLINK INVULLEN", icon: "person.2.circle", style: .outlined, color: SharedColors.accent) {
                            onTeamLink()
                        }
                    }
                    if isLast {
                        Link(destination: manual) {
                            Text("Lees de handleiding")
                                .font(SharedFonts.system(15, weight: .semibold))
                                .foregroundColor(SharedColors.accent)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 16)

                dots
                    .padding(.bottom, 20)

                HStack(spacing: 12) {
                    if page > 0 {
                        ActionButton("VORIGE", style: .outlined, color: SharedColors.textSecondary) {
                            page -= 1
                        }
                    }
                    ActionButton(isLast ? "AAN DE SLAG" : "VOLGENDE", style: .filled, color: SharedColors.accent) {
                        if isLast { onDone() } else { page += 1 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40.0 && !isLast { page += 1 }
                    if value.translation.width > 40.0 && page > 0 { page -= 1 }
                }
        )
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<Onboarding.pages.count, id: \.self) { index in
                Circle()
                    .fill(index == page ? SharedColors.accent : SharedColors.line(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .readAsOne("Stap \(page + 1) van \(Onboarding.pages.count)")
    }
}

/// "Over de app" in Instellingen, on iOS and Android: the tour again, share
/// the app (both stores) and feedback by mail
public struct AboutAppSection: View {
    let appVersion: String
    let manual: URL
    @State private var showingTour = false

    public init(appVersion: String, manual: URL) {
        self.appVersion = appVersion
        self.manual = manual
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Over de app")
                .font(SharedFonts.system(16, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Button { showingTour = true } label: {
                row("Rondleiding opnieuw bekijken", icon: "play.fill")
            }
            .buttonStyle(.plain)
            ShareLink(item: AppLinks.shareText, subject: Text("Squash Analyzer")) {
                row("Deel de app", icon: "square.and.arrow.up")
            }
            .accessibilityLabel("Deel de app")
            Link(destination: AppLinks.feedbackMail(appVersion: appVersion)) {
                row("Feedback sturen", icon: "lightbulb.fill")
            }
            .accessibilityLabel("Feedback sturen naar \(AppLinks.feedbackAddress)")
            Text("Feedback gaat per mail naar \(AppLinks.feedbackAddress), met de versie van de app erbij (\(appVersion)).")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textMuted)
        }
        .trackedCover(isPresented: $showingTour) {
            SharedOnboardingView(manual: manual) { showingTour = false }
        }
    }

    private func row(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            AppSymbol(icon, size: 15, color: SharedColors.accent)
                .frame(width: 22)
            Text(title)
                .font(SharedFonts.system(15, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Spacer(minLength: 0)
            AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
