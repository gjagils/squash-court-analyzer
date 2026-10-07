import SwiftUI
import SquashAnalyzerUI
import SwiftData

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
                    .font(SharedFonts.system(size * 0.42))
                    .foregroundColor(color.opacity(active ? 1.0 : 0.4))
            }
            Circle()
                .stroke(color.opacity(active ? 1.0 : 0.4), lineWidth: 2)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

