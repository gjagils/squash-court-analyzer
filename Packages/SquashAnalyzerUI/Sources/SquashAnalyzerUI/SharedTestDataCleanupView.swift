import SwiftUI
import SquashAnalyzerCore

// MARK: - Testgegevens opruimen

/// The one-time question after the badge reset (`TestDataCleanup`): a switch
/// per group, all on, first a full backup. "Bewaren" keeps everything in the
/// history; for badges it no longer counts anyway. iOS and Android alike.
public struct SharedTestDataCleanupView: View {
    let counts: TestDataCounts
    let before: Date
    let store: any TestDataCleanupStore
    /// Answered (cleaned up or kept): the question does not come back
    let onDone: () -> Void

    @State private var chosen: [TestDataGroup]
    @State private var busy = false
    @State private var failure: String? = nil

    public init(counts: TestDataCounts, before: Date, store: any TestDataCleanupStore, onDone: @escaping () -> Void) {
        self.counts = counts
        self.before = before
        self.store = store
        self.onDone = onDone
        _chosen = State(initialValue: counts.groups)
    }

    private func binding(_ group: TestDataGroup) -> Binding<Bool> {
        Binding(get: { chosen.contains(group) },
                set: { on in
                    if on { if !chosen.contains(group) { chosen.append(group) } } else { chosen.removeAll { $0 == group } }
                })
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Testgegevens opruimen")
                        .font(SharedFonts.system(22, weight: .bold, design: .rounded))
                        .foregroundColor(SharedColors.textPrimary)
                    Text("De testperiode is voorbij en iedereen begint opnieuw met badges. Wil je ook de wedstrijden uit de testperiode opruimen? Alleen wedstrijden van vóór de release; eerst wordt een volledige back-up gemaakt.")
                        .font(SharedFonts.system(13))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(counts.groups, id: \.self) { group in
                            Toggle(isOn: binding(group)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.title)
                                        .font(SharedFonts.system(14, weight: .medium, design: .rounded))
                                        .foregroundColor(SharedColors.textPrimary)
                                    Text(counts.count(group) == 1 ? "1 wedstrijd" : "\(counts.count(group)) wedstrijden")
                                        .font(SharedFonts.system(11))
                                        .foregroundColor(SharedColors.textMuted)
                                }
                            }
                            .tint(SharedColors.accent)
                            .disabled(busy)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SharedColors.tint(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Wat je bewaart, blijft in de geschiedenis en de analyse staan. Voor badges telt het niet meer mee.")
                        .font(SharedFonts.system(11))
                        .foregroundColor(SharedColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let failure {
                        Text(failure)
                            .font(SharedFonts.system(12, weight: .medium))
                            .foregroundColor(SharedColors.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ActionButton(busy ? "BEZIG…" : "OPRUIMEN", icon: "trash", style: .filled, disabled: busy || chosen.isEmpty) {
                        Task { await cleanUp() }
                    }
                    ActionButton("ALLES BEWAREN", disabled: busy) { onDone() }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    private func cleanUp() async {
        busy = true
        failure = nil
        do {
            try await store.backUp()
        } catch {
            busy = false
            failure = "De back-up is niet gelukt, dus er is niets opgeruimd. Probeer het later opnieuw of kies Alles bewaren."
            return
        }
        do {
            try await store.remove(chosen, before: before)
            onDone()
        } catch {
            busy = false
            failure = "Opruimen is niet gelukt. De back-up van zojuist staat klaar; probeer het later opnieuw."
        }
    }
}
