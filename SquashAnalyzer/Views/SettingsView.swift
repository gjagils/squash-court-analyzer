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
    /// What is typed; only a valid link is saved, cleaned up (as on Android)
    @State private var teamDraft = ""
    @AppStorage(AutomaticBackup.enabledKey) private var automaticBackup = true
    @AppStorage(CourtLayout.storageKey) private var courtLayout = CourtLayout.six.rawValue
    @AppStorage(LiveShare.enabledKey) private var liveSharing = true
    @AppStorage(LiveShare.photosKey) private var livePhotos = true

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(spacing: 24) {
                        manualSection

                        courtSection

                        liveSection

                        teamSection

                        backupSection

                        // AI Coach Section
                        aiCoachSection

                        // Info Section
                        infoSection
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
        .alert("API key niet opgeslagen", isPresented: $keySaveFailed) {
            Button("OK") {}
        } message: {
            Text("De sleutel kon niet in de iPhone-sleutelhanger worden bewaard. Probeer het opnieuw.")
        }
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "person.3.fill").foregroundColor(AppColors.warmOrange); Text("Mijn team").font(AppFonts.label(16)).foregroundColor(AppColors.textPrimary) }
            Text("Vul de openbare teamlink van sbn.toernooi.nl in. Daarna verschijnt Mijn team op het beginscherm.")
                .font(AppFonts.body(13)).foregroundColor(AppColors.textSecondary)
            TextField("https://sbn.toernooi.nl/league/.../team/...", text: $teamDraft)
                .font(AppFonts.body(13)).foregroundColor(AppColors.textPrimary)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding().background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            HStack(spacing: 12) {
                ActionButton("BEWAAR TEAMLINK", style: .filled, color: AppColors.warmOrange) {
                    do {
                        let link = try LeagueTeamLink(teamDraft)
                        teamURL = link.url.absoluteString
                        teamDraft = teamURL
                        teamSaveMessage = "Teamlink opgeslagen"
                    } catch {
                        teamSaveMessage = (error as? LeagueTeamError)?.message ?? LeagueTeamError.invalidLink.message
                    }
                }
                if !teamURL.isEmpty {
                    ActionButton("VERWIJDER", color: AppColors.textSecondary) {
                        teamURL = ""
                        teamDraft = ""
                        teamSaveMessage = "Teamlink verwijderd"
                    }
                }
            }
            if let teamSaveMessage { Text(teamSaveMessage).font(AppFonts.caption(12)).foregroundColor(teamSaveMessage.hasPrefix("Teamlink") ? AppColors.positive : AppColors.warmRed) }
        }.padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03))).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Terug")
                }
                .font(AppFonts.body(14))
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("Instellingen")
                .font(PageTitleStyle.font)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            // Placeholder for symmetry
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Terug")
            }
            .font(AppFonts.body(14))
            .foregroundColor(.clear)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Manual Section
    /// The iPhone manual on the website (Android links to its own page)
    private var manualSection: some View {
        Link(destination: UserManual.iPhone) {
            HStack(spacing: 12) {
                Image(systemName: "book").foregroundColor(AppColors.warmOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Handleiding").font(AppFonts.label(16)).foregroundColor(AppColors.textPrimary)
                    Text("Per tegel uitgelegd hoe alles werkt, op squashanalyzer.com")
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .accessibilityLabel("Open de handleiding")
    }

    // MARK: - Court Section
    private var courtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3").foregroundColor(AppColors.warmOrange)
                Text("Baanindeling").font(AppFonts.label(16)).foregroundColor(AppColors.textPrimary)
            }
            Picker("Baanindeling", selection: $courtLayout) {
                Text("6 vakken").tag(CourtLayout.six.rawValue)
                Text("9 vakken").tag(CourtLayout.nine.rawValue)
            }
            .pickerStyle(.segmented)
            // Dark segments so the unselected "9 vakken" stays readable on the dark card
            .environment(\.colorScheme, .dark)
            Text("Bij 6 vakken kies je voor, midden of achter, links of rechts; bij 9 komt er een middenkolom bij. De slagen die je ziet passen bij de rij van het vak: voorin Drop, Boast en Kill, in het midden Kill, Drive, Cross en Boast, achterin Drive, Cross en Lob.")
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Live Section
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(AppColors.warmOrange)
                Text("Live meekijken").font(AppFonts.label(16)).foregroundColor(AppColors.textPrimary)
            }
            Toggle(isOn: $liveSharing) {
                Text("Knop LIVE bij Coach en Scheidsrechter")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.warmOrange)
            Toggle(isOn: $livePhotos) {
                Text("Foto's van de spelers meesturen")
                    .font(AppFonts.label(14))
                    .foregroundColor(liveSharing ? AppColors.textPrimary : AppColors.textMuted)
            }
            .tint(AppColors.warmOrange)
            .disabled(!liveSharing)
            Text("Met LIVE deel je een link, bijvoorbeeld in de WhatsApp-groep; wie erop tikt ziet de stand live in de browser. Alleen voornamen, de stand en (als je dat aan laat) een kleine foto van de spelers; 2 uur na de wedstrijd wordt alles gewist.")
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Backup Section
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "icloud.and.arrow.up").foregroundColor(AppColors.warmOrange)
                Text("Back-up").font(AppFonts.label(16)).foregroundColor(AppColors.textPrimary)
            }
            Toggle(isOn: $automaticBackup) {
                Text("Wekelijkse back-up naar iCloud")
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
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var backupFootnote: String {
        var text = "Eén keer per week, als je de app na gebruik wegzet, komt er een back-up in iCloud Drive (Bestanden → iCloud Drive → Squash Analyzer). De 7 nieuwste blijven bewaard. Ook terug te zetten op Android."
        if let last = AutomaticBackup.lastBackup {
            text += " Laatste: \(last.formatted(date: .abbreviated, time: .shortened))."
        }
        return text
    }

    // MARK: - AI Coach Section
    private var aiCoachSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(AppColors.accentGold)
                Text("AI Coach")
                    .font(AppFonts.label(16))
                    .foregroundColor(AppColors.textPrimary)
            }

            Text("Voeg je OpenAI API key toe voor gepersonaliseerd tactisch advies van de AI Coach.")
                .font(AppFonts.body(13))
                .foregroundColor(AppColors.textSecondary)

            // API Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("OPENAI API KEY")
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
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.accentGold.opacity(0.4), lineWidth: 1)
                )
            }

            // Save Button
            ActionButton(showingSaveConfirmation ? "OPGESLAGEN!" : "BEWAAR API KEY", style: .filled,
                         color: showingSaveConfirmation ? SharedColors.positive : AppColors.accentGold) {
                saveAPIKey()
            }

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(APIKeyManager.shared.hasOpenAIKey ? AppColors.positive : AppColors.warmRed)
                    .frame(width: 8, height: 8)
                Text(APIKeyManager.shared.hasOpenAIKey ? "API key geconfigureerd" : "Geen API key ingesteld")
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.steelBlue)
                Text("Over AI Coach")
                    .font(AppFonts.label(16))
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "lock.shield",
                    title: "Veilig",
                    description: "Je API key wordt veilig opgeslagen in de Keychain"
                )

                InfoRow(
                    icon: "dollarsign.circle",
                    title: "Kosten",
                    description: "~€0.01 per analyse (het goedkoopste beschikbare model)"
                )

                InfoRow(
                    icon: "wifi",
                    title: "Internet vereist",
                    description: "AI advies werkt alleen met internetverbinding"
                )

                InfoRow(
                    icon: "cpu",
                    title: "Lokaal advies",
                    description: "Basis advies werkt altijd, ook zonder API key"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
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
                ActionButton("NU NAAR ICLOUD", color: AppColors.warmOrange) { saveToiCloud() }
                ActionButton("TERUGZETTEN", color: AppColors.warmOrange) { showingBackupImporter = true }
            }
            .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.json]) { result in
                if let data = read(result) {
                    pendingBackupData = data
                    showingReplaceConfirm = true
                }
            }
            HStack(spacing: 10) {
                ActionButton("DELEN", color: AppColors.textSecondary) { shareBackup() }
                ActionButton("WEDSTRIJD IMPORTEREN", color: AppColors.textSecondary) { showingMatchImporter = true }
            }
            .fileImporter(isPresented: $showingMatchImporter, allowedContentTypes: [.json]) { result in
                guard let data = read(result) else { return }
                do {
                    try ExportService.importFromJSON(data, context: modelContext)
                    show("Import gelukt!", "De wedstrijd is geïmporteerd.")
                } catch {
                    show("Import mislukt", error.localizedDescription)
                }
            }
        }
        .alert("Alles vervangen?", isPresented: $showingReplaceConfirm) {
            Button("Vervang alles", role: .destructive) { restore(replacing: true) }
            Button("Voeg toe", role: .cancel) { restore(replacing: false) }
        } message: {
            Text("Wil je alle bestaande data verwijderen en vervangen door de back-up, of de back-up toevoegen aan wat er al is?")
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
                show("Import mislukt", "Geen toegang tot bestand")
                return nil
            }
            defer { url.stopAccessingSecurityScopedResource() }
            return try Data(contentsOf: url)
        } catch {
            show("Import mislukt", error.localizedDescription)
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
            show("Back-up mislukt", error.localizedDescription)
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
                show("Back-up opgeslagen!", "'\(url.lastPathComponent)' staat in iCloud Drive, in de Bestanden-app onder iCloud Drive → Squash Analyzer.")
            case .failure(let error):
                show("Back-up mislukt", error.localizedDescription)
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
            show("Back-up mislukt", error.localizedDescription)
        }
    }

    private func restore(replacing: Bool) {
        guard let data = pendingBackupData else { return }
        pendingBackupData = nil
        do {
            if replacing {
                let result = try ExportService.replaceWithBackup(data, context: modelContext)
                show("Back-up hersteld", "\(result.players) spelers, \(result.matches) wedstrijden, \(result.games) losse games.")
            } else {
                let result = try ExportService.importFullBackup(data, context: modelContext)
                show("Back-up toegevoegd", "\(result.players) spelers, \(result.matches) wedstrijden, \(result.games) losse games.")
            }
        } catch {
            show("Terugzetten mislukt", error.localizedDescription)
        }
    }
}
