import SwiftUI
import SquashAnalyzerCore

// The settings screen of the shared UI (Android and the iOS covers): the team
// link of Mijn team, the AI Coach key, the live settings and the backups.
// Split off from SharedLeagueTeamViews.swift.

/// Backups in the settings: where the data comes from and goes to, and the
/// file picker (both supplied by the platform)
public struct BackupContext {
    public let store: any BackupStore
    public let files: any BackupFiles
    public let appVersion: String
    /// Daily backups into a folder the user picks; nil hides the option
    public let auto: (any AutoBackupControl)?

    public init(store: any BackupStore, files: any BackupFiles, appVersion: String, auto: (any AutoBackupControl)? = nil) {
        self.store = store
        self.files = files
        self.appVersion = appVersion
        self.auto = auto
    }
}

/// What Instellingen needs, so a screen can open it from its header
public struct SettingsContext {
    public let aiCoach: AICoachContext?
    public let backup: BackupContext?
    #if !SKIP
    /// The iPhone's own Instellingen (with iCloud back-up and the iPhone
    /// manual), so the gear opens the same screen everywhere; nil uses the
    /// shared one. Gets a closure that closes it.
    public let ownScreen: ((@escaping () -> Void) -> AnyView)?

    public init(aiCoach: AICoachContext?, backup: BackupContext?, ownScreen: ((@escaping () -> Void) -> AnyView)? = nil) {
        self.aiCoach = aiCoach
        self.backup = backup
        self.ownScreen = ownScreen
    }
    #else
    public init(aiCoach: AICoachContext?, backup: BackupContext?) {
        self.aiCoach = aiCoach
        self.backup = backup
    }
    #endif
}

/// Instellingen opened from a coach or referee header: the platform's own
/// screen when the host gave one (iPhone), else the shared screen with a close button
struct SettingsSheet: View {
    let settings: SettingsContext
    let close: () -> Void

    var body: some View {
        #if !SKIP
        if let own = settings.ownScreen {
            own(close)
        } else {
            shared
        }
        #else
        shared
        #endif
    }

    private var shared: some View {
        NavigationStack {
            SharedSettingsView(aiCoach: settings.aiCoach, backup: settings.backup)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        CloseButton { close() }
                    }
                }
        }
    }
}

/// Android's settings: the Mijn team link, the AI Coach API key and backups.
/// The coach input mode is not here because Android's coach screen has only
/// the score-tap flow.
public struct SharedSettingsView: View {
    let aiCoach: AICoachContext?
    let backup: BackupContext?

    @AppStorage(LeagueTeamStorage.linkKey) private var teamURL = ""
    @AppStorage(CourtLayout.storageKey) private var courtLayout = CourtLayout.six.rawValue
    @AppStorage(LiveShare.enabledKey) private var liveSharing = true
    @AppStorage(LiveShare.photosKey) private var livePhotos = true
    @AppStorage(LiveFollow.alertsKey) private var liveAlerts = true
    @State private var draft = ""
    @State private var message: String?
    @State private var messageIsError = false
    @State private var keyDraft = ""
    @State private var showingKey = false
    @State private var hasKey = false
    @State private var keyMessage: String?
    @State private var backupBusy = false
    @State private var backupMessage: String?
    @State private var backupIsError = false
    /// The backup picked to restore. Kept apart from `askingRestore`: the
    /// alert clears its own flag before a button's action runs (on Android).
    @State private var pendingRestore: FullBackup?
    @State private var askingRestore = false
    /// Refreshed after turning automatic backups on or off
    @State private var autoFolder: String?
    @State private var autoLast: Date?

    public init(aiCoach: AICoachContext? = nil, backup: BackupContext? = nil) {
        self.aiCoach = aiCoach
        self.backup = backup
    }

    /// The part that is open; one at a time
    @State private var openPart: String? = nil

    private func toggle(_ part: String) {
        withAnimation(.easeInOut(duration: 0.2)) { openPart = openPart == part ? nil : part }
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // As the home screen (Gerd-Jan, 21 October 2026): the manual in a card,
                    // then a line per part that opens underneath, one at a time
                    SettingsManualCard(manual: UserManual.android)
                        .padding(.bottom, 16)
                    SettingsRow("Mijn team", icon: "person.2", open: openPart == "team") { toggle("team") }
                    if openPart == "team" { teamSection.padding(.bottom, 16) }
                    SettingsDivider()
                    SettingsRow("Weergave", icon: "circle.lefthalf.filled", open: openPart == "theme") { toggle("theme") }
                    if openPart == "theme" { AppearancePicker(showsTitle: false).padding(.bottom, 16) }
                    SettingsDivider()
                    SettingsRow("Baanindeling", icon: "square.grid.3x3", open: openPart == "court") { toggle("court") }
                    if openPart == "court" { courtSection.padding(.bottom, 16) }
                    SettingsDivider()
                    SettingsRow("Live meekijken", icon: "dot.radiowaves.left.and.right", open: openPart == "live") { toggle("live") }
                    if openPart == "live" { liveSection.padding(.bottom, 16) }
                    SettingsDivider()
                    if backup != nil {
                        SettingsRow("Back-up", icon: "icloud.and.arrow.up", open: openPart == "backup") { toggle("backup") }
                        if openPart == "backup" { backupSection.padding(.bottom, 16) }
                        SettingsDivider()
                    }
                    if aiCoach != nil {
                        SettingsRow("AI Coach", icon: "brain", open: openPart == "ai") { toggle("ai") }
                        if openPart == "ai" {
                            VStack(alignment: .leading, spacing: 20) {
                                aiCoachSection
                                aboutAICoachSection
                            }
                            .padding(.bottom, 16)
                        }
                        SettingsDivider()
                    }
                    AboutAppSection(appVersion: backup?.appVersion ?? "Android", manual: UserManual.android)
                    // Clear of the system navigation bar
                    Color.clear.frame(height: 40)
                }
                .padding(24)
            }
        }
        .pageTitle("Instellingen")
        .onAppear {
            draft = teamURL
            hasKey = aiCoach?.keyStore.hasOpenAIKey == true
        }
    }

    /// Mijn team: the sbn.toernooi.nl link, saved or removed here
    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vul de openbare teamlink van sbn.toernooi.nl in. Daarna verschijnt Mijn team op het beginscherm.")
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
            Link(destination: UserManual.androidTeamLink) {
                Text("Waar vind ik mijn teamlink?")
                    .font(SharedFonts.system(13, weight: .semibold))
                    .foregroundColor(SharedColors.accent)
            }
            TextField("https://sbn.toernooi.nl/league/.../team/...", text: $draft)
                .accessibilityLabel("Teamlink")
                // No autocapitalization/URL-keyboard modifiers: this package also builds
                // for macOS; the link check is case-insensitive where it matters
                .autocorrectionDisabled()
                .foregroundColor(SharedColors.textPrimary)
                .padding()
                .background(SharedColors.tint(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            HStack(spacing: 12) {
                // ActionButton as everywhere else: a system button turned white on grey in the light theme
                ActionButton("BEWAAR TEAMLINK", style: .filled, color: SharedColors.accent) { save() }
                if !teamURL.isEmpty {
                    ActionButton("VERWIJDER", style: .outlined, color: SharedColors.textSecondary) { remove() }
                }
            }
            if let message {
                Text(message)
                    .font(SharedFonts.system(12))
                    .foregroundColor(messageIsError ? SharedColors.error : SharedColors.positive)
            }
        }
    }

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $liveSharing) {
                Text("Knop LIVE bij Scheidsrechter en Coach")
                    .font(SharedFonts.system(14))
                    .foregroundColor(SharedColors.textPrimary)
            }
            .tint(SharedColors.accent)
            Toggle(isOn: $livePhotos) {
                Text("Foto's van de spelers meesturen")
                    .font(SharedFonts.system(14))
                    .foregroundColor(liveSharing ? SharedColors.textPrimary : SharedColors.textMuted)
            }
            .tint(SharedColors.accent)
            .disabled(!liveSharing)
            Text("Met LIVE deel je een link, bijvoorbeeld in de WhatsApp-groep; wie erop tikt ziet de stand live in de browser. Alleen voornamen, de stand en (als je dat aan laat) een kleine foto van de spelers; 2 uur na de wedstrijd wordt alles gewist.")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textMuted)
            Toggle(isOn: Binding(get: { liveAlerts }, set: { on in
                liveAlerts = on
                // The server keeps the choice per followed match: tell it for the ones followed now
                Task { await LiveFollow.shared.setAlerts(on) }
            })) {
                Text("Melding bij elke game")
                    .font(SharedFonts.system(14))
                    .foregroundColor(SharedColors.textPrimary)
            }
            .tint(SharedColors.accent)
            Text("Bij een gevolgde wedstrijd: een melding met geluid als er een game is uitgespeeld en bij de uitslag. Bij een teamwedstrijd: per partij en bij de einduitslag.")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textMuted)
        }
    }

    private var courtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Baanindeling", selection: $courtLayout) {
                Text("6 vakken").tag(CourtLayout.six.rawValue)
                Text("9 vakken").tag(CourtLayout.nine.rawValue)
            }
            .pickerStyle(.segmented)
            Text("Bij 6 vakken kies je voor, midden of achter, links of rechts; bij 9 komt er een middenkolom bij. De slagen die je ziet passen bij de rij van het vak.")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textMuted)
        }
    }

    private var aiCoachSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voeg je OpenAI API key toe voor gepersonaliseerd tactisch advies van de AI Coach.")
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 8) {
                if showingKey {
                    TextField("sk-...", text: $keyDraft)
                        .accessibilityLabel("OpenAI API key")
                        .autocorrectionDisabled()
                        .foregroundColor(SharedColors.textPrimary)
                } else {
                    SecureField("sk-...", text: $keyDraft)
                        .accessibilityLabel("OpenAI API key")
                        .foregroundColor(SharedColors.textPrimary)
                }
                Button(showingKey ? "Verberg" : "Toon") { showingKey.toggle() }
                    .foregroundColor(SharedColors.textSecondary)
            }
            .padding()
            .background(SharedColors.tint(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            HStack(spacing: 12) {
                ActionButton("BEWAAR API KEY", style: .filled, color: SharedColors.accent,
                             disabled: keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { saveKey() }
                if hasKey {
                    ActionButton("VERWIJDER KEY", style: .outlined, color: SharedColors.textSecondary) { removeKey() }
                }
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(hasKey ? SharedColors.positive : SharedColors.error)
                    .frame(width: 8, height: 8)
                Text(keyMessage ?? (hasKey ? "API key geconfigureerd" : "Geen API key ingesteld"))
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textMuted)
            }
        }
    }

    /// "Over AI Coach", as on iOS
    private var aboutAICoachSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Over AI Coach")
                .font(SharedFonts.system(16, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            infoRow("Veilig", "Je API key wordt versleuteld op dit toestel bewaard")
            infoRow("Kosten", "~€0.01 per analyse (het goedkoopste beschikbare model)")
            infoRow("Internet vereist", "AI advies werkt alleen met internetverbinding")
            infoRow("Lokaal advies", "Basis advies werkt altijd, ook zonder API key")
        }
    }

    private func infoRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Text(detail)
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bewaar spelers, coach- en scheidsrechterwedstrijden en badges in een bestand, bijvoorbeeld op Google Drive. Een back-up van Android kun je ook op een iPhone terugzetten, en andersom.")
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
            HStack(spacing: 12) {
                ActionButton("MAAK BACK-UP", style: .filled, color: SharedColors.accent, disabled: backupBusy) { makeBackup() }
                ActionButton("ZET BACK-UP TERUG", style: .outlined, color: SharedColors.accent, disabled: backupBusy) { pickBackup() }
            }
            if let auto = backup?.auto {
                autoBackupRow(auto)
            }
            if backupBusy {
                ProgressView()
            }
            if let backupMessage {
                Text(backupMessage)
                    .font(SharedFonts.system(12))
                    .foregroundColor(backupIsError ? SharedColors.error : SharedColors.positive)
            }
        }
        .alert("Back-up terugzetten?", isPresented: $askingRestore) {
            Button("Samenvoegen") { restore(replacing: false) }
            Button("Alles vervangen", role: .destructive) { restore(replacing: true) }
            Button("Annuleren", role: .cancel) { pendingRestore = nil }
        } message: {
            Text(restoreQuestion)
        }
    }

    private func autoBackupRow(_ auto: any AutoBackupControl) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automatische back-up")
                .font(SharedFonts.system(14, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
                .padding(.top, 8)
            if let folder = autoFolder {
                Text("Aan · map \u{201C}\(folder)\u{201D}\(autoLast.map { date in " · laatste \(Self.shortDate(date))" } ?? "")")
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                Button("Uitzetten") {
                    auto.turnOff()
                    refreshAuto()
                }
                .foregroundColor(SharedColors.textSecondary)
            } else {
                Text("Eén keer per week, als je de app na gebruik wegzet, komt er een back-up in een map die je kiest (bijvoorbeeld Documenten). De 7 nieuwste blijven bewaard.")
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textMuted)
                Button("Aanzetten en map kiezen") { turnOnAuto(auto) }
                    .foregroundColor(SharedColors.accent)
                    .disabled(backupBusy)
            }
        }
        .onAppear { refreshAuto() }
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: date)
    }

    private func refreshAuto() {
        autoFolder = backup?.auto?.folderName()
        autoLast = backup?.auto?.lastBackupDate()
    }

    private func turnOnAuto(_ auto: any AutoBackupControl) {
        backupBusy = true
        backupMessage = nil
        Task {
            do {
                if try await auto.turnOn() {
                    showBackup("Automatische back-up staat aan; de eerste is gemaakt.", error: false)
                }
            } catch {
                showBackup("Automatische back-up aanzetten is niet gelukt.", error: true)
            }
            refreshAuto()
            backupBusy = false
        }
    }

    private var restoreQuestion: String {
        guard let backup = pendingRestore else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMMM yyyy HH:mm"
        var contents = "\(backup.players.count) spelers en \(backup.matches.count + backup.standaloneGames.count) wedstrijden"
        let referee = backup.refereeMatches?.count ?? 0
        let team = backup.teamMatches?.count ?? 0
        if referee > 0 { contents += ", \(referee) scheidsrechterwedstrijden" }
        if team > 0 { contents += ", \(team) teamwedstrijden" }
        return "Back-up van \(formatter.string(from: backup.backupDate)): \(contents). Samenvoegen voegt toe wat er nog niet is; Alles vervangen wist eerst je spelers, wedstrijden en badges op dit toestel, ook de scheidsrechter- en teamwedstrijden als de back-up die bevat."
    }

    private func showBackup(_ text: String, error: Bool) {
        backupMessage = text
        backupIsError = error
    }

    private func makeBackup() {
        guard let backup else { return }
        backupBusy = true
        backupMessage = nil
        Task {
            do {
                let full = try await backup.store.makeBackup()
                let data = try BackupCodec.encode(full, appVersion: backup.appVersion)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let saved = try await backup.files.save(data, suggestedName: "squash-backup-\(formatter.string(from: Date())).json")
                if saved {
                    showBackup("Back-up opgeslagen: \(full.players.count) spelers, \(full.matches.count) wedstrijden", error: false)
                }
            } catch {
                showBackup("De back-up is niet gelukt.", error: true)
            }
            backupBusy = false
        }
    }

    private func pickBackup() {
        guard let backup else { return }
        backupBusy = true
        backupMessage = nil
        Task {
            do {
                if let data = try await backup.files.open() {
                    pendingRestore = try BackupCodec.decode(data)
                    askingRestore = true
                }
            } catch {
                showBackup((error as? BackupValidationError)?.message ?? "Dit bestand kon niet worden gelezen.", error: true)
            }
            backupBusy = false
        }
    }

    private func restore(replacing: Bool) {
        guard let backup, let full = pendingRestore else { return }
        pendingRestore = nil
        backupBusy = true
        Task {
            do {
                let counts = try await backup.store.restore(full, replacing: replacing)
                showBackup("Teruggezet: \(counts.summary)", error: false)
            } catch {
                showBackup("Terugzetten is niet gelukt; er is niets veranderd.", error: true)
            }
            backupBusy = false
        }
    }

    private func saveKey() {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let aiCoach, !key.isEmpty else { return }
        aiCoach.keyStore.openAIAPIKey = key
        keyDraft = ""
        hasKey = aiCoach.keyStore.hasOpenAIKey
        keyMessage = hasKey ? "API key opgeslagen" : "Opslaan is niet gelukt"
    }

    private func removeKey() {
        aiCoach?.keyStore.openAIAPIKey = nil
        hasKey = false
        keyMessage = "API key verwijderd"
    }

    private func save() {
        do {
            let link = try LeagueTeamLink(draft)
            teamURL = link.url.absoluteString
            draft = teamURL
            message = "Teamlink opgeslagen"
            messageIsError = false
        } catch {
            message = (error as? LeagueTeamError)?.message ?? LeagueTeamError.invalidLink.message
            messageIsError = true
        }
    }

    private func remove() {
        teamURL = ""
        draft = ""
        message = "Teamlink verwijderd"
        messageIsError = false
    }
}
