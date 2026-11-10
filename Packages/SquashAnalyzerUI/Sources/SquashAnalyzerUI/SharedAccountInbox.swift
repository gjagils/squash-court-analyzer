import SwiftUI
import SquashAnalyzerCore

// 4.0: the Postvak of the player account (Gebruiken, Niet gebruiken, Blokkeren)
// and the team's matches that wait for a name ("Ben jij X?"). Shown in
// Instellingen → Mijn account and, since 10 November 2026, from the
// Wedstrijdverzoeken block on the home screen (HomeInboxBar).

public struct SharedAccountInbox: View {
    @State private var busy = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var confirmBlock = false
    @State private var blockMatchId = ""

    private var account: PlayerAccount { PlayerAccount.shared }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            inboxPart
            teamPart
            if busy {
                ProgressView()
            }
            if let message {
                Text(message)
                    .font(SharedFonts.system(12))
                    .foregroundColor(messageIsError ? SharedColors.error : SharedColors.support)
            }
        }
        .alert(loc("Afzender blokkeren?"), isPresented: $confirmBlock) {
            Button(loc("Blokkeren"), role: .destructive) { answer(blockMatchId, use: false, block: true) }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text("Deze wedstrijd wordt gewist en van deze telefoon krijg je geen verzoeken meer.", bundle: textBundle)
        }
    }

    private var inboxPart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Postvak", bundle: textBundle)
                    .font(SharedFonts.system(14, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Spacer()
                Button(loc("Vernieuwen")) { refresh() }
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
                    .disabled(busy)
            }
            .padding(.top, 10)
            if account.inbox.isEmpty {
                note(loc("Geen wedstrijden die op je antwoord wachten."))
            }
            ForEach(account.inbox) { match in
                inboxCard(match)
            }
        }
    }

    private func inboxCard(_ match: AccountServerMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(match.inboxTitle)
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Text(match.inboxDetail)
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 8) {
                ActionButton(loc("GEBRUIKEN"), style: .filled, color: SharedColors.accent, disabled: busy) {
                    answer(match.matchId, use: true, block: false)
                }
                ActionButton(loc("NIET GEBRUIKEN"), style: .outlined, color: SharedColors.textSecondary, disabled: busy) {
                    answer(match.matchId, use: false, block: false)
                }
            }
            Button(loc("Blokkeren")) {
                blockMatchId = match.matchId
                confirmBlock = true
            }
            .font(SharedFonts.system(12))
            .foregroundColor(SharedColors.error)
            .disabled(busy)
        }
        .padding(12)
        .background(SharedColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Matches of your team for a name nobody claimed yet: a teammate may know you as "Gerd Lasso"
    @ViewBuilder
    private var teamPart: some View {
        if !account.teamInbox.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Uit je team", bundle: textBundle)
                    .font(SharedFonts.system(14, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                    .padding(.top, 10)
                note(loc("Een teamgenoot heeft deze wedstrijden ingevuld met een naam die nog niet gekoppeld is. Ben jij het, dan telt de wedstrijd voor jou."))
                ForEach(account.teamInbox) { match in
                    teamCard(match)
                }
            }
        }
    }

    private func teamCard(_ match: AccountServerMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let called = match.name ?? ""
            Text(loc("Ben jij \"\(called)\"?"))
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Text("\(match.inboxTitle) · \(match.inboxDetail)")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 8) {
                ActionButton(loc("DAT BEN IK"), style: .filled, color: SharedColors.accent, disabled: busy) { claim(match) }
                ActionButton(loc("NIET IK"), style: .outlined, color: SharedColors.textSecondary, disabled: busy) {
                    account.hideTeamMatch(match)
                }
            }
        }
        .padding(12)
        .background(SharedColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(SharedFonts.system(12))
            .foregroundColor(SharedColors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Actions

    private func run(_ success: String?, _ work: @escaping () async throws -> Void) {
        busy = true
        message = nil
        Task {
            do {
                try await work()
                message = success
                messageIsError = false
            } catch let error as AccountError {
                message = error.message
                messageIsError = true
            } catch {
                message = AccountError.noConnection.message
                messageIsError = true
            }
            busy = false
        }
    }

    private func refresh() {
        guard account.isConfigured, account.isSignedIn, account.profile != nil else { return }
        run(nil) {
            try await account.loadInbox()
            await account.sendOutbox()
            await AccountSync.shared.run()
        }
    }

    private func claim(_ match: AccountServerMatch) {
        run(loc("De wedstrijd telt mee en staat bij Afgeronde wedstrijden.")) {
            try await account.claimTeamMatch(match)
            await AccountSync.shared.run()
        }
    }

    private func answer(_ matchId: String, use: Bool, block: Bool) {
        run(use ? loc("De wedstrijd telt mee en staat bij Afgeronde wedstrijden.") : nil) {
            try await account.answer(matchId: matchId, use: use, block: block)
            if use { await AccountSync.shared.run() }
        }
    }
}
