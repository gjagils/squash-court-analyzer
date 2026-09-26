import SwiftUI

/// Coach input settings shared between the settings screen and the live coach screen
enum CoachInputSettings {
    static let modeKey = "coachInputMode"
    static let teamURLKey = "sbnTeamURL"
}

/// How a point is entered on the coach screen. The stored raw value of the
/// removed "classic" mode no longer parses and falls back to `.scoreTap`.
enum CoachInputMode: String {
    /// Winner/Fout buttons per player, shot optional afterwards
    case quick
    /// Tap the score, then everything inline: type → zone → slag, no pop-ups
    case scoreTap

    var description: String {
        switch self {
        case .quick: return "Winner en Fout per speler; na de zone is het punt binnen, de slag kies je optioneel achteraf."
        case .scoreTap: return "Tik op de score van wie scoort; type, zone en slag volgen op het scherm zelf. Ook bij een unforced error leg je vast waar."
        }
    }
}

/// Settings view for managing app configuration
struct SettingsView: View {
    @Binding var isPresented: Bool
    @AppStorage(CoachInputSettings.modeKey) private var inputModeRaw = CoachInputMode.scoreTap.rawValue

    private var inputMode: CoachInputMode {
        CoachInputMode(rawValue: inputModeRaw) ?? .scoreTap
    }
    @State private var apiKey: String = ""
    @State private var showingAPIKey = false
    @State private var showingSaveConfirmation = false
    @AppStorage(CoachInputSettings.teamURLKey) private var teamURL = ""
    @State private var teamSaveMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(spacing: 24) {
                        // Coach input
                        coachInputSection

                        teamSection

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
        }
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "person.3.fill").foregroundColor(AppColors.warmOrange); Text("Mijn team").font(AppFonts.label(16)).foregroundColor(AppColors.textPrimary) }
            Text("Vul de openbare teamlink van sbn.toernooi.nl in. Daarna verschijnt Mijn team op het beginscherm.")
                .font(AppFonts.body(13)).foregroundColor(AppColors.textSecondary)
            TextField("https://sbn.toernooi.nl/league/.../team/...", text: $teamURL)
                .font(AppFonts.body(13)).foregroundColor(AppColors.textPrimary)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding().background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            HardwareButton(title: "Bewaar teamlink", subtitle: nil, color: AppColors.warmOrange, colorDark: AppColors.warmOrangeDark) {
                do { _ = try LeagueTeamLink(teamURL); teamSaveMessage = "Teamlink opgeslagen" }
                catch { teamSaveMessage = error.localizedDescription }
            }
            if let teamSaveMessage { Text(teamSaveMessage).font(AppFonts.caption(12)).foregroundColor(teamSaveMessage.contains("opgeslagen") ? .green : AppColors.warmRed) }
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

            Text("INSTELLINGEN")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)
                .tracking(3)

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

    // MARK: - Coach input Section
    private var coachInputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(AppColors.warmOrange)
                Text("Coachmodus")
                    .font(AppFonts.label(16))
                    .foregroundColor(AppColors.textPrimary)
            }

            Text("PUNTINVOER")
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)

            Toggle(isOn: Binding(
                get: { inputMode == .quick },
                set: { quick in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        inputModeRaw = (quick ? CoachInputMode.quick : .scoreTap).rawValue
                    }
                }
            )) {
                Text("Snelle invoer")
                    .font(AppFonts.label(14))
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.warmOrange)

            Text(inputMode.description)
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
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
            HardwareButton(
                title: showingSaveConfirmation ? "Opgeslagen!" : "Bewaar API Key",
                subtitle: nil,
                color: showingSaveConfirmation ? Color.green : AppColors.accentGold,
                colorDark: showingSaveConfirmation ? Color.green.opacity(0.7) : AppColors.accentGold.opacity(0.7)
            ) {
                saveAPIKey()
            }

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(APIKeyManager.shared.hasOpenAIKey ? Color.green : Color.red)
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
                    description: "~€0.01 per analyse (GPT-4o-mini)"
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
        APIKeyManager.shared.openAIAPIKey = apiKey.isEmpty ? nil : apiKey
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
