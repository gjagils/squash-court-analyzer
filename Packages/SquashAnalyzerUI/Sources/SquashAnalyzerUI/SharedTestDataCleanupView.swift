import SwiftUI
import SquashAnalyzerCore

// MARK: - Testgegevens opruimen

/// The one-time sheet after the badge reset (`TestDataCleanup`): the message
/// that badges start again (with Pionier) when the device had badges, and the
/// question with a switch per group, all on, first a full backup. "Bewaren" keeps everything in the
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
                    if counts.earlierBadges > 0 {
                        badgeReset
                    }
                    if !counts.isEmpty {
                        cleanup
                    } else {
                        ActionButton(loc("BEGREPEN"), style: .filled) { onDone() }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    /// The badge reset, for a device with badges from before it
    private var badgeReset: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges beginnen opnieuw", bundle: textBundle)
                .font(SharedFonts.system(22, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
            Text("Vanaf de release begint iedereen opnieuw met badges. Je badges uit de testperiode worden niet gewist, maar tellen niet meer mee.", bundle: textBundle)
                .font(SharedFonts.system(13))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                AppSymbol("medal", size: 20, color: SharedColors.accent, weight: .medium)
                Text("Als dank voor het testen krijgen je spelers de badge Pionier. Je vindt hem bij je spelers en in de lijst onder Speciaal.", bundle: textBundle)
                    .font(SharedFonts.system(13, weight: .medium))
                    .foregroundColor(SharedColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.tint(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// The question itself: a switch per group, first a full backup
    private var cleanup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Testgegevens opruimen", bundle: textBundle)
                .font(SharedFonts.system(counts.earlierBadges > 0 ? 18.0 : 22.0, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
            Text(counts.earlierBadges > 0
                 ? loc("Wil je ook de wedstrijden uit de testperiode opruimen? Alleen wedstrijden van vóór de release; eerst wordt een volledige back-up gemaakt.")
                 : loc("De testperiode is voorbij en iedereen begint opnieuw met badges. Wil je ook de wedstrijden uit de testperiode opruimen? Alleen wedstrijden van vóór de release; eerst wordt een volledige back-up gemaakt."))
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
                            Text(counts.count(group) == 1 ? loc("1 wedstrijd") : loc("\(counts.count(group)) wedstrijden"))
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
            Text("Wat je bewaart, blijft in de geschiedenis en de analyse staan. Voor badges telt het niet meer mee.", bundle: textBundle)
                .font(SharedFonts.system(11))
                .foregroundColor(SharedColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let failure {
                Text(failure)
                    .font(SharedFonts.system(12, weight: .medium))
                    .foregroundColor(SharedColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ActionButton(busy ? loc("BEZIG…") : loc("OPRUIMEN"), icon: "trash", style: .filled, disabled: busy || chosen.isEmpty) {
                Task { await cleanUp() }
            }
            ActionButton(loc("ALLES BEWAREN"), disabled: busy) { onDone() }
        }
    }

    private func cleanUp() async {
        busy = true
        failure = nil
        do {
            try await store.backUp()
        } catch {
            busy = false
            failure = loc("De back-up is niet gelukt, dus er is niets opgeruimd. Probeer het later opnieuw of kies Alles bewaren.")
            return
        }
        do {
            try await store.remove(chosen, before: before)
            onDone()
        } catch {
            busy = false
            failure = loc("Opruimen is niet gelukt. De back-up van zojuist staat klaar; probeer het later opnieuw.")
        }
    }
}
