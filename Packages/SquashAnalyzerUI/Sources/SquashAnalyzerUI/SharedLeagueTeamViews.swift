import SwiftUI
import SquashAnalyzerCore

// "Mijn team" on Android: the card on the home screen, the team screen, and
// the settings screen where the team link is entered. iOS has its own
// `LeagueTeamCard` / `LeagueTeamDetailView` (named `Shared...` here so the two
// never collide); both use Core's `LeagueTeamFetcher` and the same storage keys.

enum LeaguePalette {
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let secondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let muted = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let card = Color(red: 0.14, green: 0.12, blue: 0.10)
    static let background = Color.black
}

enum LeagueDates {
    static func day(_ date: Date) -> String {
        format(date, "EEE d MMM")
    }

    static func time(_ date: Date) -> String {
        format(date, "HH:mm")
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

/// The home-screen card: stand, played and points, and the next match. Shows
/// nothing until a team link is saved in Instellingen; keeps showing the last
/// fetched team when SBN cannot be reached.
public struct SharedLeagueTeamCard: View {
    let fetcher: LeagueTeamFetcher
    let onOpen: (LeagueTeamSnapshot) -> Void

    @AppStorage(LeagueTeamStorage.linkKey) private var teamURL = ""
    @State private var snapshot: LeagueTeamSnapshot?
    @State private var errorMessage: String?
    @State private var loading = false

    public init(fetcher: LeagueTeamFetcher, onOpen: @escaping (LeagueTeamSnapshot) -> Void) {
        self.fetcher = fetcher
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let snapshot {
                Button { onOpen(snapshot) } label: { card(snapshot) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mijn team: \(snapshot.name)")
            } else if !teamURL.isEmpty {
                HStack(spacing: 10) {
                    if loading {
                        ProgressView()
                    }
                    Text(loading ? "Mijn team laden…" : (errorMessage ?? "Team laden niet gelukt"))
                        .font(.system(size: 12))
                        .foregroundColor(LeaguePalette.secondary)
                    Spacer()
                    if !loading {
                        Button("Opnieuw") { Task { await load() } }
                            .foregroundColor(LeaguePalette.orange)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(LeaguePalette.card))
            }
        }
        .padding(.horizontal, 24)
        .task(id: teamURL) { await load() }
    }

    private func card(_ snapshot: LeagueTeamSnapshot) -> some View {
        HomeTeamSummary(snapshot: snapshot)
    }

    private func load() async {
        guard let link = try? LeagueTeamLink(teamURL) else {
            snapshot = nil
            return
        }
        if snapshot?.source != link.url {
            snapshot = LeagueTeamStorage.cachedSnapshot(for: link)
        }
        loading = true
        errorMessage = nil
        do {
            let result = try await fetcher.fetch(link)
            LeagueTeamStorage.store(result)
            snapshot = result
        } catch {
            errorMessage = (error as? LeagueTeamError)?.message ?? LeagueTeamError.unavailable.message
        }
        loading = false
    }
}

/// The whole team: standings, matches and players
public struct SharedLeagueTeamDetailView: View {
    let snapshot: LeagueTeamSnapshot

    public init(snapshot: LeagueTeamSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        ZStack {
            LeaguePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(LeaguePalette.text)
                        Text("\(snapshot.division) · \(snapshot.competition)")
                            .font(.system(size: 12))
                            .foregroundColor(LeaguePalette.secondary)
                    }
                    section("STAND") {
                        ForEach(snapshot.standings) { row in
                            HStack {
                                Text("\(row.rank)")
                                    .foregroundColor(row.name == snapshot.name ? LeaguePalette.orange : LeaguePalette.muted)
                                    .frame(width: 26, alignment: .leading)
                                Text(row.name)
                                    .foregroundColor(LeaguePalette.text)
                                    .fontWeight(row.name == snapshot.name ? .bold : .regular)
                                Spacer()
                                Text("\(row.points) pt")
                                    .foregroundColor(LeaguePalette.gold)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    section("WEDSTRIJDEN") {
                        ForEach(snapshot.fixtures) { fixture in
                            HStack(spacing: 10) {
                                Text(LeagueDates.day(fixture.date))
                                    .font(.system(size: 11))
                                    .foregroundColor(LeaguePalette.muted)
                                    .frame(width: 82, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fixture.home).foregroundColor(LeaguePalette.text)
                                    Text(fixture.away).foregroundColor(LeaguePalette.secondary)
                                }
                                Spacer()
                                Text(fixture.score ?? LeagueDates.time(fixture.date))
                                    .foregroundColor(fixture.score == nil ? LeaguePalette.muted : LeaguePalette.gold)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    section("SPELERS") {
                        ForEach(snapshot.players) { player in
                            HStack {
                                Text(player.name).foregroundColor(LeaguePalette.text)
                                Spacer()
                                Text(player.record)
                                    .font(.system(size: 12))
                                    .foregroundColor(LeaguePalette.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Text("Bijgewerkt: \(LeagueDates.day(snapshot.updatedAt)) \(LeagueDates.time(snapshot.updatedAt))")
                        .font(.system(size: 11))
                        .foregroundColor(LeaguePalette.muted)
                }
                .padding(24)
            }
        }
        .pageTitle("Mijn team")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(LeaguePalette.orange)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
    }
}

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

    public init(aiCoach: AICoachContext?, backup: BackupContext?) {
        self.aiCoach = aiCoach
        self.backup = backup
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

    public var body: some View {
        ZStack {
            LeaguePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    manualSection
                        .padding(.bottom, 20)
                    courtSection
                        .padding(.bottom, 20)
                    liveSection
                        .padding(.bottom, 20)
                    HStack(spacing: 8) {
                        HomeTileIconView(icon: .players, color: LeaguePalette.orange, size: 20)
                        Text("Mijn team")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(LeaguePalette.text)
                    }
                    Text("Vul de openbare teamlink van sbn.toernooi.nl in. Daarna verschijnt Mijn team op het beginscherm.")
                        .font(.system(size: 13))
                        .foregroundColor(LeaguePalette.secondary)
                    TextField("https://sbn.toernooi.nl/league/.../team/...", text: $draft)
                        .accessibilityLabel("Teamlink")
                        // No autocapitalization/URL-keyboard modifiers: this package also builds
                        // for macOS; the link check is case-insensitive where it matters
                        .autocorrectionDisabled()
                        .foregroundColor(LeaguePalette.text)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    HStack(spacing: 12) {
                        Button("Bewaar teamlink") { save() }
                            .buttonStyle(.borderedProminent)
                            .tint(LeaguePalette.orange)
                        if !teamURL.isEmpty {
                            Button("Verwijder") { remove() }
                                .foregroundColor(LeaguePalette.secondary)
                        }
                    }
                    if let message {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(messageIsError ? Color(red: 0.95, green: 0.40, blue: 0.35) : Color(red: 0.45, green: 0.80, blue: 0.45))
                    }
                    // Same order as iOS: back-up, then AI Coach and what it is
                    if backup != nil {
                        backupSection
                            .padding(.top, 20)
                    }
                    if aiCoach != nil {
                        aiCoachSection
                            .padding(.top, 20)
                        aboutAICoachSection
                            .padding(.top, 20)
                    }
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

    /// The Android manual on the website (iOS links to the iPhone page)
    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Handleiding")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            Text("Per tegel uitgelegd hoe alles werkt, op squashanalyzer.com.")
                .font(.system(size: 13))
                .foregroundColor(LeaguePalette.secondary)
            Link(destination: UserManual.android) {
                Text("Open de handleiding")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LeaguePalette.orange)
            }
            .accessibilityLabel("Open de handleiding")
        }
    }

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live meekijken")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            Toggle(isOn: $liveSharing) {
                Text("Knop LIVE bij Coach en Scheidsrechter")
                    .font(.system(size: 14))
                    .foregroundColor(LeaguePalette.text)
            }
            .tint(LeaguePalette.orange)
            Text("Met LIVE deel je een link, bijvoorbeeld in de WhatsApp-groep; wie erop tikt ziet de stand live in de browser. Alleen voornamen en de stand; 2 uur na de wedstrijd wordt alles gewist.")
                .font(.system(size: 12))
                .foregroundColor(LeaguePalette.muted)
        }
    }

    private var courtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Baanindeling")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            Picker("Baanindeling", selection: $courtLayout) {
                Text("6 vakken").tag(CourtLayout.six.rawValue)
                Text("9 vakken").tag(CourtLayout.nine.rawValue)
            }
            .pickerStyle(.segmented)
            Text("Bij 6 vakken kies je voor, midden of achter, links of rechts; bij 9 komt er een middenkolom bij. De slagen die je ziet passen bij de rij van het vak.")
                .font(.system(size: 12))
                .foregroundColor(LeaguePalette.muted)
        }
    }

    private var aiCoachSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Coach")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            Text("Voeg je OpenAI API key toe voor gepersonaliseerd tactisch advies van de AI Coach.")
                .font(.system(size: 13))
                .foregroundColor(LeaguePalette.secondary)
            HStack(spacing: 8) {
                if showingKey {
                    TextField("sk-...", text: $keyDraft)
                        .accessibilityLabel("OpenAI API key")
                        .autocorrectionDisabled()
                        .foregroundColor(LeaguePalette.text)
                } else {
                    SecureField("sk-...", text: $keyDraft)
                        .accessibilityLabel("OpenAI API key")
                        .foregroundColor(LeaguePalette.text)
                }
                Button(showingKey ? "Verberg" : "Toon") { showingKey.toggle() }
                    .foregroundColor(LeaguePalette.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            HStack(spacing: 12) {
                Button("Bewaar API key") { saveKey() }
                    .buttonStyle(.borderedProminent)
                    .tint(LeaguePalette.gold)
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if hasKey {
                    Button("Verwijder key") { removeKey() }
                        .foregroundColor(LeaguePalette.secondary)
                }
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(hasKey ? Color(red: 0.45, green: 0.80, blue: 0.45) : Color(red: 0.95, green: 0.40, blue: 0.35))
                    .frame(width: 8, height: 8)
                Text(keyMessage ?? (hasKey ? "API key geconfigureerd" : "Geen API key ingesteld"))
                    .font(.system(size: 12))
                    .foregroundColor(LeaguePalette.muted)
            }
        }
    }

    /// "Over AI Coach", as on iOS
    private var aboutAICoachSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Over AI Coach")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            infoRow("Veilig", "Je API key wordt versleuteld op dit toestel bewaard")
            infoRow("Kosten", "~€0.01 per analyse (het goedkoopste beschikbare model)")
            infoRow("Internet vereist", "AI advies werkt alleen met internetverbinding")
            infoRow("Lokaal advies", "Basis advies werkt altijd, ook zonder API key")
        }
    }

    private func infoRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(LeaguePalette.secondary)
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Back-up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
            Text("Bewaar spelers, coach- en scheidsrechterwedstrijden en badges in een bestand, bijvoorbeeld op Google Drive. Een back-up van Android kun je ook op een iPhone terugzetten, en andersom.")
                .font(.system(size: 13))
                .foregroundColor(LeaguePalette.secondary)
            HStack(spacing: 12) {
                Button("Maak back-up") { makeBackup() }
                    .buttonStyle(.borderedProminent)
                    .tint(LeaguePalette.orange)
                    .disabled(backupBusy)
                Button("Zet back-up terug") { pickBackup() }
                    .foregroundColor(LeaguePalette.orange)
                    .disabled(backupBusy)
            }
            if let auto = backup?.auto {
                autoBackupRow(auto)
            }
            if backupBusy {
                ProgressView()
            }
            if let backupMessage {
                Text(backupMessage)
                    .font(.system(size: 12))
                    .foregroundColor(backupIsError ? Color(red: 0.95, green: 0.40, blue: 0.35) : Color(red: 0.45, green: 0.80, blue: 0.45))
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LeaguePalette.text)
                .padding(.top, 8)
            if let folder = autoFolder {
                Text("Aan · map \u{201C}\(folder)\u{201D}\(autoLast.map { date in " · laatste \(Self.shortDate(date))" } ?? "")")
                    .font(.system(size: 12))
                    .foregroundColor(LeaguePalette.secondary)
                Button("Uitzetten") {
                    auto.turnOff()
                    refreshAuto()
                }
                .foregroundColor(LeaguePalette.secondary)
            } else {
                Text("Eén keer per week, als je de app na gebruik wegzet, komt er een back-up in een map die je kiest (bijvoorbeeld Documenten). De 7 nieuwste blijven bewaard.")
                    .font(.system(size: 12))
                    .foregroundColor(LeaguePalette.muted)
                Button("Aanzetten en map kiezen") { turnOnAuto(auto) }
                    .foregroundColor(LeaguePalette.orange)
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
        return "Back-up van \(formatter.string(from: backup.backupDate)): \(backup.players.count) spelers en \(backup.matches.count + backup.standaloneGames.count) wedstrijden. Samenvoegen voegt toe wat er nog niet is; Alles vervangen wist eerst je spelers, coachwedstrijden en badges op dit toestel."
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
