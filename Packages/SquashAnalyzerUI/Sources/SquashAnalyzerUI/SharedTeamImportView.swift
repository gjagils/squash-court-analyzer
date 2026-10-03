import SwiftUI
import SquashAnalyzerCore

/// Spelers → Team: paste a squashanalyzer.com/teams link and import that team
/// (names, photos, focus). Android only for now; iOS has the same choice in
/// its own Spelers screen (`PlayerManagementView`, "Via link").
struct SharedTeamImportView: View {
    let importer: any TeamLinkImporter
    /// "Kies zip-bestand" from the phone's files; nil hides it
    let filePicker: (any PlayerFilePicker)?
    /// Called after a successful import so the list reloads
    let onImported: () async -> Void
    let onClose: () -> Void

    @State private var link = ""
    @State private var isImporting = false
    @State private var resultText: String? = nil
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("TEAM IMPORTEREN")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(SharedColors.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Button(action: onClose) {
                        AppSymbol("xmark", size: 18, color: SharedColors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Sluiten")
                }
                Text("Plak de teamlink die je hebt gekregen, zoals https://squashanalyzer.com/teams/…/team.zip. Spelers met dezelfde naam worden bijgewerkt, nieuwe worden toegevoegd.")
                    .font(.system(size: 14))
                    .foregroundColor(SharedColors.textSecondary)
                TextField("https://squashanalyzer.com/teams/…", text: $link)
                    .foregroundColor(SharedColors.textPrimary)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .disabled(isImporting)
                ActionButton(isImporting ? "Bezig met importeren…" : "IMPORTEREN", style: .filled, color: SharedColors.gold,
                             disabled: isImporting || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, action: start)
                if filePicker != nil {
                    Text("Of kies een team-zip van je telefoon.")
                        .font(.system(size: 14))
                        .foregroundColor(SharedColors.textSecondary)
                    ActionButton("KIES ZIP-BESTAND", color: SharedColors.gold, disabled: isImporting, action: pickZip)
                }
                if let resultText {
                    Text(resultText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SharedColors.gold)
                }
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 14))
                        .foregroundColor(SharedColors.error)
                }
                Spacer()
            }
            .padding(24)
        }
    }

    private func pickZip() {
        Task {
            do {
                guard let zip = try await filePicker?.pickTeamZip() else { return }
                isImporting = true
                resultText = nil
                errorText = nil
                let result = try await importer.importTeam(zip: zip)
                resultText = "Geïmporteerd: \(result.summary)"
                await onImported()
            } catch let error as TeamImportError {
                errorText = error.message
            } catch {
                errorText = TeamImportError.notAZip.message
            }
            isImporting = false
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
