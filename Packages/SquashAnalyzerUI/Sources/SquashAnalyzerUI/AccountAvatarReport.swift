import SwiftUI
import SquashAnalyzerCore

/// Under a player's photo when it came from that player's account (4.0):
/// where it comes from, and "Foto melden" for a photo that is not okay. A photo
/// picked on this phone replaces it as usual.
public struct AccountAvatarReportButton: View {
    let playerId: String

    @State private var confirming = false
    @State private var reported = false

    public init(playerId: String) {
        self.playerId = playerId
    }

    public var body: some View {
        if let record = AccountAvatars.records()[playerId] {
            VStack(spacing: 4) {
                Text("Foto uit het account van deze speler", bundle: textBundle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textMuted)
                if reported {
                    Text("Gemeld. Dank je!", bundle: textBundle)
                        .font(SharedFonts.system(12, weight: .semibold))
                        .foregroundColor(SharedColors.support)
                } else {
                    Button(loc("Foto melden")) { confirming = true }
                        .font(SharedFonts.system(12, weight: .semibold))
                        .foregroundColor(SharedColors.error)
                }
            }
            .alert(loc("Foto melden?"), isPresented: $confirming) {
                Button(loc("Melden"), role: .destructive) { report(record.sbnPath) }
                Button(loc("Annuleren"), role: .cancel) { }
            } message: {
                Text("Hoort deze foto hier niet, of is hij niet in orde? Wij kijken ernaar en halen hem zo nodig weg.", bundle: textBundle)
            }
        }
    }

    private func report(_ sbnPath: String) {
        Task {
            do {
                try await PlayerAccount.shared.reportAvatar(sbnPath: sbnPath)
                reported = true
            } catch {
                reported = false
            }
        }
    }
}
