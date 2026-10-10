import SwiftUI
import SquashAnalyzerUI
import SwiftData
import SquashAnalyzerCore

// MARK: - Share button on the badge screen

// MARK: - Image of the card for WhatsApp

struct PlayerCardImage: View {
    let snapshot: CardSnapshot

    /// Earned badges with how often, in catalogue order: per badge the highest
    /// tier earned, counted by the tier with the most moments (bronze comes
    /// with every silver or gold), like the shared badge screen
    private var earned: [(kind: BadgeKind, count: Int)] {
        let active = snapshot.awards.filter { $0.deletedAt == nil }
        return BadgeKind.families.compactMap { family in
            var best: BadgeKind? = nil
            var count = 0
            for kind in family.series {
                let moments = active.filter { award in award.badge == kind }.count
                if moments > 0 { best = kind }
                count = max(count, moments)
            }
            guard let best else { return nil }
            return (best, count)
        }
    }

    private var rows: [[(kind: BadgeKind, count: Int)]] {
        stride(from: 0, to: earned.count, by: 4).map { Array(earned[$0..<min($0 + 4, earned.count)]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("BADGEKAART")
                    .font(AppFonts.label(12))
                    .tracking(2)
                    .foregroundColor(AppColors.accentGold)
                Spacer()
                Text("Squash Analyzer")
                    .font(AppFonts.caption(11))
                    .foregroundColor(AppColors.textMuted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.name)
                    .font(AppFonts.title(24))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(earned.count) van \(BadgeKind.families.count) badges")
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textSecondary)
            }
            if earned.isEmpty {
                Text("Nog geen badges verdiend")
                    .font(AppFonts.body(13))
                    .foregroundColor(AppColors.textMuted)
            }
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(rows[index], id: \.kind) { item in
                        VStack(spacing: 4) {
                            BadgeView(kind: item.kind, size: 68, showsTitle: false)
                            Text("\(item.count)×")
                                .font(AppFonts.label(13))
                                .foregroundColor(AppColors.accentGold)
                            Text(item.kind.title)
                                .font(AppFonts.caption(10))
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 72)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .background(AppColors.backgroundDark)
    }

    @MainActor
    static func render(snapshot: CardSnapshot) -> UIImage? {
        let renderer = ImageRenderer(content: PlayerCardImage(snapshot: snapshot))
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - Linking a card that came in

/// Shown when a card link is opened: link it to a local player (or a new one)
/// and merge its badges. Android's `SharedCardImportView` does the same.
struct CardImportSheet: View {
    let snapshot: CardSnapshot
    /// Closes the sheet when it is presented from UIKit (see `CardImportPresenter`)
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayer.name) private var players: [SavedPlayer]
    @State private var errorMessage: String?

    private var linkedPlayer: SavedPlayer? { players.first { $0.badgeCardId == snapshot.cardId } }

    private var preview: (new: Int, deleted: Int) {
        (try? CardStore(context: modelContext).preview(snapshot.awards)) ?? (0, 0)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.name)
                            .font(AppFonts.title(20))
                            .foregroundColor(AppColors.textPrimary)
                        Text(summary)
                            .font(AppFonts.body(13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .listRowBackground(Color.clear)
                }

                if let linkedPlayer {
                    Section {
                        Button {
                            link(to: linkedPlayer)
                        } label: {
                            Label("Bijwerken bij \(linkedPlayer.name)", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(AppColors.accentGold)
                        }
                        .listRowBackground(SharedColors.tint(0.05))
                    }
                } else {
                    Section("Koppel aan") {
                        Button {
                            link(to: nil)
                        } label: {
                            Label("Nieuwe speler \(snapshot.name)", systemImage: "person.badge.plus")
                                .foregroundColor(AppColors.accentGold)
                        }
                        .listRowBackground(SharedColors.tint(0.05))

                        ForEach(players) { player in
                            Button {
                                link(to: player)
                            } label: {
                                HStack {
                                    Text(player.name)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if player.name.localizedCaseInsensitiveCompare(snapshot.name) == .orderedSame {
                                        Text("zelfde naam")
                                            .font(AppFonts.caption(11))
                                            .foregroundColor(AppColors.textMuted)
                                    }
                                }
                            }
                            .listRowBackground(SharedColors.tint(0.05))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .pageTitle("Spelerskaart")
            .toolbar {
                CloseToolbarItem(title: "Annuleren") { close() }
            }
            .alert("Koppelen mislukt", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(SharedColors.preferredScheme)
    }

    /// Same wording as Android, from `CardImportPreview.summary`
    private var summary: String {
        let preview = preview
        return CardImportPreview(activeBadges: snapshot.awards.filter { $0.deletedAt == nil }.count,
                                 newBadges: preview.new, deletedBadges: preview.deleted,
                                 linkedPlayer: linkedPlayer.map { CardImportPlayer(id: $0.id.uuidString, name: $0.name) },
                                 players: []).summary
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func link(to player: SavedPlayer?) {
        do {
            let store = CardStore(context: modelContext)
            try store.link(cardId: snapshot.cardId, name: snapshot.name, to: player)
            try store.merge(snapshot.awards)
            try modelContext.save()
            close()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Shows the import sheet on top of whatever is on screen (a player list, a
/// match, the history), so an opened card link never has to wait.
@MainActor
enum CardImportPresenter {
    /// The sheet that is (or was) on screen. When the screen under it closes
    /// (a full-screen cover), UIKit takes the sheet along without telling
    /// anyone: this is how that is noticed.
    private static weak var shown: UIViewController?

    /// Whether the import sheet is really on screen now
    static var isShowing: Bool {
        guard let shown else { return false }
        return shown.presentingViewController != nil && shown.view.window != nil
    }

    /// Presents the import sheet on top of whatever is showing. False when
    /// there is no window yet (a cold start from a link): try again later.
    @discardableResult
    static func present(_ snapshot: CardSnapshot, container: ModelContainer, onClose: @escaping () -> Void) -> Bool {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return false }
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        var host: UIViewController?
        let sheet = CardImportSheet(snapshot: snapshot) {
            host?.dismiss(animated: true)
            onClose()
        }
        let controller = UIHostingController(rootView: AnyView(sheet.modelContainer(container)))
        controller.isModalInPresentation = true
        host = controller
        shown = controller
        top.present(controller, animated: true)
        return true
    }
}
