import SwiftUI
import SquashAnalyzerCore

/// Platform-independent home presentation. Navigation and persistence belong to
/// the host app; iOS keeps its existing destinations and Android adds them in phase 5.
public struct HomeMenuHeader: View {
    private let onSettings: (() -> Void)?
    /// Sign in with Apple on iOS, for Mijn account behind the photo top left
    private let accountProviders: [AccountProviderSignIn]
    @State private var showingAccount = false
    @State private var showingQuestion = false

    public init(onSettings: (() -> Void)? = nil, accountProviders: [AccountProviderSignIn] = []) {
        self.onSettings = onSettings
        self.accountProviders = accountProviders
    }

    /// Your photo (or the person icon) top left opens Mijn account (4.0, Gerd-Jan 10 November 2026)
    @ViewBuilder
    private var accountButton: some View {
        let account = PlayerAccount.shared
        if Features.shared.playerAccount && account.isConfigured {
            Button { showingAccount = true } label: {
                if let profile = account.profile {
                    PlayerPhotoView(photo: account.ownAvatar, name: profile.name, size: 30, color: SharedColors.textSecondary)
                } else {
                    AppSymbol("person.crop.circle", size: 22, color: SharedColors.textSecondary)
                }
            }
            .frame(width: 36, height: 36)
            .accessibilityLabel(loc("Mijn account"))
            .padding(.leading, -4)
        }
    }

    /// The logo and the text block are the same height; the text is centred
    /// next to the logo, the gear sits in the top right corner so the text
    /// gets the full width (Gerd-Jan, 12 October 2026)
    private static let logoSize: CGFloat = 72


    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                accountButton
                Spacer()
                // "Stel een vraag": a window with an answer from the manual (Gerd-Jan, 11 November 2026)
                Button { showingQuestion = true } label: {
                    AppSymbol("questionmark.bubble", size: 20, color: SharedColors.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(loc("Stel een vraag"))
                if let onSettings {
                    Button(action: onSettings) {
                        AppSymbol("gearshape", size: 20, color: SharedColors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(loc("Instellingen"))
                    // Same spot as the gear in the coach and referee headers (20 pt from the edge)
                    .padding(.trailing, -4)
                }
            }
            .frame(height: 36)
            HStack(spacing: 12) {
                // The logo on its own dark tile, or on warm light in the light theme
                Image(AppTheme.shared.isLight ? "home-logo-light" : "home-logo", bundle: .module)
                    .resizable().scaledToFit().frame(width: HomeMenuHeader.logoSize, height: HomeMenuHeader.logoSize)
                    .accessibilityHidden(true)
                VStack(alignment: .center, spacing: 0) {
                    // Wordmark as on the sticker: "Analyzer" in brand orange.
                    HStack(spacing: 0) {
                        Text("Squash").foregroundColor(SharedColors.textPrimary)
                        Text("Analyzer").foregroundColor(SharedColors.accent)
                    }
                    .font(SharedFonts.system(26, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    Text("Jouw spel scherp in beeld. Voor jou en je team.", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 2)
                    // The line from the stickers and the website; the sentence
                    // sits halfway between the wordmark and this line (the wordmark's
                    // line already has some room under it, hence 2 and 6)
                    Text("SCHEIDSEN · COACHEN · DELEN", bundle: textBundle)
                        .font(SharedFonts.system(11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(SharedColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(loc("Scheidsen, coachen, delen"))
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: HomeMenuHeader.logoSize)
            }
            // No frame: logo, name and tagline straight on the background, so
            // only real buttons look like cards (A3, 1 November 2026)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showingAccount) {
            WhatsNewAccountSheet(providers: accountProviders) { showingAccount = false }
        }
        .sheet(isPresented: $showingQuestion) {
            ManualQuestionSheet { showingQuestion = false }
        }
    }

}

public struct HomeMenuTiles: View {
    private let onCoach: () -> Void
    private let onReferee: () -> Void
    private let onHistory: () -> Void
    private let onPlayers: () -> Void
    private let onBadges: () -> Void
    /// Competitie (teamwedstrijden); the row only shows when the host wires it
    private let onCompetition: (() -> Void)?
    /// A live team match of the own team is running: the Competitie row shows LIVE
    private let competitionLive: Bool
    /// Sign in with Apple on iOS, for the account reminder; empty shows only e-mail
    private let accountProviders: [AccountProviderSignIn]
    /// "Maak je account" was tapped away
    @AppStorage(HomeAccountNudge.hiddenKey) private var accountNudgeHidden = false
    /// The Mijn team link: with one, Competitie sits behind the team card
    @AppStorage(LeagueTeamStorage.linkKey) private var teamLink = ""

    public init(onCoach: @escaping () -> Void, onReferee: @escaping () -> Void,
                onHistory: @escaping () -> Void, onPlayers: @escaping () -> Void, onBadges: @escaping () -> Void,
                onCompetition: (() -> Void)? = nil, competitionLive: Bool = false,
                accountProviders: [AccountProviderSignIn] = []) {
        self.accountProviders = accountProviders
        self.competitionLive = competitionLive
        self.onCoach = onCoach
        self.onReferee = onReferee
        self.onHistory = onHistory
        self.onPlayers = onPlayers
        self.onBadges = onBadges
        self.onCompetition = onCompetition
    }

    public var body: some View {
        // No heading above the tiles since A3 (1 November 2026): the tiles say
        // "Start met fluiten" and "Start met coachen" themselves, and the 30 pt
        // saved let the team card with its bar fit on an iPhone 15/16
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HomeMenuTile(title: loc("Scheidsrechter"), subtitle: loc("Start met fluiten"), icon: .referee, action: onReferee)
                HomeMenuTile(title: loc("Coach"), subtitle: loc("Start met coachen"), icon: .coach, action: onCoach)
            }
            // 4.0: only while matches wait for an answer (option B, Gerd-Jan, 10 November 2026)
            if HomeInboxBar.waiting > 0 {
                HomeInboxBar()
            } else if HomeAccountNudge.shows(hidden: accountNudgeHidden) {
                HomeAccountNudge(providers: accountProviders) { accountNudgeHidden = true }
            }
            // One row of icons instead of four rows (variant 2, Gerd-Jan 10 November
            // 2026): with Mijn team, Competitie opens from the team card ("Competitie ›")
            HStack(spacing: 8) {
                iconButton(loc("Wedstrijden"), accessibility: loc("Afgeronde wedstrijden"), icon: .history, action: onHistory)
                if let onCompetition, teamLink.isEmpty {
                    iconButton(loc("Competitie"), accessibility: loc("Competitie"), icon: .competition,
                               live: competitionLive, action: onCompetition)
                }
                iconButton(loc("Spelers"), accessibility: loc("Spelers"), icon: .players, action: onPlayers)
                iconButton(loc("Badges"), accessibility: loc("Badges"), icon: .badges, action: onBadges)
            }
        }
        .padding(.horizontal, 24)
        // After two weeks without team and account: the SBN card and Maak je account once more
        .onAppear {
            let account = PlayerAccount.shared
            if SetupReminder.check(hasTeam: !teamLink.isEmpty, hasAccount: account.isSignedIn) { accountNudgeHidden = false }
        }
        .task { await HomeInboxBar.follow() }
    }

    /// A square button in the icon row; `live` colours it sea green with a dot (a live team match)
    private func iconButton(_ title: String, accessibility: String, icon: HomeTileIcon, live: Bool = false,
                            action: @escaping () -> Void) -> some View {
        let tint = live ? SharedColors.support : SharedColors.accent
        return Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    HomeTileIconView(icon: icon, color: tint, size: 24)
                    if live {
                        Circle().fill(SharedColors.support).frame(width: 8, height: 8).offset(x: 5, y: -3)
                    }
                }
                Text(title)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(SharedColors.cardTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.25), lineWidth: 1))
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel(live ? accessibility + ", LIVE" : accessibility)
    }
}

/// Identical home team presentation for both native hosts; loading and navigation stay with the host.
public struct HomeTeamSummary: View {
    private let snapshot: LeagueTeamSnapshot
    /// Today's team match on this phone: it takes the place of the next match
    private let match: TeamMatch?
    /// 4.0: a team match a teammate (or the opponent) made that this phone can
    /// join; it takes the place of the next match while there is no own match
    private let offer: HomeTeamOffer?
    private let onOpen: () -> Void
    private let onMatch: (TeamMatch) -> Void

    public init(snapshot: LeagueTeamSnapshot, match: TeamMatch? = nil, offer: HomeTeamOffer? = nil,
                onOpen: @escaping () -> Void, onMatch: @escaping (TeamMatch) -> Void = { _ in }) {
        self.snapshot = snapshot
        self.match = match
        self.offer = offer
        self.onOpen = onOpen
        self.onMatch = onMatch
    }

    public var body: some View {
        // Since 1 November 2026 (Gerd-Jan; design "Mijn team-kaart varianten",
        // 3c and 3d): MIJN TEAM with Competitie › on top, the team name with
        // the stand as a badge on the right, and the next match as one row: a
        // date block, home or away and the opponent, and the opponent's stand
        // in the same badge, outlined. With the home screen on one page of a
        // regular iPhone; the three big numbers of 3.0 did not leave room for
        // the opponent.
        // On the day of a team match the bar is that match (design A, Gerd-Jan,
        // 7 November 2026): its own button to the team match, the rest to the team.
        let next = snapshot.nextFixture()
        VStack(spacing: 0) {
            Button(action: onOpen) {
                VStack(spacing: 0) {
                    teamPart
                    if match == nil, offer == nil, let next {
                        fixtureRow(next)
                            .padding(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SharedColors.accent.opacity(0.07))
                    }
                }
                #if !SKIP
                .contentShape(Rectangle())
                #endif
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("Mijn team: \(snapshot.name)"))
            if let match {
                HomeTeamMatchBar(match: match) { onMatch(match) }
            } else if let offer {
                HomeTeamOfferBar(offer: offer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A step lighter than the two tiles below (A3)
        .background(SharedColors.brandCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.brandCardStroke, lineWidth: 1))
        .foregroundColor(SharedColors.textPrimary)
    }

    private var teamPart: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MIJN TEAM", bundle: textBundle).font(SharedFonts.system(11, weight: .semibold))
                        .tracking(1.4).foregroundColor(SharedColors.accent)
                    Spacer()
                    Text("Competitie ›", bundle: textBundle).font(SharedFonts.system(12)).foregroundColor(SharedColors.textSecondary)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.name).font(SharedFonts.system(18, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(loc("\(number(snapshot.played)) gespeeld · \(number(snapshot.points)) punten"))
                            .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                            .foregroundColor(SharedColors.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    LeagueRankBadge(rank: snapshot.rank, filled: true)
                }
            }
            .padding(14)
    }

    // The next match in a tinted bar (variant 3d): the testers' and
    // Gerd-Jan's choice on 1 November 2026; the variant under a line is gone

    /// The next match: date block, "Thuis ·" or "Uit ·" with the opponent, the
    /// last result against them, and their stand as an outlined badge
    private func fixtureRow(_ next: LeagueFixture) -> some View {
        let ownIsHome = TeamMatch.sameTeam(next.home, snapshot.name)
        let info = snapshot.opponent(in: next)
        let opponentName = info?.name ?? (ownIsHome ? next.away : next.home)
        let side = ownIsHome ? loc("Thuis") : loc("Uit")
        let previous = LeagueOpponentText.previousLine(info)
        return HStack(spacing: 12) {
            // In the bar the block takes the card colour, so it still stands out
            LeagueDateBlock(date: next.date, fill: SharedColors.brandCard)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(side) ·").font(SharedFonts.system(13)).foregroundColor(SharedColors.textSecondary)
                    Text(opponentName).font(SharedFonts.system(13, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !previous.isEmpty {
                    Text(previous).font(SharedFonts.system(11)).foregroundColor(SharedColors.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let standing = info?.standing {
                LeagueRankBadge(rank: standing.rank, filled: false)
            }
        }
    }

    private func number(_ value: Int?) -> String {
        value.map { String($0) } ?? "–"
    }
}

/// A live team match this phone can join from the home card (4.0, teamwedstrijd vinden)
public struct HomeTeamOffer {
    /// "Kees heeft een teamwedstrijd aangemaakt" / "Squash City 2 houdt deze wedstrijd bij"
    public let title: String
    /// "Thuis · Bevo 3"
    public let detail: String
    public let joining: Bool
    public let onJoin: () -> Void

    public init(title: String, detail: String, joining: Bool, onJoin: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.joining = joining
        self.onJoin = onJoin
    }
}

/// The bar of a team match to join: the same place and height as the next
/// match, in the live colour, with Meedoen on the right
struct HomeTeamOfferBar: View {
    let offer: HomeTeamOffer

    var body: some View {
        Button(action: offer.onJoin) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.title)
                        .font(SharedFonts.system(13, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(offer.detail)
                        .font(SharedFonts.system(11))
                        .foregroundColor(SharedColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if offer.joining {
                    ProgressView()
                } else {
                    Text("Meedoen", bundle: textBundle)
                        .font(SharedFonts.system(13, weight: .semibold))
                        .foregroundColor(SharedColors.support)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .overlay(Capsule().stroke(SharedColors.support, lineWidth: 1.5))
                }
            }
            .padding(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.support.opacity(0.12))
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .disabled(offer.joining)
        .foregroundColor(SharedColors.textPrimary)
        .accessibilityLabel(offer.title)
    }
}

/// Today's team match, seen from the own team: LIVE or Vandaag, home or away
/// and the opponent, the games won by each, and the four partijen. A tap opens
/// that team match, where a partij is refereed or coached.
struct HomeTeamMatchBar: View {
    let match: TeamMatch
    let onOpen: () -> Void

    var body: some View {
        let score = match.score
        return Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if match.isProbablyLive() {
                        LivePill(text: "LIVE")
                    } else {
                        Text(match.isComplete ? loc("Afgelopen") : loc("Bezig"))
                            .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                            .foregroundColor(SharedColors.support)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(match.ownSide == TeamSide.home ? loc("Thuis") : loc("Uit")) ·")
                            .font(SharedFonts.system(13))
                            .foregroundColor(SharedColors.textSecondary)
                        Text(match.opponentName)
                            .font(SharedFonts.system(13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(score.ownGames)–\(score.theirGames)")
                        .font(SharedFonts.system(18, weight: .bold, design: .rounded))
                    AppSymbol("chevron.right", size: 12, color: SharedColors.textPrimary)
                }
                HStack(spacing: 6) {
                    ForEach(0..<match.partijen.count, id: \.self) { index in
                        partijChip(match.partijen[index])
                    }
                }
            }
            .padding(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.support.opacity(0.12))
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .foregroundColor(SharedColors.textPrimary)
        .accessibilityLabel(match.title)
    }

    /// "E1 3-1", won in the support colour; "–" when nothing is entered yet
    private func partijChip(_ partij: TeamPartij) -> some View {
        let color: Color = partij.ownWon == true ? SharedColors.support
            : partij.ownWon == false ? SharedColors.textSecondary
            : partij.hasEntry ? SharedColors.textPrimary : SharedColors.textMuted
        return HStack(spacing: 5) {
            Text(partij.label)
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textSecondary)
            Text(partij.hasEntry ? partij.standText : "–")
                .font(SharedFonts.system(12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(SharedColors.tint(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


/// All tiles share one accent colour, so the icon is what tells them apart
private struct HomeMenuTile: View {
    let title: String
    let subtitle: String
    let icon: HomeTileIcon
    let action: () -> Void

    private var color: Color { SharedColors.accent }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HomeTileIconView(icon: icon, color: color, size: 32)
                Text(title.uppercased())
                    .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SharedColors.textPrimary)
                    .multilineTextAlignment(.center)
                    // Large system text broke "SCHEIDSRECHTE / R" on Android: one line, a little smaller
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(SharedFonts.system(12))
                    .foregroundColor(SharedColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 110)
            // A step heavier than the team card above: the tiles carry the emphasis (A3)
            .background(SharedColors.tileCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.tileStroke, lineWidth: SharedColors.tileStrokeWidth))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The home tiles' icons, outlines like the sticker: a clipboard (coach), a
/// whistle (referee), history, a group (players), a medal (badges) and a cup
/// (competition). The clipboard also marks the coach card, everywhere.
/// Wedstrijdverzoeken (4.0): under the Scheidsrechter and Coach tiles while
/// matches wait in the Postvak, or team matches wait for a name ("Ben jij
/// X?"). A tap opens the Postvak itself; with nothing waiting the block is
/// gone. Before, the Postvak was only in Instellingen → Mijn account, where
/// nobody looks by themselves (Gerd-Jan's test, 10 November 2026).
struct HomeInboxBar: View {
    @State private var showing = false

    /// Matches that wait for an answer of the signed-in player; 0 without an account
    static var waiting: Int {
        let account = PlayerAccount.shared
        guard Features.shared.playerAccount, account.isSignedIn, account.profile != nil else { return 0 }
        return account.inbox.count + account.teamInbox.count
    }

    /// Asks the server for the Postvak while the home screen is up: at once,
    /// then every five minutes (the bar updates by itself when it changes)
    @MainActor
    static func follow() async {
        while !Task.isCancelled {
            let account = PlayerAccount.shared
            if Features.shared.playerAccount, account.isConfigured, account.isSignedIn {
                if !account.profileChecked { try? await account.loadProfile() }
                if account.profile != nil { try? await account.loadInbox() }
                // Your photo for the button top left
                if account.profile?.avatarVersion != nil && account.ownAvatar == nil { try? await account.loadOwnAvatar() }
            }
            // Avatars of linked players: AccountAvatars asks at most once an hour
            await AccountSync.shared.syncAvatars()
            try? await Task.sleep(nanoseconds: 300_000_000_000)
        }
    }

    private var detail: String {
        let account = PlayerAccount.shared
        if let first = account.inbox.first { return first.inboxTitle }
        if let first = account.teamInbox.first { return loc("Ben jij \"\(first.name ?? "")\"?") }
        return ""
    }

    var body: some View {
        let count = HomeInboxBar.waiting
        Button { showing = true } label: {
            HStack(spacing: 12) {
                AppSymbol("mailbox", size: 30, color: SharedColors.support)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEDSTRIJDVERZOEKEN", bundle: textBundle)
                        .font(SharedFonts.system(11, weight: .semibold))
                        .foregroundColor(SharedColors.support)
                    Text(count == 1 ? loc("1 wedstrijd wacht op je") : loc("\(count) wedstrijden wachten op je"))
                        .font(SharedFonts.system(13, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AppSymbol("chevron.right", size: 12, color: SharedColors.textPrimary)
            }
            .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SharedColors.support.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.support, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            #if !SKIP
            .contentShape(Rectangle())
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("Wedstrijdverzoeken"))
        .sheet(isPresented: $showing) {
            HomeInboxSheet { showing = false }
        }
    }
}

/// "Maak je account" (4.0, Gerd-Jan, 10 November 2026): in the place of
/// Wedstrijdverzoeken while there is no account, until one is made or the
/// cross taps it away. A tap opens Mijn account.
struct HomeAccountNudge: View {
    let providers: [AccountProviderSignIn]
    let onHide: () -> Void

    @State private var showing = false

    static let hiddenKey = SetupReminder.accountNudgeKey

    /// Signed out, or signed in without an account (once that is known)
    static func shows(hidden: Bool) -> Bool {
        let account = PlayerAccount.shared
        guard Features.shared.playerAccount, account.isConfigured, !hidden else { return false }
        if !account.isSignedIn { return true }
        return account.profileChecked && account.profile == nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { showing = true } label: {
                HStack(spacing: 12) {
                    AppSymbol("person.crop.circle", size: 26, color: SharedColors.accent, weight: .medium)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maak je account", bundle: textBundle)
                            .font(SharedFonts.system(13, weight: .semibold))
                            .foregroundColor(SharedColors.textPrimary)
                        Text("Dan zie je de teamwedstrijd van je team meteen en komen je partijen vanzelf binnen.", bundle: textBundle)
                            .font(SharedFonts.system(11))
                            .foregroundColor(SharedColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #if !SKIP
                .contentShape(Rectangle())
                #endif
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("Maak je account"))
            Button(action: onHide) {
                AppSymbol("xmark", size: 12, color: SharedColors.textMuted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("Niet meer tonen"))
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SharedColors.cardTint)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.accent.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showing) {
            WhatsNewAccountSheet(providers: providers) { showing = false }
        }
    }
}

/// The Postvak on its own, opened from the Wedstrijdverzoeken block
struct HomeInboxSheet: View {
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Wedstrijdverzoeken", bundle: textBundle)
                        .font(SharedFonts.system(18, weight: .semibold))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    Button(loc("Sluiten")) { onClose() }
                        .font(SharedFonts.system(14, weight: .semibold))
                        .foregroundColor(SharedColors.accent)
                }
                Text("Wedstrijden die een coach of scheidsrechter voor jou invulde. Kies per wedstrijd of hij meetelt.", bundle: textBundle)
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SharedAccountInbox()
            }
            .padding(20)
        }
        .background(SharedColors.background.ignoresSafeArea())
        .appAppearance()
    }
}

enum HomeTileIcon {
    case coach, referee, history, players, badges, competition, liveFollow

    /// The AppSymbol name; history is `MatchHistoryIconView`, the rest `OutlineIcon`
    var symbol: String {
        switch self {
        case .coach: return "list.bullet.clipboard"
        case .referee: return "whistle"
        case .history: return "clock.arrow.circlepath"
        case .players: return "person.2"
        case .badges: return "medal"
        case .competition: return "trophy"
        case .liveFollow: return "lock.iphone"
        }
    }
}

/// The home tiles' icons in one place, so the tour and the menu draw the same
struct HomeTileIconView: View {
    let icon: HomeTileIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        if icon == .history {
            MatchHistoryIconView(color: color, size: size)
                .accessibilityHidden(true)
        } else {
            AppSymbol(icon.symbol, size: size, color: color, weight: .medium)
                .frame(width: size, height: size)
        }
    }
}

/// Android's first screen: the Mijn team card (once a team link is saved in
/// Instellingen) above the five tiles; every tile and the gear lead somewhere.
public struct AndroidHomeView: View {
    private let playerStore: any PlayerProfileStore
    private let badgeStore: any PlayerBadgeSummaryStore
    private let historyStore: any MatchHistoryStore
    @State private var showingPlayers = false
    @State private var showingCoach = false
    @State private var showingReferee = false
    @State private var showingBadges = false
    @State private var showingHistory = false
    /// A coach match opened for its analysis from Afgeronde wedstrijden
    @State private var analysedMatch: Match? = nil
    @State private var showingSettings = false
    /// Instellingen opens with Mijn team unfolded
    @State private var settingsOpensTeam = false
    @State private var showingTeam = false
    @State private var team: LeagueTeamSnapshot?
    /// The tour version seen; the tour shows by itself until it is current
    @AppStorage(Onboarding.storageKey) private var tourSeen = 0
    /// The "Nieuw in 3.0" version seen; it comes first, with the tour as a choice
    @AppStorage(WhatsNew.storageKey) private var whatsNewSeen = 0
    @AppStorage(WhatsNew.buildStorageKey) private var whatsNewBuildSeen = ""
    /// "Testgegevens opruimen" was answered (once, after the badge reset)
    @AppStorage(TestDataCleanup.storageKey) private var testDataCleanupDone = false
    /// What the cleanup question offers; set when there is something to clean up
    @State private var testDataCounts: TestDataCounts? = nil
    /// The test period's matches (Android supplies Room)
    private let testDataStore: (any TestDataCleanupStore)?
    private let matchStore: any CoachMatchStore
    private let refereeMatchStore: any RefereeMatchStore
    /// Opens the platform share sheet with a text (a card link); Android's
    /// `MainActivity` supplies `Intent.ACTION_SEND`
    private let shareText: (String) -> Void
    /// A card link opened from outside the app; the import screen shows while one is pending
    private let cardInbox: CardInbox
    private let cardImportStore: any CardImportStore
    /// Fetches Mijn team from sbn.toernooi.nl (Android supplies the page loader)
    private let leagueTeamFetcher: LeagueTeamFetcher
    private var settingsContext: SettingsContext {
        var context = SettingsContext(aiCoach: aiCoach, backup: backup, onLanguage: onLanguage)
        context.leagueFetcher = leagueTeamFetcher
        return context
    }
    /// AI Coach (Android supplies the key store and the sender)
    private let aiCoach: AICoachContext?
    /// Backups in Instellingen (Android supplies Room and the file pickers)
    private let backup: BackupContext?
    /// Player photos and the system pickers (Android)
    private let photoStore: (any PlayerPhotoStore)?
    private let filePicker: (any PlayerFilePicker)?
    /// "Deel kaart" with a picture (Android draws it)
    private let shareCard: ((CardSnapshot, String) -> Void)?
    /// Competitie: team matches in a JSON file (Android supplies its files directory)
    private let teamMatchStore: (any TeamMatchStore)?
    /// Instellingen → Taal: the system's per-app language screen (Android's
    /// MainActivity supplies it); nil hides the row
    private let onLanguage: ((String) -> Void)?
    @State private var showingCompetition = false
    /// Opened from the bar on the Mijn team card
    @State private var openedTeamMatch: TeamMatch? = nil

    public init(playerStore: any PlayerProfileStore, badgeStore: any PlayerBadgeSummaryStore,
                historyStore: any MatchHistoryStore,
                matchStore: any CoachMatchStore, refereeMatchStore: any RefereeMatchStore,
                shareText: @escaping (String) -> Void,
                cardInbox: CardInbox, cardImportStore: any CardImportStore,
                leagueTeamFetcher: LeagueTeamFetcher, aiCoach: AICoachContext? = nil, backup: BackupContext? = nil,
                photoStore: (any PlayerPhotoStore)? = nil,
                filePicker: (any PlayerFilePicker)? = nil, shareCard: ((CardSnapshot, String) -> Void)? = nil,
                teamMatchStore: (any TeamMatchStore)? = nil, testDataStore: (any TestDataCleanupStore)? = nil,
                onLanguage: ((String) -> Void)? = nil) {
        self.onLanguage = onLanguage
        self.teamMatchStore = teamMatchStore
        self.testDataStore = testDataStore
        self.photoStore = photoStore
        self.filePicker = filePicker
        self.leagueTeamFetcher = leagueTeamFetcher
        self.backup = backup
        self.aiCoach = aiCoach
        self.shareText = shareText
        self.shareCard = shareCard
        self.cardInbox = cardInbox
        self.cardImportStore = cardImportStore
        self.playerStore = playerStore
        self.badgeStore = badgeStore
        self.historyStore = historyStore
        self.matchStore = matchStore
        self.refereeMatchStore = refereeMatchStore
    }

    public var body: some View {
        NavigationStack {
            homeContent
                .navigationDestination(isPresented: $showingPlayers) {
                    PlayerDirectoryView(store: playerStore, badgeStore: badgeStore, shareText: shareText, cardInbox: cardInbox,
                                        photoStore: photoStore, filePicker: filePicker, shareCard: shareCard, historyStore: historyStore)
                }
                .navigationDestination(isPresented: $showingCoach) {
                    CoachSessionView(store: matchStore, playerStore: playerStore, photoStore: photoStore, filePicker: filePicker, aiCoach: aiCoach, shareText: shareText,
                                     historyStore: historyStore, settings: settingsContext,
                                     teamMatchStore: teamMatchStore,
                                     onExit: { showingCoach = false })
                        .navigationBarBackButtonHidden(true)
                        // These screens have their own header; without this Android keeps
                        // an empty bar of 65 dp above it (OnePlus Nord 3, 7 November 2026)
                        #if SKIP
                        .toolbar(.hidden, for: .navigationBar)
                        #endif
                }
                .navigationDestination(isPresented: $showingReferee) {
                    RefereeSessionView(store: refereeMatchStore, playerStore: playerStore, photoStore: photoStore, filePicker: filePicker, shareText: shareText,
                                       settings: settingsContext,
                                       teamMatchStore: teamMatchStore, historyStore: historyStore, onExit: { showingReferee = false })
                        .navigationBarBackButtonHidden(true)
                        // These screens have their own header; without this Android keeps
                        // an empty bar of 65 dp above it (OnePlus Nord 3, 7 November 2026)
                        #if SKIP
                        .toolbar(.hidden, for: .navigationBar)
                        #endif
                }
                .navigationDestination(isPresented: $showingBadges) {
                    SharedBadgeCatalogView()
                }
                .navigationDestination(isPresented: $showingHistory) {
                    SharedMatchHistoryView(store: historyStore, aiCoach: aiCoach, shareText: shareText) { match in
                        // As on iOS: the list closes and the analysis opens
                        showingHistory = false
                        analysedMatch = match
                    }
                }
                .navigationDestination(isPresented: $showingSettings) {
                    SharedSettingsView(aiCoach: aiCoach, backup: backup, onLanguage: onLanguage, leagueFetcher: leagueTeamFetcher,
                                       opensTeam: settingsOpensTeam)
                }
                .navigationDestination(isPresented: $showingTeam) {
                    if let team {
                        SharedLeagueTeamDetailView(snapshot: team, fetcher: leagueTeamFetcher, teamMatches: teamMatchStore,
                                                   tools: TeamMatchTools(historyStore: historyStore, playerStore: playerStore, coachStore: matchStore,
                                                                         refereeStore: refereeMatchStore, photoStore: photoStore, filePicker: filePicker,
                                                                         aiCoach: aiCoach, shareText: shareText, leagueFetcher: leagueTeamFetcher))
                    }
                }
                .navigationDestination(isPresented: $showingCompetition) {
                    if let teamMatchStore {
                        SharedTeamMatchesView(
                            store: teamMatchStore,
                            tools: TeamMatchTools(historyStore: historyStore, playerStore: playerStore, coachStore: matchStore,
                                                  refereeStore: refereeMatchStore, photoStore: photoStore, filePicker: filePicker,
                                                  aiCoach: aiCoach, shareText: shareText, leagueFetcher: leagueTeamFetcher),
                            team: TeamMatchSupport.cachedTeam())
                    }
                }
                .navigationDestination(isPresented: Binding(get: { openedTeamMatch != nil }, set: { if !$0 { openedTeamMatch = nil } })) {
                    if let teamMatchStore, let match = openedTeamMatch {
                        SharedTeamMatchView(match: match, store: teamMatchStore,
                                            tools: TeamMatchTools(historyStore: historyStore, playerStore: playerStore, coachStore: matchStore,
                                                                  refereeStore: refereeMatchStore, photoStore: photoStore, filePicker: filePicker,
                                                                  aiCoach: aiCoach, shareText: shareText, leagueFetcher: leagueTeamFetcher),
                                            team: TeamMatchSupport.cachedTeam()) { _ in }
                    }
                }
        }
        // "Nieuw in 3.0" (with the tour as a choice), or the tour alone once it is raised
        .trackedCover(isPresented: Binding(get: { welcomeNeeded },
                                           set: { if !$0 { welcomeSeen() } })) {
            if whatsNewNeeded {
                SharedWhatsNewView(manual: UserManual.android, onTeamLink: {
                    welcomeSeen()
                    settingsOpensTeam = true
                    showingSettings = true
                }) { welcomeSeen() }
            } else {
                SharedOnboardingView(manual: UserManual.android, onTeamLink: {
                    welcomeSeen()
                    settingsOpensTeam = true
                    showingSettings = true
                }) { welcomeSeen() }
            }
        }
        // 4.0: a match someone shared for your account ("Stuur naar speler")
        .sheet(isPresented: Binding(get: { PlayerAccount.shared.pendingClaim != nil },
                                    set: { open in if !open { PlayerAccount.shared.pendingClaim = nil } })) {
            if let token = PlayerAccount.shared.pendingClaim {
                SharedAccountClaimSheet(token: token) { PlayerAccount.shared.pendingClaim = nil }
            }
        }
        .sheet(isPresented: Binding(get: { testDataCounts != nil && !welcomeNeeded },
                                    set: { if !$0 { testDataCounts = nil } })) {
            if let counts = testDataCounts, let start = BadgeSeason.start, let testDataStore {
                SharedTestDataCleanupView(counts: counts, before: start, store: testDataStore) {
                    testDataCleanupDone = true
                    testDataCounts = nil
                }
            }
        }
        .task { await offerTestDataCleanup() }
        .sheet(isPresented: Binding(get: { cardInbox.pending != nil },
                                    set: { if !$0 { cardInbox.pending = nil } })) {
            if let snapshot = cardInbox.pending {
                SharedCardImportView(snapshot: snapshot, store: cardImportStore) { imported in
                    if imported { cardInbox.finishImport() } else { cardInbox.pending = nil }
                }
            }
        }
        .sheet(isPresented: Binding(get: { cardInbox.pendingTeam != nil }, set: { if !$0 { cardInbox.pendingTeam = nil } })) {
            // A link to a live team match was opened: join it
            if let invite = cardInbox.pendingTeam, let teamMatchStore {
                SharedTeamJoinView(store: teamMatchStore, team: TeamMatchSupport.cachedTeam(), initialCode: invite.code) { _ in
                    cardInbox.pendingTeam = nil
                    showingCompetition = true
                } onCancel: { cardInbox.pendingTeam = nil }
            }
        }
        .sheet(isPresented: Binding(get: { analysedMatch != nil }, set: { if !$0 { analysedMatch = nil } })) {
            if let match = analysedMatch {
                SharedCoachDashboardView(match: match, game: match.games.last ?? match.currentGame, aiCoach: aiCoach,
                                         shareText: shareText) { analysedMatch = nil }
            }
        }
        .appAppearance()
    }

    /// After the badge reset, once: offers to remove the test period's matches
    /// when there are any; with nothing to remove the question is done at once
    private func offerTestDataCleanup() async {
        guard TestDataCleanup.shouldOffer(done: testDataCleanupDone), let start = BadgeSeason.start, let testDataStore else { return }
        guard let counts = try? await testDataStore.counts(before: start) else { return }
        if counts.needsSheet { testDataCounts = counts } else { testDataCleanupDone = true }
    }

    /// "Nieuw in 3.0" or the tour still has to show
    private var welcomeNeeded: Bool {
        whatsNewNeeded || Onboarding.shouldShow(seenVersion: tourSeen)
    }

    /// "Nieuw in 4.0" once per test build: the version text holds the build ("Android 4.0 (2)")
    private var whatsNewNeeded: Bool {
        WhatsNew.shouldShow(seenVersion: whatsNewSeen, seenBuild: whatsNewBuildSeen, build: backup?.appVersion ?? "")
    }

    /// Both seen, whether the tour was chosen or skipped: neither comes back by itself
    private func welcomeSeen() {
        whatsNewSeen = WhatsNew.currentVersion
        whatsNewBuildSeen = backup?.appVersion ?? ""
        tourSeen = Onboarding.currentVersion
    }

    private var homeContent: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            SamplePlayersQuestion(store: playerStore, waiting: welcomeNeeded || testDataCounts != nil)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        HomeMenuHeader(onSettings: { settingsOpensTeam = false; showingSettings = true })
                        SharedLeagueTeamCard(fetcher: leagueTeamFetcher, onTeam: { snapshot in
                            let store = playerStore
                            Task { _ = await TeamRosterSync.run(snapshot, store: store) }
                        }, onSetup: { settingsOpensTeam = true; showingSettings = true },
                           teamMatches: teamMatchStore,
                           matchesPaused: showingCompetition || openedTeamMatch != nil || showingTeam || showingCoach || showingReferee,
                           onTeamMatch: { match in openedTeamMatch = match }) { snapshot in
                            team = snapshot
                            showingTeam = true
                        }
                        HomeMenuTiles(
                            onCoach: { showingCoach = true },
                            onReferee: { showingReferee = true },
                            onHistory: { showingHistory = true },
                            onPlayers: { showingPlayers = true },
                            onBadges: { showingBadges = true },
                            onCompetition: teamMatchStore == nil ? nil : { showingCompetition = true }
                        )
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }
}

/// A small outlined pill in the support colour: "LIVE", "2 LIVE". The one
/// marker for everything live on the home screen (1 November 2026).
struct LivePill: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(SharedColors.support).frame(width: 6, height: 6)
            Text(text)
                .font(SharedFonts.system(11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(SharedColors.support)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .overlay(Capsule().stroke(SharedColors.support.opacity(0.45), lineWidth: 1))
        .accessibilityLabel(loc("Live"))
    }
}
