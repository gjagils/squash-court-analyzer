import SwiftUI
import SwiftData

/// Circular player avatar in the referee style: the saved player's photo when one
/// exists for this name, otherwise the person icon. `active` = the serving/selected
/// player (full-strength ring), inactive players are dimmed.
struct PlayerAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 52
    var active: Bool = true

    @Query private var players: [SavedPlayer]

    init(name: String, color: Color, size: CGFloat = 52, active: Bool = true) {
        self.name = name
        self.color = color
        self.size = size
        self.active = active
        _players = Query(filter: #Predicate<SavedPlayer> { $0.name == name })
    }

    private var photo: UIImage? {
        players.first?.photoData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        PlayerAvatarImage(photo: photo, color: color, size: size, active: active)
    }
}

/// The drawing part, usable when the photo is already at hand (player list, edit sheet)
struct PlayerAvatarImage: View {
    let photo: UIImage?
    let color: Color
    var size: CGFloat = 52
    var active: Bool = true

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .opacity(active ? 1.0 : 0.55)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundColor(color.opacity(active ? 1.0 : 0.4))
            }
            Circle()
                .stroke(color.opacity(active ? 1.0 : 0.4), lineWidth: 2)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}
