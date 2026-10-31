import SwiftUI
import SquashAnalyzerCore

// 4.0, behind Features.shared.playerAccount (docs/voorstel-spelersaccount-4.0.md):
// Instellingen → Mijn account, on iOS and Android. It opens under its row like
// the other parts of Instellingen. Signed out: sign in or make a Firebase login.
// Signed in without an account: "Dit ben ik", birth year (16+) and consent.
// With an account: the player code to hand out, the inbox (Gebruiken, Niet
// gebruiken, Blokkeren), signing out and deleting the account. With the switch
// off the row is not there at all; nothing here runs.

/// Signing in with Apple (iOS) or Google: supplied by the platform, nil hides the button
public struct AccountProviderSignIn: Identifiable {
    public let title: String
    /// Starts the platform's sign-in and gives Firebase's provider id, the
    /// provider's ID token and the raw nonce (Apple); nil when cancelled
    public let start: (@escaping (AccountProviderToken?) -> Void) -> Void

    public init(title: String, start: @escaping (@escaping (AccountProviderToken?) -> Void) -> Void) {
        self.title = title
        self.start = start
    }

    public var id: String { title }
}

/// What a provider's sign-in gives
public struct AccountProviderToken {
    public let providerId: String
    public let idToken: String
    public let nonce: String?
    /// Sign in with Apple's authorization code: needed to revoke the token when the account is deleted
    public let authorizationCode: String?

    public init(providerId: String, idToken: String, nonce: String?, authorizationCode: String?) {
        self.providerId = providerId
        self.idToken = idToken
        self.nonce = nonce
        self.authorizationCode = authorizationCode
    }
}

public struct SharedAccountSection: View {
    /// Sign in with Apple and Google, from the platform; empty shows only e-mail
    let providers: [AccountProviderSignIn]
    /// For deleting an Apple account: a fresh Sign in with Apple, for the code to revoke
    let appleReauthorize: AccountProviderSignIn?

    @State private var registering = false
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var messageIsError = false
    // "Dit ben ik"
    @State private var name = ""
    @State private var sbnPath = ""
    @State private var birthYear = ""
    @State private var consent = false
    @State private var confirmDelete = false
    @State private var confirmBlock = false
    @State private var blockMatchId = ""
    #if os(iOS) && !SKIP
    /// The number pad has no return key: "Gereed" above it closes it
    @FocusState private var typingYear: Bool
    #endif

    private var account: PlayerAccount { PlayerAccount.shared }

    public init(providers: [AccountProviderSignIn] = [], appleReauthorize: AccountProviderSignIn? = nil) {
        self.providers = providers
        self.appleReauthorize = appleReauthorize
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !account.isConfigured {
                note(loc("Inloggen is in deze build niet ingesteld."))
            } else if !account.isSignedIn {
                signInPart
            } else if let profile = account.profile {
                accountPart(profile)
                inboxPart
                endPart
            } else if account.profileChecked {
                makeAccountPart
            } else {
                ProgressView()
            }
            if busy {
                ProgressView()
            }
            if let message {
                Text(message)
                    .font(SharedFonts.system(12))
                    .foregroundColor(messageIsError ? SharedColors.error : SharedColors.positive)
            }
        }
        .onAppear { refresh() }
        .alert(loc("Account verwijderen?"), isPresented: $confirmDelete) {
            Button(loc("Verwijderen"), role: .destructive) { deleteAccount() }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text("Je wedstrijden, verzoeken en badges op de server worden meteen gewist. Wat op deze telefoon staat blijft.", bundle: textBundle)
        }
        .alert(loc("Afzender blokkeren?"), isPresented: $confirmBlock) {
            Button(loc("Blokkeren"), role: .destructive) { answer(blockMatchId, use: false, block: true) }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text("Deze wedstrijd wordt gewist en van deze telefoon krijg je geen verzoeken meer.", bundle: textBundle)
        }
    }

    // MARK: Signed out

    private var signInPart: some View {
        VStack(alignment: .leading, spacing: 12) {
            note(loc("Met een account komen wedstrijden die je coach of de scheidsrechter invoert bij jou terecht. Jij kiest per wedstrijd of hij meetelt. Een account is niet nodig om de app te gebruiken."))
            Picker(loc("Account"), selection: $registering) {
                Text("Inloggen", bundle: textBundle).tag(false)
                Text("Account maken", bundle: textBundle).tag(true)
            }
            .pickerStyle(.segmented)
            field(loc("E-mailadres"), text: $email)
                #if os(iOS) || SKIP
                .keyboardType(.emailAddress)
                #endif
                #if os(iOS) && !SKIP
                .textInputAutocapitalization(.never)
                #endif
            SecureField(loc("Wachtwoord"), text: $password)
                .accessibilityLabel(loc("Wachtwoord"))
                .foregroundColor(SharedColors.textPrimary)
                .padding()
                .background(SharedColors.tint(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            ActionButton(registering ? loc("ACCOUNT MAKEN") : loc("INLOGGEN"), style: .filled, color: SharedColors.accent,
                         disabled: busy || email.isEmpty || password.isEmpty) { signIn() }
            if !registering {
                Button(loc("Wachtwoord vergeten")) { resetPassword() }
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
                    .disabled(busy)
            }
            ForEach(providers) { provider in
                ActionButton(provider.title, style: .outlined, color: SharedColors.textPrimary, disabled: busy) {
                    signIn(with: provider)
                }
            }
        }
    }

    // MARK: Signed in, no account yet

    private var teamPlayers: [LeaguePlayer] { PlayerAccount.mijnTeamPlayers() }

    private var makeAccountPart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dit ben ik", bundle: textBundle)
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            if !teamPlayers.isEmpty {
                note(loc("Speel je in Mijn team? Kies jezelf, dan komen teamwedstrijden vanzelf bij je terecht."))
                ForEach(teamPlayers) { player in
                    Button {
                        name = player.name
                        sbnPath = player.id
                    } label: {
                        HStack {
                            Text(player.name).font(SharedFonts.system(14))
                            Spacer()
                            if sbnPath == player.id {
                                AppSymbol("star.fill", size: 12, color: SharedColors.accent)
                            }
                        }
                        .foregroundColor(sbnPath == player.id ? SharedColors.accent : SharedColors.textPrimary)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                note(loc("Of vul alleen je naam in:"))
            }
            field(loc("Je naam"), text: Binding(get: { name }, set: { value in
                name = value
                // A typed name is not the chosen SBN player any more
                if let chosen = teamPlayers.first(where: { player in player.id == sbnPath }), chosen.name != value { sbnPath = "" }
            }))
            HStack(spacing: 12) {
                field(loc("Geboortejaar"), text: $birthYear)
                    #if os(iOS) || SKIP
                    .keyboardType(.numberPad)
                    #endif
                    #if os(iOS) && !SKIP
                    .focused($typingYear)
                    #endif
                #if os(iOS) && !SKIP
                // Instellingen has no navigation bar, so no keyboard toolbar either
                if typingYear {
                    Button(loc("Gereed")) { typingYear = false }
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                #endif
            }
            note(loc("Een account kan vanaf 16 jaar. Het geboortejaar wordt alleen daarvoor bewaard."))
            Toggle(isOn: $consent) {
                Text("Ik geef toestemming", bundle: textBundle)
                    .font(SharedFonts.system(14))
                    .foregroundColor(SharedColors.textPrimary)
            }
            .tint(SharedColors.accent)
            note(loc("Bewaard worden: je e-mailadres (bij Firebase, van Google), je naam, je geboortejaar en de wedstrijden die je goedkeurt, met per rally wie won, hoe en waar. In de EU, bij Cloudflare. Notities, advies en foto's blijven op de telefoon. Je kunt het account altijd verwijderen; dan is alles meteen weg."))
            ActionButton(loc("ACCOUNT MAKEN"), style: .filled, color: SharedColors.accent,
                         disabled: busy || !consent || name.isEmpty || birthYear.isEmpty) { makeAccount() }
            Button(loc("Uitloggen")) { signOut() }
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
        }
    }

    // MARK: The account

    private func accountPart(_ profile: AccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(profile.name)
                .font(SharedFonts.system(16, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            if let session = account.session, !session.email.isEmpty {
                Text(session.email)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
            }
            Text("Je spelerscode", bundle: textBundle)
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
                .padding(.top, 6)
            Text(AccountProfile.spaced(profile.code))
                .font(SharedFonts.system(22, weight: .bold, design: .monospaced))
                .foregroundColor(SharedColors.accent)
                #if !SKIP
                .textSelection(.enabled)
                #endif
            note(loc("Geef deze code aan je coach of de scheidsrechter. Dan kunnen ze wedstrijden naar je sturen."))
        }
    }

    private var inboxPart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Postvak", bundle: textBundle)
                    .font(SharedFonts.system(14, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Spacer()
                Button(loc("Vernieuwen")) { refresh(force: true) }
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

    private var endPart: some View {
        VStack(alignment: .leading, spacing: 10) {
            ActionButton(loc("UITLOGGEN"), style: .outlined, color: SharedColors.textSecondary, disabled: busy) { signOut() }
            ActionButton(loc("ACCOUNT VERWIJDEREN"), style: .text, color: SharedColors.error, disabled: busy) { confirmDelete = true }
        }
        .padding(.top, 10)
    }

    // MARK: Parts

    private func note(_ text: String) -> some View {
        Text(text)
            .font(SharedFonts.system(12))
            .foregroundColor(SharedColors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .accessibilityLabel(title)
            .autocorrectionDisabled()
            .foregroundColor(SharedColors.textPrimary)
            .padding()
            .background(SharedColors.tint(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
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

    private func refresh(force: Bool = false) {
        guard account.isConfigured, account.isSignedIn else { return }
        if !force && account.profileChecked && account.profile == nil { return }
        run(nil) {
            if force || !account.profileChecked { try await account.loadProfile() }
            if account.profile != nil {
                try await account.loadInbox()
                await account.sendOutbox()
            }
        }
    }

    private func signIn() {
        let typedEmail = email
        let typedPassword = password
        let making = registering
        run(making ? loc("Je login is gemaakt. Je krijgt een mail om je adres te bevestigen.") : nil) {
            if making {
                try await account.register(email: typedEmail, password: typedPassword)
            } else {
                try await account.signIn(email: typedEmail, password: typedPassword)
            }
            password = ""
            if account.profile != nil { try await account.loadInbox() }
        }
    }

    private func signIn(with provider: AccountProviderSignIn) {
        provider.start { token in
            guard let token else { return }
            run(nil) {
                try await account.signIn(providerId: token.providerId, idToken: token.idToken, nonce: token.nonce)
                if account.profile != nil { try await account.loadInbox() }
            }
        }
    }

    private func resetPassword() {
        let typedEmail = email
        if typedEmail.isEmpty {
            message = loc("Vul eerst je e-mailadres in.")
            messageIsError = true
            return
        }
        run(loc("Als er een account met dit adres is, krijg je een mail om een nieuw wachtwoord te kiezen.")) {
            try await account.sendPasswordReset(email: typedEmail)
        }
    }

    private func makeAccount() {
        guard let year = Int(birthYear.trimmingCharacters(in: .whitespaces)), year > 1900 else {
            message = loc("Vul je geboortejaar in, bijvoorbeeld 1990.")
            messageIsError = true
            return
        }
        let chosenName = name
        let chosenPath = sbnPath
        let given = consent
        run(loc("Je account is gemaakt.")) {
            try await account.createAccount(name: chosenName, birthYear: year, sbnPath: chosenPath, consent: given)
            try await account.loadInbox()
        }
    }

    private func answer(_ matchId: String, use: Bool, block: Bool) {
        run(use ? loc("De wedstrijd telt mee.") : nil) {
            try await account.answer(matchId: matchId, use: use, block: block)
        }
    }

    private func signOut() {
        account.signOut()
        message = nil
        password = ""
    }

    private func deleteAccount() {
        if account.session?.provider == "apple.com", let appleReauthorize {
            // Apple wants its token revoked: a fresh Sign in with Apple gives the code for that
            appleReauthorize.start { token in
                guard let token else { return }
                run(loc("Je account is verwijderd.")) {
                    try await account.deleteAccount(appleAuthorizationCode: token.authorizationCode)
                }
            }
            return
        }
        run(loc("Je account is verwijderd.")) {
            try await account.deleteAccount()
        }
    }
}
