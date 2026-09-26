import SwiftUI
import SwiftData

// MARK: - Share buttons on the badge screen

/// "Deel kaart" (image plus snapshot link, for WhatsApp) and "Nodig coach uit"
/// (the CloudKit invitation), plus the sharing status of the card.
struct CardShareActions: View {
    let player: SavedPlayer

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [SavedPlayerCard]
    @State private var shareItems: ShareItemsWrapper?
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var showingStopConfirm = false

    init(player: SavedPlayer) {
        self.player = player
        let cardId = player.badgeCardId
        _cards = Query(filter: #Predicate<SavedPlayerCard> { $0.cardId == cardId })
    }

    private var card: SavedPlayerCard? { cards.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let card {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text(card.isOwner ? "Gedeelde kaart · nieuwe badges gaan automatisch mee"
                                      : "Gekoppelde kaart · nieuwe badges gaan automatisch mee")
                        .font(AppFonts.caption(12))
                }
                .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 10) {
                actionButton("Deel kaart", icon: "square.and.arrow.up") { shareSnapshot() }
                actionButton(isInviting ? "Bezig…" : "Nodig coach uit", icon: "person.badge.plus") { invite() }
                    .disabled(isInviting)
            }

            if let card {
                Button(card.isOwner ? "Stop met delen" : "Ontkoppel kaart") { showingStopConfirm = true }
                    .font(AppFonts.caption(13))
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .sheet(item: $shareItems) { wrapper in
            ShareSheet(items: wrapper.items)
        }
        .alert("Delen lukt niet", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(card?.isOwner == true ? "Stoppen met delen?" : "Kaart ontkoppelen?",
                            isPresented: $showingStopConfirm, titleVisibility: .visible) {
            Button(card?.isOwner == true ? "Stop met delen" : "Ontkoppel", role: .destructive) { stopSharing() }
            Button("Annuleren", role: .cancel) { }
        } message: {
            Text(card?.isOwner == true
                 ? "De andere coaches zien de kaart dan niet meer bijwerken. De badges blijven op dit toestel."
                 : "Nieuwe badges worden dan niet meer gedeeld. De badges blijven op dit toestel.")
        }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        let color = AppColors.accentGold
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(AppFonts.label(12))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func shareSnapshot() {
        do {
            let snapshot = try CardStore(context: modelContext).snapshot(for: player)
            let url = try snapshot.webURL()
            var items: [Any] = []
            if let image = PlayerCardImage.render(snapshot: snapshot) { items.append(image) }
            items.append("Badgekaart van \(player.name): \(url.absoluteString)")
            shareItems = ShareItemsWrapper(items: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func invite() {
        isInviting = true
        Task {
            defer { isInviting = false }
            do {
                let url = try await CardSync.shared.invitationURL(for: player)
                shareItems = ShareItemsWrapper(items: [
                    "Koppel de badgekaart van \(player.name) in Squash Analyzer, dan tellen jouw badges voor \(player.name) ook mee: \(url.absoluteString)"
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopSharing() {
        guard let card else { return }
        Task {
            do {
                try await CardSync.shared.stopSharing(card)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Image of the card for WhatsApp

struct PlayerCardImage: View {
    let snapshot: CardSnapshot

    /// Earned badges with how often, in catalogue order
    private var earned: [(kind: BadgeKind, count: Int)] {
        let active = snapshot.awards.filter { $0.deletedAt == nil }
        return BadgeKind.allCases.compactMap { kind in
            let count = active.filter { $0.badge == kind }.count
            return count > 0 ? (kind, count) : nil
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
                Text("\(earned.count) van \(BadgeKind.allCases.count) badges")
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

/// Shown when a card link or an invitation is opened: link it to a local
/// player (or a new one) and merge its badges.
struct CardImportSheet: View {
    let pending: PendingCard
    /// Closes the sheet when it is presented from UIKit (see `CardImportPresenter`)
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlayer.name) private var players: [SavedPlayer]
    @State private var errorMessage: String?

    private var linkedPlayer: SavedPlayer? { players.first { $0.badgeCardId == pending.cardId } }

    private var preview: (new: Int, deleted: Int) {
        (try? CardStore(context: modelContext).preview(pending.awards)) ?? (0, 0)
    }

    private var isInvitation: Bool {
        if case .share = pending.source { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pending.name)
                            .font(AppFonts.title(20))
                            .foregroundColor(AppColors.textPrimary)
                        Text(summary)
                            .font(AppFonts.body(13))
                            .foregroundColor(AppColors.textSecondary)
                        if isInvitation {
                            Text("Na het koppelen gaan nieuwe badges van deze speler automatisch naar de gedeelde kaart.")
                                .font(AppFonts.caption(12))
                                .foregroundColor(AppColors.textMuted)
                        }
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
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                } else {
                    Section("Koppel aan") {
                        Button {
                            link(to: nil)
                        } label: {
                            Label("Nieuwe speler \(pending.name)", systemImage: "person.badge.plus")
                                .foregroundColor(AppColors.accentGold)
                        }
                        .listRowBackground(Color.white.opacity(0.05))

                        ForEach(players) { player in
                            Button {
                                link(to: player)
                            } label: {
                                HStack {
                                    Text(player.name)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if player.name.localizedCaseInsensitiveCompare(pending.name) == .orderedSame {
                                        Text("zelfde naam")
                                            .font(AppFonts.caption(11))
                                            .foregroundColor(AppColors.textMuted)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Spelerskaart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { close() }
                }
            }
            .alert("Koppelen mislukt", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summary: String {
        let active = pending.awards.filter { $0.deletedAt == nil }.count
        let preview = preview
        var parts = [active == 1 ? "1 badge op de kaart" : "\(active) badges op de kaart"]
        if preview.new > 0 { parts.append(preview.new == 1 ? "1 nieuw voor jou" : "\(preview.new) nieuw voor jou") }
        if preview.deleted > 0 { parts.append("\(preview.deleted) verwijderd") }
        if linkedPlayer != nil, preview.new == 0, preview.deleted == 0 { parts.append("je bent al bij") }
        return parts.joined(separator: " · ")
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func link(to player: SavedPlayer?) {
        do {
            try CardSync.shared.completeLink(pending, to: player)
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
    static func present(_ pending: PendingCard, container: ModelContainer) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        var top = root
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        var host: UIViewController?
        let sheet = CardImportSheet(pending: pending) {
            host?.dismiss(animated: true)
            CardSync.shared.inbox = nil
        }
        let controller = UIHostingController(rootView: AnyView(sheet.modelContainer(container)))
        controller.isModalInPresentation = true
        host = controller
        top.present(controller, animated: true)
    }
}
