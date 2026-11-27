import SwiftUI
import SquashAnalyzerCore

/// Instellingen → Delen en meldingen (Gerd-Jan, 21 November 2026: fewer
/// words on screen). One shared section for iPhone and Android: two groups of
/// switches with one line each, "Volg een andere wedstrijd" with them, and the
/// long explanation behind "Uitleg". It replaces "Live meekijken" with its
/// five paragraphs and the separate row "Wedstrijd volgen".
public struct ShareSettingsSection: View {
    @AppStorage(LiveShare.enabledKey) private var liveSharing = true
    @AppStorage(LiveShare.photosKey) private var livePhotos = true
    @AppStorage(LiveFollow.ownMatchKey) private var ownMatch = true
    @AppStorage(LiveFollow.alertsKey) private var liveAlerts = true
    @AppStorage(TeamAlertFollow.enabledKey) private var teamAlerts = true
    @AppStorage(AppUsage.enabledKey) private var usageCounting = true
    @State private var showingInfo = false
    @State private var showingFollow = false
    /// "Opnieuw vanzelf aanmaken" was tapped (testers)
    @State private var autoStartCleared = false
    /// "Je eigen wedstrijd": the iPhone shows the match being scored on the lock screen
    private let showsOwnMatch: Bool

    public init(showsOwnMatch: Bool = false) {
        self.showsOwnMatch = showsOwnMatch
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            group(loc("LIVE VOOR KIJKERS"))
            row(loc("Live aanbieden bij het scoren"), loc("Een kijklink, via de deelknop"), isOn: $liveSharing)
            row(loc("Foto's van de spelers meesturen"), loc("Kleine foto naast de voornaam"), isOn: $livePhotos, enabled: liveSharing)

            SettingsDivider()
            group(loc("OP JE VERGRENDELSCHERM"))
            if showsOwnMatch {
                row(loc("Je eigen wedstrijd"), loc("De stand tijdens het scoren"), isOn: $ownMatch)
            }
            row(loc("Je teamwedstrijd"), loc("Teamstand en meldingen, vanzelf bij de start"),
                isOn: Binding(get: { teamAlerts }, set: { on in
                    teamAlerts = on
                    // (Un)register the live team matches on this phone at once
                    Task { await TeamAlertFollow.shared.refresh() }
                }))
            row(loc("Melding bij elke game"), loc("Bij een wedstrijd die je volgt"),
                isOn: Binding(get: { liveAlerts }, set: { on in
                    liveAlerts = on
                    // The server keeps the choice per followed match: tell it for the ones followed now
                    Task { await LiveFollow.shared.setAlerts(on) }
                }))
            if LiveFollow.shared.presenter != nil {
                Button { showingFollow = true } label: {
                    HStack(spacing: 10) {
                        labels(loc("Volg een andere wedstrijd"), loc("Plak een live link"), enabled: true)
                        Spacer(minLength: 0)
                        AppSymbol("chevron.right", size: 14, color: SharedColors.textMuted)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingFollow) {
                    SharedLiveFollowView { showingFollow = false }
                }
            }

            SettingsDivider()
            group(loc("GEBRUIK"))
            row(loc("Anoniem gebruik tellen"), loc("Eén keer per dag, zonder naam of apparaat-ID"), isOn: $usageCounting)

            if Features.shared.testerTools && Features.shared.playerAccount {
                SettingsDivider()
                group(loc("VOOR TESTERS"))
                Button {
                    TeamFinding.clearAutoStarted()
                    autoStartCleared = true
                } label: {
                    HStack(spacing: 10) {
                        labels(loc("Teamwedstrijd opnieuw vanzelf aanmaken"),
                               autoStartCleared ? loc("Gewist: de app maakt hem weer vanzelf aan")
                                   : loc("Ook voor wedstrijden waarvan je hem verwijderde"), enabled: true)
                        Spacer(minLength: 0)
                        AppSymbol(autoStartCleared ? "checkmark" : "arrow.counterclockwise", size: 14,
                                  color: autoStartCleared ? SharedColors.support : SharedColors.accent)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            SettingsDivider()
            Button { showingInfo.toggle() } label: {
                HStack(spacing: 8) {
                    AppSymbol("questionmark.bubble", size: 16, color: SharedColors.accent)
                    Text(showingInfo ? loc("Verberg uitleg") : loc("Uitleg"))
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            if showingInfo { info }
        }
    }

    private func group(_ title: String) -> some View {
        Text(title)
            .font(SharedFonts.system(11, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(SharedColors.textMuted)
    }

    private func labels(_ title: String, _ detail: String, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(SharedFonts.system(14))
                .foregroundColor(enabled ? SharedColors.textPrimary : SharedColors.textMuted)
            Text(detail)
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textMuted)
        }
    }

    private func row(_ title: String, _ detail: String, isOn: Binding<Bool>, enabled: Bool = true) -> some View {
        Toggle(isOn: isOn) {
            labels(title, detail, enabled: enabled)
        }
        .tint(SharedColors.accent)
        .disabled(!enabled)
    }

    /// The long texts, as they stood under each switch before
    private var info: some View {
        VStack(alignment: .leading, spacing: 10) {
            paragraph(loc("Met LIVE deel je een link, bijvoorbeeld in de WhatsApp-groep; wie erop tikt ziet de stand live in de browser. Alleen voornamen, de stand en (als je dat aan laat) een kleine foto van de spelers; 2 uur na de wedstrijd wordt alles gewist."))
            if showsOwnMatch {
                paragraph(loc("Tijdens het scoren staat de stand van je wedstrijd op het vergrendelscherm en in het Dynamic Island. Een wedstrijd van iemand anders volg je via Wedstrijd volgen hier in Instellingen."))
            }
            paragraph(loc("Doe je mee aan een live teamwedstrijd (zelf gestart of meegedaan), dan krijg je een melding als een teamgenoot aan een partij begint, als een partij beslist is en bij de einduitslag. Niet over je eigen partij."))
            if Features.shared.playerAccount {
                paragraph(loc("Met een account hoor je het ook als iemand van je team een teamwedstrijd start, ook als je zelf niet speelt. De teamstand komt dan vanzelf op je vergrendelscherm en de teamwedstrijd staat in de app voor je klaar. Daarvoor staat het pushtoken van deze telefoon bij je account."))
            }
            paragraph(loc("Bij een gevolgde wedstrijd: een melding met geluid als er een game is uitgespeeld en bij de uitslag. Bij een teamwedstrijd: per partij en bij de einduitslag."))
            paragraph(loc("Eén keer per dag meldt de app dat hij gebruikt is: platform, versie, taal en welk deel. Zonder naam of apparaat-ID."))
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(SharedFonts.system(12))
            .foregroundColor(SharedColors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
