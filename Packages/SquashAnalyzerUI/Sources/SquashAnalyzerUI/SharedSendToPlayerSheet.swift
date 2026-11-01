import SwiftUI
import SquashAnalyzerCore

// 4.0, behind Features.shared.playerAccount: "Stuur naar speler" on the result
// card of a finished match, for a player outside Mijn team (a friend, a club
// evening). The match goes to the account server with a link; the coach shares
// the link (WhatsApp) and whoever opens it in the app gets the match.
// Teammates need no link: their matches go by themselves (AccountSending).

public struct SharedSendToPlayerSheet: View {
    let names: [Player: String]
    let upload: (Player) -> AccountMatchUpload?
    let shareText: (String) -> Void
    let onClose: () -> Void

    @State private var busy = false
    @State private var message: String?

    public init(names: [Player: String], upload: @escaping (Player) -> AccountMatchUpload?,
                shareText: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.names = names
        self.upload = upload
        self.shareText = shareText
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Stuur naar speler", bundle: textBundle)
                    .font(SharedFonts.system(18, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Spacer()
                Button(loc("Sluiten")) { onClose() }
                    .font(SharedFonts.system(14, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
            }
            Text("Je deelt een link. Wie hem in de app opent, krijgt de wedstrijd in zijn account. Spelers uit Mijn team krijgen hun wedstrijden vanzelf.", bundle: textBundle)
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach([Player.player1, Player.player2], id: \.self) { side in
                let name = names[side] ?? ""
                ActionButton(loc("NAAR \(name.uppercased())"), style: .outlined, color: SharedColors.accent, disabled: busy) {
                    send(side, name: name)
                }
            }
            if busy { ProgressView() }
            if let message {
                Text(message)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.error)
            }
            Spacer()
        }
        .padding(20)
        .background(SharedColors.background.ignoresSafeArea())
    }

    private func send(_ side: Player, name: String) {
        guard let match = upload(side) else { return }
        busy = true
        message = nil
        let account = PlayerAccount.shared
        Task {
            do {
                let token = try await account.shareLink(match, senderName: account.profile?.name ?? "")
                busy = false
                let link = AccountClaimLink.url(token: token)
                shareText(loc("\(name), hier is onze wedstrijd voor je Squash Analyzer-account. Open de link op je telefoon: \(link)"))
                onClose()
            } catch let error as AccountError {
                busy = false
                message = error.message
            } catch {
                busy = false
                message = AccountError.noConnection.message
            }
        }
    }
}

/// The other end: a "Stuur naar speler" link opened in the app
/// (`PlayerAccount.pendingClaim`). Signed in with an account, one tap adds the
/// match; otherwise Mijn account is right here to sign in first.
public struct SharedAccountClaimSheet: View {
    let token: String
    let providers: [AccountProviderSignIn]
    let onClose: () -> Void

    @State private var busy = false
    @State private var message: String?
    @State private var done = false

    private var account: PlayerAccount { PlayerAccount.shared }

    public init(token: String, providers: [AccountProviderSignIn] = [], onClose: @escaping () -> Void) {
        self.token = token
        self.providers = providers
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Wedstrijd voor je account", bundle: textBundle)
                        .font(SharedFonts.system(18, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Sluiten")) { onClose() }
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                if done {
                    Text("De wedstrijd staat in je account en telt mee.", bundle: textBundle)
                        .font(SharedFonts.system(14))
                        .foregroundColor(SharedColors.positive)
                } else if account.profile != nil {
                    Text("Iemand heeft een wedstrijd met jou gedeeld. Voeg hem toe, dan telt hij mee voor je badges.", bundle: textBundle)
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ActionButton(loc("TOEVOEGEN AAN MIJN ACCOUNT"), style: .filled, color: SharedColors.accent, disabled: busy) { claim() }
                } else {
                    Text("Log eerst in of maak een account. Daarna kun je de wedstrijd hier toevoegen.", bundle: textBundle)
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    SharedAccountSection(providers: providers)
                }
                if busy { ProgressView() }
                if let message {
                    Text(message)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.error)
                }
            }
            .padding(20)
        }
        .background(SharedColors.background.ignoresSafeArea())
    }

    private func claim() {
        busy = true
        message = nil
        Task {
            do {
                _ = try await account.claimLink(token)
                done = true
            } catch let error as AccountError {
                message = error == AccountError.notFound ? loc("Deze wedstrijd is al toegevoegd, of de link is verlopen.") : error.message
            } catch {
                message = AccountError.noConnection.message
            }
            busy = false
        }
    }
}
