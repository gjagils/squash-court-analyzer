import SwiftUI
import SquashAnalyzerCore

// 4.0, behind Features.shared.playerAccount (docs/voorstel-spelersaccount-4.0.md):
// Instellingen → Mijn account, on iOS and Android. It opens under its row like
// the other parts of Instellingen. Signed out: sign in or make a Firebase login.
// Signed in without an account: "Dit ben ik", birth year (16+) and consent.
// With an account: the name (to correct), who you are in SBN, the inbox
// (Gebruiken, Niet gebruiken, Blokkeren), the team's matches that wait for a
// name ("Ben jij dit?"), signing out and deleting the account. No player code:
// coaches send to your SBN player or to the name they use in your team. With
// the switch off the row is not there at all; nothing here runs.

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

/// Android: the sign-in form came on screen or left it. Every other text field
/// is kept out of autofill there (`AutofillGate.kt`), so the password manager
/// does not offer the account password on a name field. nil on iOS, where a
/// field without a content type is left alone.
public enum LoginAutofill {
    @MainActor public static var onLoginVisible: ((Bool) -> Void)? = nil
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
    @State private var confirmAvatar = false
    // Correcting the name
    @State private var editingName = false
    @State private var newName = ""
    // A new e-mail address (password accounts)
    @State private var editingEmail = false
    @State private var newEmail = ""
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
                    .onAppear { LoginAutofill.onLoginVisible?(true) }
                    .onDisappear { LoginAutofill.onLoginVisible?(false) }
            } else if let profile = account.profile {
                accountPart(profile)
                SharedAccountInbox()
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
                    .foregroundColor(messageIsError ? SharedColors.error : SharedColors.support)
            }
        }
        .onAppear { refresh() }
        .alert(loc("Je foto delen?"), isPresented: $confirmAvatar) {
            Button(loc("Foto kiezen")) { pickAvatar() }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text("Wie jou als speler of tegenspeler kiest, ziet deze foto bij jou in de app. Je kunt hem altijd weer verwijderen.", bundle: textBundle)
        }
        .alert(loc("Account verwijderen?"), isPresented: $confirmDelete) {
            Button(loc("Verwijderen"), role: .destructive) { deleteAccount() }
            Button(loc("Annuleren"), role: .cancel) { }
        } message: {
            Text("Je wedstrijden, verzoeken en badges op de server worden meteen gewist. Wat op deze telefoon staat blijft.", bundle: textBundle)
        }
    }

    // MARK: Signed out

    private var signInPart: some View {
        VStack(alignment: .leading, spacing: 12) {
            note(loc("Met een account zie je de teamwedstrijd van je team meteen en doe je met één tik mee. Partijen die een teamgenoot, coach of scheidsrechter van jou bijhoudt, komen bij jou binnen; jij kiest per wedstrijd of hij meetelt voor je badges. Een account is niet nodig om de app te gebruiken."))
            Picker(loc("Account"), selection: $registering) {
                Text("Inloggen", bundle: textBundle).tag(false)
                Text("Account maken", bundle: textBundle).tag(true)
            }
            .pickerStyle(.segmented)
            field(loc("E-mailadres"), text: $email)
                // Only these two fields tell Android autofill what they are (docs/skip-valkuilen.md)
                .textContentType(.username)
                #if os(iOS) || SKIP
                .keyboardType(.emailAddress)
                #endif
                #if os(iOS) && !SKIP
                .textInputAutocapitalization(.never)
                #endif
            SecureField(loc("Wachtwoord"), text: $password)
                .textContentType(registering ? .newPassword : .password)
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
            note(loc("Bewaard worden: je e-mailadres (bij Firebase, van Google), je naam, je geboortejaar en de wedstrijden die je goedkeurt, met per rally wie won, hoe en waar. In de EU, bij Cloudflare. Notities, advies en de foto's van je spelers blijven op de telefoon. Je eigen foto staat alleen bij je account als je die zelf kiest. Je kunt het account altijd verwijderen; dan is alles meteen weg."))
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
            if editingName {
                field(loc("Je naam"), text: $newName)
                HStack(spacing: 8) {
                    ActionButton(loc("BEWAREN"), style: .filled, color: SharedColors.accent,
                                 disabled: busy || newName.trimmingCharacters(in: .whitespaces).isEmpty) { saveName() }
                    ActionButton(loc("ANNULEREN"), style: .outlined, color: SharedColors.textSecondary, disabled: busy) {
                        editingName = false
                    }
                }
            } else {
                HStack {
                    Text(profile.name)
                        .font(SharedFonts.system(16, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Naam wijzigen")) {
                        newName = profile.name
                        editingName = true
                    }
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
                }
            }
            emailPart
            sbnPart(profile)
            avatarPart(profile)
        }
    }

    /// The sign-in address, and changing it (password accounts): a link goes to
    /// the new address, and the old one gets a mail that can undo it
    @ViewBuilder
    private var emailPart: some View {
        if editingEmail {
            field(loc("Nieuw e-mailadres"), text: $newEmail)
                #if os(iOS) || SKIP
                .keyboardType(.emailAddress)
                #endif
            HStack(spacing: 8) {
                ActionButton(loc("BEWAREN"), style: .filled, color: SharedColors.accent,
                             disabled: busy || newEmail.trimmingCharacters(in: .whitespaces).isEmpty) { changeEmail() }
                ActionButton(loc("ANNULEREN"), style: .outlined, color: SharedColors.textSecondary, disabled: busy) {
                    editingEmail = false
                }
            }
        } else if let session = account.session, !session.email.isEmpty {
            HStack {
                Text(session.email)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                Spacer()
                if account.canChangeEmail {
                    Button(loc("E-mailadres wijzigen")) {
                        newEmail = ""
                        editingEmail = true
                    }
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
                }
            }
            if let pending = account.pendingEmail {
                Text(loc("Wacht op bevestiging: \(pending). Tik op de link in die mail."))
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textMuted)
            } else if account.needsEmailVerification {
                // A reminder, not a block (Gerd-Jan 11 November 2026): the account works anyway
                note(loc("Je e-mailadres is nog niet bevestigd. Tik op de link in de mail die we je stuurden."))
                Button(loc("Bevestigmail opnieuw sturen")) { resendVerification(to: session.email) }
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
                    .disabled(busy)
            }
        }
    }

    /// Your avatar (4.0, Gerd-Jan 10 November 2026): whoever picks you as a
    /// player, linked to your SBN player, sees it in their app
    @ViewBuilder
    private func avatarPart(_ profile: AccountProfile) -> some View {
        if account.avatarSource != nil {
            HStack(spacing: 14) {
                PlayerPhotoView(photo: account.ownAvatar, name: profile.name, size: 56, color: SharedColors.textSecondary)
                VStack(alignment: .leading, spacing: 6) {
                    Button(account.ownAvatar == nil ? loc("Foto kiezen") : loc("Andere foto")) { confirmAvatar = true }
                        .font(SharedFonts.system(13, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                        .disabled(busy)
                    if account.ownAvatar != nil {
                        Button(loc("Foto verwijderen")) { removeAvatar() }
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                            .disabled(busy)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            note(profile.sbnPath == nil
                 ? loc("Je foto: kies eerst wie je in SBN bent, dan zien je teamgenoten en tegenstanders hem bij jou in hun app.")
                 : loc("Je foto: wie jou als speler of tegenspeler kiest, ziet hem bij jou in zijn app. Verwijderen kan altijd."))
            .task(id: profile.avatarVersion ?? Int64(0)) { try? await account.loadOwnAvatar() }
        }
    }

    /// Who you are in SBN: set once, from Mijn team
    private func sbnPart(_ profile: AccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let path = profile.sbnPath {
                let chosen = teamPlayers.first { player in player.id == path }?.name ?? loc("gekoppeld")
                Text(loc("In SBN: \(chosen)"))
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textPrimary)
                note(loc("Wedstrijden die je coach of de scheidsrechter met jou invult, komen hier binnen. Ook als ze je in hun app anders noemen."))
            } else if !teamPlayers.isEmpty {
                note(loc("Wie ben jij in Mijn team? Kies jezelf, dan komen wedstrijden met jou vanzelf hier binnen. Dit kan één keer."))
                ForEach(teamPlayers) { player in
                    Button {
                        chooseSbnPlayer(player)
                    } label: {
                        Text(player.name)
                            .font(SharedFonts.system(14))
                            .foregroundColor(SharedColors.textPrimary)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
            } else {
                note(loc("Speel je in een SBN-team? Kies je team bij Mijn team; dan kun je hier zeggen wie je bent."))
            }
        }
        .padding(.top, 6)
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

    private func resendVerification(to address: String) {
        run(loc("We hebben de mail opnieuw gestuurd naar \(address).")) {
            try await account.resendVerification()
        }
    }

    private func refresh(force: Bool = false) {
        guard account.isConfigured, account.isSignedIn else { return }
        if !force && account.profileChecked && account.profile == nil { return }
        run(nil) {
            // A new address that waits for its link: a fresh token shows whether it went through
            // The same for an address that is not confirmed yet
            if account.pendingEmail != nil || account.needsEmailVerification { try await account.refreshEmail() }
            if force || !account.profileChecked { try await account.loadProfile() }
            if account.profile != nil {
                try await account.loadInbox()
                await account.sendOutbox()
                await AccountSync.shared.run()
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
            if account.profile != nil {
                try await account.loadInbox()
                await AccountSync.shared.run()
            }
        }
    }

    private func signIn(with provider: AccountProviderSignIn) {
        provider.start { token in
            guard let token else { return }
            run(nil) {
                try await account.signIn(providerId: token.providerId, idToken: token.idToken, nonce: token.nonce)
                if account.profile != nil {
                    try await account.loadInbox()
                    await AccountSync.shared.run()
                }
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

    private func changeEmail() {
        let typed = newEmail.trimmingCharacters(in: .whitespaces)
        run(loc("We hebben een mail gestuurd naar \(typed). Tik op de link om je nieuwe adres te bevestigen.")) {
            try await account.changeEmail(to: typed)
            editingEmail = false
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

    private func saveName() {
        let typed = newName
        run(nil) {
            try await account.updateAccount(name: typed)
            editingName = false
        }
    }

    private func chooseSbnPlayer(_ player: LeaguePlayer) {
        run(nil) {
            try await account.updateAccount(sbnPath: player.id)
            try await account.loadInbox()
        }
    }

    private func pickAvatar() {
        guard let source = account.avatarSource else { return }
        Task {
            // Let the question close first: a picker cannot open over a closing alert
            try? await Task.sleep(nanoseconds: 450_000_000)
            let picked: Data?
            do {
                picked = try await source.pickAvatar()
            } catch {
                message = loc("Deze foto kan niet worden gebruikt.")
                messageIsError = true
                return
            }
            guard let picked else { return }
            run(loc("Je foto staat bij je account.")) {
                try await account.setAvatar(picked)
            }
        }
    }

    private func removeAvatar() {
        run(loc("Je foto is verwijderd.")) {
            try await account.deleteAvatar()
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
