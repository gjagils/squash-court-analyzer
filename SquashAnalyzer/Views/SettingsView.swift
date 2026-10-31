import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

/// Settings keys shared with other screens
enum CoachInputSettings {
    static let teamURLKey = "sbnTeamURL"
}

/// Settings view for managing app configuration
struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var showingAPIKey = false
    @State private var showingSaveConfirmation = false
    @State private var keySaveFailed = false
    @AppStorage(CoachInputSettings.teamURLKey) private var teamURL = ""
    @State private var teamSaveMessage: String?
    /// The message above is the success one (green), not an error (red)
    @State private var teamSaved = false
    /// What is typed; only a valid link is saved, cleaned up (as on Android)
    @State private var teamDraft = ""
    @AppStorage(AutomaticBackup.enabledKey) private var automaticBackup = true
    @AppStorage(CourtLayout.storageKey) private var courtLayout = CourtLayout.six.rawValue
    @AppStorage(CoachInputMode.storageKey) private var coachInput = CoachInputMode.detailed.rawValue
    @AppStorage(LiveShare.enabledKey) private var liveSharing = true
    @AppStorage(LiveShare.photosKey) private var livePhotos = true
    @AppStorage(LiveFollow.ownMatchKey) private var lockScreenScore = true
    @AppStorage(LiveFollow.alertsKey) private var liveAlerts = true
    @Environment(\.openURL) private var openURL
    /// The part of Instellingen that is open; one at a time
    @State private var openPart: String? = nil

    private func toggle(_ part: String) {
        withAnimation(.easeInOut(duration: 0.2)) { openPart = openPart == part ? nil : part }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // As the home screen (Gerd-Jan, 21 October 2026): the manual in a card,
                        // then a line per part that opens underneath, one at a time
                        SettingsManualCard(manual: UserManual.iPhone)
                            .padding(.bottom, 16)
                        SettingsRow(appText("Mijn team"), icon: "person.2", open: openPart == "team") { toggle("team") }
                        if openPart == "team" { teamSection.padding(.bottom, 16) }
                        SettingsDivider()
                        SettingsRow(appText("Weergave"), icon: "circle.lefthalf.filled", open: openPart == "theme") { toggle("theme") }
                        if openPart == "theme" { AppearancePicker(showsTitle: false).padding(.bottom, 16) }
                        SettingsDivider()
                        // Telefoon, Nederlands or English, for the whole app at once
                        SettingsRow(appText("Taal"), icon: "globe", open: openPart == "language") { toggle("language") }
                        if openPart == "language" {
                            LanguagePicker { code in AppLanguageChoice.apply(code) }.padding(.bottom, 16)
                        }
                        SettingsDivider()
                        // Uitgebreid or Eenvoudig coachen (the shared picker, as on Android)
                        SettingsRow(appText("Coachen"), icon: "list.bullet.clipboard", open: openPart == "coach") { toggle("coach") }
                        if openPart == "coach" {
                            CoachInputModePicker(selection: $coachInput)
                                .environment(\.colorScheme, SharedColors.colorScheme)
                                .padding(.bottom, 16)
                        }
                        SettingsDivider()
                        SettingsRow(appText("Baanindeling"), icon: "square.grid.3x3", open: openPart == "court") { toggle("court") }
                        if openPart == "court" { courtSection.padding(.bottom, 16) }
                        SettingsDivider()
                        SettingsRow(appText("Live meekijken"), icon: "dot.radiowaves.left.and.right", open: openPart == "live") { toggle("live") }
                        if openPart == "live" { liveSection.padding(.bottom, 16) }
                        SettingsDivider()
                        SettingsRow(appText("Back-up"), icon: "icloud.and.arrow.up", open: openPart == "backup") { toggle("backup") }
                        if openPart == "backup" { backupSection.padding(.bottom, 16) }
                        SettingsDivider()
                        SettingsRow(appText("AI Coach"), icon: "brain", open: openPart == "ai") { toggle("ai") }
                        if openPart == "ai" {
                            VStack(alignment: .leading, spacing: 20) {
                                aiCoachSection
                                infoSection
                            }
                            .padding(.bottom, 16)
                        }
                        SettingsDivider()
                        AboutAppSection(appVersion: Self.appVersion, manual: UserManual.iPhone)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .onAppear {
            apiKey = APIKeyManager.shared.openAIAPIKey ?? ""
            teamDraft = teamURL
        }
        .alert(Text(appText("API key niet opgeslagen")), isPresented: $keySaveFailed) {
            Button("OK") {}
        } message: {
            Text(appText("De sleutel kon niet in de iPhone-sleutelhanger worden bewaard. Probeer het opnieuw."))
        }
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appText("Vul de openbare teamlink van sbn.toernooi.nl in. Daarna verschijnt Mijn team op het beginscherm."))
                .font(AppFonts.body(13)).foregroundColor(AppColors.textSecondary)
            Link(destination: UserManual.iPhoneTeamLink) {
                Text(appText("Waar vind ik mijn teamlink?")).font(AppFonts.label(13)).foregroundColor(AppColors.warmOrange)
            }
            TextField("https://sbn.toernooi.nl/league/.../team/...", text: $teamDraft)
                .font(AppFonts.body(13)).foregroundColor(AppColors.textPrimary)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding().background(RoundedRectangle(cornerRadius: 10).fill(SharedColors.tint(0.08)))
            HStack(spacing: 12) {
                ActionButton(appText("BEWAAR TEAMLINK"), style: .filled, color: AppColors.warmOrange) {
                    do {
                        let link = try LeagueTeamLink(teamDraft)
                        teamURL = link.url.absoluteString
                        teamDraft = teamURL
                        teamSaveMessage = appText("Teamlink opgeslagen")
                        teamSaved = true
                    } catch {
                        teamSaveMessage = (error as? LeagueTeamError)?.message ?? LeagueTeamError.invalidLink.message
                        teamSaved = false
                    }
                }
                if !teamURL.isEmpty {
                    ActionButton(appText("VERWIJDER"), color: AppColors.textSecondary) {
                        teamURL = ""
                        teamDraft = ""
                        teamSaveMessage = appText("Teamlink verwijderd")
                        teamSaved = true
                    }
                }
            }
            if let teamSaveMessage { Text(teamSaveMessage).font(AppFonts.caption(12)).foregroundColor(teamSaved ? AppColors.positive : AppColors.warmRed) }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text(appText("Terug"))
                }
                .font(AppFonts.body(14))
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(appText("Instellingen"))
                .font(PageTitleStyle.font)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            // Placeholder for symmetry
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text(appText("Terug"))
            }
            .font(AppFonts.body(14))
            .foregroundColor(.clear)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Manual Section
    /// The iPhone manual on the website (Android links to its own page)
    /// "iPhone 3.0 (2.1)", for the feedback mail
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "iPhone \(version) (\(build))"
    }

    // MARK: - Court Section
    private var courtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(appText("Baanindeling"), selection: $courtLayout) {
                Text(appText("6 vakken")).tag(CourtLayout.six.rawValue)
                Text(appText("9 vakken")).tag(CourtLayout.nine.rawValue)
            }
            .pickerStyle(.segmented)
            // Dark segments so the unselected "9 vakken" stays readable on the dark card
            .environment(\.colorScheme, SharedColors.colorScheme)
            Text(appText("Bij 6 vakken kies je voor, midden of achter, links of rechts; bij 9 komt er een middenkolom bij. De slagen die je ziet passen bij de rij van het vak: voorin Drop, Boast en Kill, in het midden Kill, Drive, Cross en Boast, achterin Drive, Cross en Lob."))
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Live Section
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $liveSharing) {
                Text(appText("Knop LIVE bij Scheidsrechter en Coach"))
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.warmOrange)
            Toggle(isOn: $livePhotos) {
                Text(appText("Foto's van de spelers meesturen"))
                    .font(AppFonts.label(14))
                    .foregroundColor(liveSharing ? AppColors.textPrimary : AppColors.textMuted)
            }
            .tint(AppColors.warmOrange)
            .disabled(!liveSharing)
            Text(appText("Met LIVE deel je een link, bijvoorbeeld in de WhatsApp-groep; wie erop tikt ziet de stand live in de browser. Alleen voornamen, de stand en (als je dat aan laat) een kleine foto van de spelers; 2 uur na de wedstrijd wordt alles gewist."))
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: $lockScreenScore) {
                Text(appText("Stand op vergrendelscherm"))
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.warmOrange)
            Text(appText("Tijdens het scoren staat de stand van je wedstrijd op het vergrendelscherm en in het Dynamic Island. Een wedstrijd van iemand anders volg je via Wedstrijd volgen op het beginscherm."))
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: Binding(get: { liveAlerts }, set: { on in
                liveAlerts = on
                // The server keeps the choice per followed match: tell it for the ones followed now
                Task { await LiveFollow.shared.setAlerts(on) }
            })) {
                Text(appText("Melding bij elke game"))
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.warmOrange)
            Text(appText("Bij een gevolgde wedstrijd: een melding met geluid als er een game is uitgespeeld en bij de uitslag. Bij een teamwedstrijd: per partij en bij de einduitslag."))
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Backup Section
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $automaticBackup) {
                Text(appText("Wekelijkse back-up naar iCloud"))
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.warmOrange)
            Text(backupFootnote)
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            BackupActionsView()
        }
    }

    private var backupFootnote: String {
        var text = appText("Eén keer per week, als je de app na gebruik wegzet, komt er een back-up in iCloud Drive (Bestanden → iCloud Drive → Squash Analyzer). De 7 nieuwste blijven bewaard. Ook terug te zetten op Android.")
        if let last = AutomaticBackup.lastBackup {
            text += appText(" Laatste: \(last.formatted(date: .abbreviated, time: .shortened)).")
        }
        return text
    }

    // MARK: - AI Coach Section
    private var aiCoachSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(appText("Voeg je OpenAI API key toe voor gepersonaliseerd tactisch advies van de AI Coach."))
                .font(AppFonts.body(13))
                .foregroundColor(AppColors.textSecondary)

            // API Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text(appText("OPENAI API KEY"))
                    .font(AppFonts.caption(11))
                    .foregroundColor(AppColors.textMuted)
                    .tracking(1)

                HStack {
                    if showingAPIKey {
                        TextField("sk-...", text: $apiKey)
                            .font(AppFonts.body(14))
                            .foregroundColor(AppColors.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .font(AppFonts.body(14))
                            .foregroundColor(AppColors.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Button(action: { showingAPIKey.toggle() }) {
                        Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SharedColors.tint(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.warmOrange.opacity(0.4), lineWidth: 1)
                )
            }

            // Save Button
            ActionButton(showingSaveConfirmation ? appText("OPGESLAGEN!") : appText("BEWAAR API KEY"), style: .filled,
                         color: showingSaveConfirmation ? SharedColors.positive : AppColors.warmOrange) {
                saveAPIKey()
            }

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(APIKeyManager.shared.hasOpenAIKey ? AppColors.positive : AppColors.warmRed)
                    .frame(width: 8, height: 8)
                Text(APIKeyManager.shared.hasOpenAIKey ? appText("API key geconfigureerd") : appText("Geen API key ingesteld"))
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textMuted)
            }
        }
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.steelBlue)
                Text(appText("Over AI Coach"))
                    .font(AppFonts.label(16))
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "lock.shield",
                    title: appText("Veilig"),
                    description: appText("Je API key wordt veilig opgeslagen in de Keychain")
                )

                InfoRow(
                    icon: "dollarsign.circle",
                    title: appText("Kosten"),
                    description: appText("~€0.01 per analyse (het goedkoopste beschikbare model)")
                )

                InfoRow(
                    icon: "wifi",
                    title: appText("Internet vereist"),
                    description: appText("AI advies werkt alleen met internetverbinding")
                )

                InfoRow(
                    icon: "cpu",
                    title: appText("Lokaal advies"),
                    description: appText("Basis advies werkt altijd, ook zonder API key")
                )
            }
        }
    }

    // MARK: - Actions
    private func saveAPIKey() {
        guard APIKeyManager.shared.setOpenAIKey(apiKey.isEmpty ? nil : apiKey) else {
            keySaveFailed = true
            return
        }
        showingSaveConfirmation = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingSaveConfirmation = false
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    /// Already in the app's language (appText)
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(SharedFonts.system(16))
                .foregroundColor(AppColors.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.label(13))
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppFonts.caption(11))
                    .foregroundColor(AppColors.textMuted)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView(isPresented: .constant(true))
}

// MARK: - Backup actions

/// Back-up now to iCloud Drive, restore one, share a backup file or import a
/// single shared match (before T20 these sat behind "…" in the iPhone's own
/// Afgeronde wedstrijden).
struct BackupActionsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingBackupImporter = false
    @State private var showingMatchImporter = false
    @State private var pendingBackupData: Data? = nil
    @State private var showingReplaceConfirm = false
    @State private var message: String? = nil
    @State private var messageTitle = ""

    var body: some View {
        // Each file picker hangs on its own row: two `.fileImporter`s on one
        // view let only the last one present, so TERUGZETTEN never opened.
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ActionButton(appText("NU NAAR ICLOUD"), color: AppColors.warmOrange) { saveToiCloud() }
                ActionButton(appText("TERUGZETTEN"), color: AppColors.warmOrange) { showingBackupImporter = true }
            }
            .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.json]) { result in
                if let data = read(result) {
                    pendingBackupData = data
                    showingReplaceConfirm = true
                }
            }
            HStack(spacing: 10) {
                ActionButton(appText("DELEN"), color: AppColors.textSecondary) { shareBackup() }
                ActionButton(appText("WEDSTRIJD IMPORTEREN"), color: AppColors.textSecondary) { showingMatchImporter = true }
            }
            .fileImporter(isPresented: $showingMatchImporter, allowedContentTypes: [.json]) { result in
                guard let data = read(result) else { return }
                do {
                    try ExportService.importFromJSON(data, context: modelContext)
                    show(appText("Import gelukt!"), appText("De wedstrijd is geïmporteerd."))
                } catch {
                    show(appText("Import mislukt"), error.localizedDescription)
                }
            }
        }
        .alert(Text(appText("Alles vervangen?")), isPresented: $showingReplaceConfirm) {
            Button(appText("Vervang alles"), role: .destructive) { restore(replacing: true) }
            Button(appText("Voeg toe"), role: .cancel) { restore(replacing: false) }
        } message: {
            Text(appText("Wil je alle bestaande data verwijderen en vervangen door de back-up, of de back-up toevoegen aan wat er al is?"))
        }
        .alert(messageTitle, isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message ?? "")
        }
    }

    private func show(_ title: String, _ text: String) {
        messageTitle = title
        message = text
    }

    private func read(_ result: Result<URL, Error>) -> Data? {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                show(appText("Import mislukt"), appText("Geen toegang tot bestand"))
                return nil
            }
            defer { url.stopAccessingSecurityScopedResource() }
            return try Data(contentsOf: url)
        } catch {
            show(appText("Import mislukt"), error.localizedDescription)
            return nil
        }
    }

    private func backupData() throws -> Data {
        try ExportService.exportFullBackup(
            players: try modelContext.fetch(FetchDescriptor<SavedPlayer>()),
            matches: try modelContext.fetch(FetchDescriptor<SavedMatch>()),
            standaloneGames: try modelContext.fetch(FetchDescriptor<SavedGame>(predicate: #Predicate { $0.match == nil })),
            badgeAwards: try modelContext.fetch(FetchDescriptor<SavedBadgeAward>()),
            refereeMatches: try modelContext.fetch(FetchDescriptor<SavedRefereeMatch>()))
    }

    /// The data is gathered here (SwiftData); finding the iCloud folder and
    /// writing happen off the main thread
    private func saveToiCloud() {
        let data: Data
        do {
            data = try backupData()
        } catch {
            show(appText("Back-up mislukt"), error.localizedDescription)
            return
        }
        Task {
            let result: Result<URL, Error> = await Task.detached(priority: .userInitiated) {
                Result {
                    guard let dir = ExportService.iCloudDirectory else { throw ExportService.iCloudError.unavailable }
                    return try ExportService.writeBackup(data, to: dir)
                }
            }.value
            switch result {
            case .success(let url):
                show(appText("Back-up opgeslagen!"),
                     appText("'\(url.lastPathComponent)' staat in iCloud Drive, in de Bestanden-app onder iCloud Drive → Squash Analyzer."))
            case .failure(let error):
                show(appText("Back-up mislukt"), error.localizedDescription)
            }
        }
    }

    private func shareBackup() {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = try ExportService.writeToTempFile(try backupData(), filename: "squash-backup-\(formatter.string(from: Date())).json")
            IOSShare.present([url])
        } catch {
            show(appText("Back-up mislukt"), error.localizedDescription)
        }
    }

    private func restore(replacing: Bool) {
        guard let data = pendingBackupData else { return }
        pendingBackupData = nil
        do {
            if replacing {
                let result = try ExportService.replaceWithBackup(data, context: modelContext)
                show(appText("Back-up hersteld"),
                     appText("\(result.players) spelers, \(result.matches) wedstrijden, \(result.games) losse games."))
            } else {
                let result = try ExportService.importFullBackup(data, context: modelContext)
                show(appText("Back-up toegevoegd"),
                     appText("\(result.players) spelers, \(result.matches) wedstrijden, \(result.games) losse games."))
            }
        } catch {
            show(appText("Terugzetten mislukt"), error.localizedDescription)
        }
    }
}

/// Instellingen → Taal on the iPhone: the choice itself is in `AppLanguage.storageKey`
/// (Core, the shared screens and the app's own texts read it at once); the widget
/// reads its copy in the app group. iOS' own alerts keep the phone's language.
enum AppLanguageChoice {
    static func apply(_ code: String) {
        let group = UserDefaults(suiteName: WidgetLanguage.group)
        if code.isEmpty {
            group?.removeObject(forKey: WidgetLanguage.storageKey)
        } else {
            group?.set(code, forKey: WidgetLanguage.storageKey)
        }
    }
}
