import SwiftUI
import Foundation
import SquashAnalyzerCore


/// The text colours of a player's column on the coach and referee screens,
/// on iOS and Android: the server's name and score in white, the receiver's in
/// the player colour. One rule, so all four screens change together.
public struct ServerHighlight {
    public let name: Color
    public let score: Color
    /// "TIK = PUNT" under the referee score
    public let caption: Color

    public init(color: Color, isServer: Bool) {
        name = isServer ? SharedColors.textPrimary : color
        score = isServer ? SharedColors.textPrimary : color
        caption = isServer ? SharedColors.textPrimary.opacity(0.8) : color.opacity(0.55)
    }
}

/// Links/Rechts service box picker, same rules on both platforms.
public struct ServiceSideSelector: View {
    let side: ServerSide
    let preferredSide: ServerSide?
    let color: Color
    var compact: Bool = false
    var disabled: Bool = false
    let onSelect: (ServerSide) -> Void

    public init(side: ServerSide, preferredSide: ServerSide?, color: Color, compact: Bool = false, disabled: Bool = false, onSelect: @escaping (ServerSide) -> Void) {
        self.side = side
        self.preferredSide = preferredSide
        self.color = color
        self.compact = compact
        self.disabled = disabled
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: compact ? 2.0 : 3.0) {
            Text("SERVICE")
                .font(.system(size: compact ? 8.0 : 9.0, weight: .medium, design: .rounded))
                .foregroundColor(color.opacity(0.6))
                .tracking(1)

            HStack(spacing: compact ? 4.0 : 6.0) {
                chip("Links", .left)
                chip("Rechts", .right)
            }
        }
    }

    private func chip(_ label: String, _ box: ServerSide) -> some View {
        let active = side == box
        return Button(action: { onSelect(box) }) {
            HStack(spacing: 3) {
                if preferredSide == box {
                    AppSymbol("pin.fill", size: 7, color: active ? SharedColors.background : color.opacity(0.4))
                }
                Text(label)
                    .font(.system(size: compact ? 11.0 : 12.0, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(active ? SharedColors.background : color.opacity(0.4))
            .padding(.horizontal, compact ? 8.0 : 10.0)
            .padding(.vertical, compact ? 4.0 : 5.0)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? color : color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(active ? 0.0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(active || disabled)
    }
}

/// Small glowing dot shown next to the serving player's name.
public struct ServerIndicator: View {
    var isServing: Bool = true

    public init(isServing: Bool = true) {
        self.isServing = isServing
    }

    public var body: some View {
        Circle()
            .fill(isServing ? SharedColors.serverIndicator : Color.clear)
            .frame(width: 8, height: 8)
            .shadow(color: isServing ? SharedColors.serverIndicator.opacity(0.8) : .clear, radius: 4, x: 0, y: 0)
    }
}

/// Circular player avatar without a photo (Android/shared): initials-free
/// person icon with a colored ring, dimmed when not the active/serving player.
/// iOS keeps its own `PlayerAvatar` for the SwiftData-backed photo lookup.
public struct PlayerAvatarPlaceholder: View {
    let color: Color
    var size: CGFloat = 52
    var active: Bool = true
    /// The picked player's photo, if they have one
    var photo: Data? = nil

    public init(color: Color, size: CGFloat = 52, active: Bool = true, photo: Data? = nil) {
        self.color = color
        self.size = size
        self.active = active
        self.photo = photo
    }

    public var body: some View {
        ZStack {
            if let photo {
                PlayerPhotoView(photo: photo, name: "", size: size - 4, color: color)
                    .opacity(active ? 1.0 : 0.6)
            } else {
                AppSymbol("person.fill", size: size * 0.42, color: color.opacity(active ? 1.0 : 0.4))
            }
            Circle()
                .stroke(color.opacity(active ? 1.0 : 0.4), lineWidth: 2)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

/// Player photos for the scoreboards and result cards, by picked player id
/// and, as on iOS (`PlayerAvatar`), by name: a typed-in name that matches a
/// saved player shows that player's photo too.
enum PlayerPhotos {
    static func nameKey(_ name: String) -> String { "name:" + name }

    /// Photos by id plus "name:<name>" entries for every saved player with a photo
    @MainActor
    static func load(photoStore: (any PlayerPhotoStore)?, playerStore: any PlayerProfileStore) async -> [String: Data] {
        guard let photoStore else { return [:] }
        var result = (try? await photoStore.photos()) ?? [:]
        let players = (try? await playerStore.loadPlayers()) ?? []
        for player in players {
            if let photo = result[player.id] { result[nameKey(player.name)] = photo }
        }
        return result
    }

    static func photo(in photos: [String: Data], id: UUID?, name: String) -> Data? {
        if let id, let photo = photos[id.uuidString] { return photo }
        return photos[nameKey(name.trimmingCharacters(in: .whitespaces))]
    }
}

/// iOS' AppBackground for the shared screens: dark base, a warm glow from the
/// bottom, a faint one from the top and a dark vignette
/// Screen background: true black (docs/style/tokens.json)
struct GlowBackground: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}
