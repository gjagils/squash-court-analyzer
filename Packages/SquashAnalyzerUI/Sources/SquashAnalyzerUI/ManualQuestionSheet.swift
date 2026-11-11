import SwiftUI
import SquashAnalyzerCore

/// "Stel een vraag" as a window over the home screen (Gerd-Jan, 11 November
/// 2026): a short answer from the manual, with links to read further on the
/// website. The same answer as the box at the top of the manual.
public struct ManualQuestionSheet: View {
    let onClose: () -> Void

    @State private var question = ""
    @State private var asking = false
    @State private var answer: ManualAnswer? = nil
    @State private var failure: String? = nil

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var english: Bool { AppLanguage.current == AppLanguage.english }
    private var android: Bool {
        #if SKIP
        return true
        #else
        return false
        #endif
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Stel een vraag", bundle: textBundle)
                        .font(SharedFonts.system(18, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Sluiten")) { onClose() }
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                Text("Een vraag over de app? Het antwoord komt uit de handleiding.", bundle: textBundle)
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField(loc("Bijvoorbeeld: Hoe deel ik de stand met mijn team?"), text: $question)
                    .accessibilityLabel(loc("Stel een vraag"))
                    .foregroundColor(SharedColors.textPrimary)
                    .padding(12)
                    .background(SharedColors.tint(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit { ask() }
                ActionButton(loc("VRAAG"), style: .filled, color: SharedColors.accent,
                             disabled: asking || !ManualQuestion.isAskable(question)) { ask() }
                if asking {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Even zoeken…", bundle: textBundle)
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                    }
                }
                if let failure {
                    Text(failure)
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let answer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(answer.answer)
                            .font(SharedFonts.system(15))
                            .foregroundColor(SharedColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(0..<answer.links.count, id: \.self) { index in
                            if let url = answer.links[index].url {
                                Link(destination: url) {
                                    Text(loc("Lees verder: \(answer.links[index].title)"))
                                        .font(SharedFonts.system(13, weight: .semibold))
                                        .foregroundColor(SharedColors.accent)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SharedColors.cardTint)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text("Het antwoord wordt gemaakt met AI (Cloudflare). We bewaren je vraag, zonder je naam of IP-adres, om de app en de handleiding te verbeteren. Typ geen persoonlijke gegevens.", bundle: textBundle)
                    .font(SharedFonts.system(11))
                    .foregroundColor(SharedColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(SharedColors.background.ignoresSafeArea())
        .appAppearance()
    }

    private func ask() {
        guard !asking, ManualQuestion.isAskable(question), let transport = LiveShare.shared.transport else {
            if LiveShare.shared.transport == nil { failure = loc("Dat lukte niet. Probeer het zo nog eens.") }
            return
        }
        let text = question
        asking = true
        failure = nil
        Task {
            do {
                answer = try await ManualQuestion.ask(text, english: english, android: android, transport: transport)
            } catch let error as ManualQuestionError {
                answer = nil
                failure = error == ManualQuestionError.busy ? loc("Veel vragen net. Probeer het over een minuut weer.")
                    : loc("Dat lukte niet. Probeer het zo nog eens, of mail info@squashanalyzer.com.")
            } catch {
                answer = nil
                failure = loc("Dat lukte niet. Probeer het zo nog eens, of mail info@squashanalyzer.com.")
            }
            asking = false
        }
    }
}
