import SwiftUI
import SquashAnalyzerCore

/// Spelers → Team: paste a squashanalyzer.com/teams link and import that team
/// (names, photos, focus). Android only for now; iOS has the same choice in
/// its own Spelers screen (`PlayerManagementView`, "Via link").
struct SharedTeamImportView: View {
    let importer: any TeamLinkImporter
    /// Called after a successful import so the list reloads
    let onImported: () async -> Void
    let onClose: () -> Void

    @State private var link = ""
    @State private var isImporting = false
    @State private var resultText: String? = nil
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            PlayerStyle.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("TEAM IMPORTEREN")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(PlayerStyle.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Button(action: onClose) {
                        AppSymbol("xmark", size: 18, color: PlayerStyle.text)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Sluiten")
                }
                Text("Plak de teamlink die je hebt gekregen, zoals https://squashanalyzer.com/teams/…/team.zip. Spelers met dezelfde naam worden bijgewerkt, nieuwe worden toegevoegd.")
                    .font(.system(size: 14))
                    .foregroundColor(PlayerStyle.muted)
                TextField("https://squashanalyzer.com/teams/…", text: $link)
                    .foregroundColor(PlayerStyle.text)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .disabled(isImporting)
                Button(action: start) {
                    Text(isImporting ? "Bezig met importeren…" : "IMPORTEREN")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(PlayerStyle.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PlayerStyle.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isImporting || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let resultText {
                    Text(resultText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PlayerStyle.gold)
                }
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.90, green: 0.40, blue: 0.35))
                }
                Spacer()
            }
            .padding(24)
        }
    }

    private func start() {
        isImporting = true
        resultText = nil
        errorText = nil
        let text = link
        Task {
            do {
                let result = try await importer.importTeam(link: text)
                resultText = "Geïmporteerd: \(result.summary)"
                await onImported()
            } catch let error as TeamImportError {
                errorText = error.message
            } catch {
                errorText = TeamImportError.unavailable.message
            }
            isImporting = false
        }
    }
}
