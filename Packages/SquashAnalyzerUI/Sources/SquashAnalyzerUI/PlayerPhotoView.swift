import SwiftUI
import Foundation
#if SKIP
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
#endif

/// A player's photo in a circle, or the first letter of the name when there
/// is none. On Android the JPEG bytes are drawn through Compose (Skip has no
/// `Image(data:)`); on Apple through UIImage.
struct PlayerPhotoView: View {
    let photo: Data?
    let name: String
    let size: CGFloat
    let color: Color

    var body: some View {
        if let photo, hasImage(photo) {
            image(photo)
        } else {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(color.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private func hasImage(_ data: Data) -> Bool {
        #if SKIP
        return BitmapFactory.decodeByteArray(data.platformValue, 0, data.count) != nil
        #elseif canImport(UIKit)
        return UIImage(data: data) != nil
        #else
        return false
        #endif
    }

    @ViewBuilder
    private func image(_ data: Data) -> some View {
        #if SKIP
        ComposeView { context in
            if let bitmap = BitmapFactory.decodeByteArray(data.platformValue, 0, data.count) {
                Image(bitmap: bitmap.asImageBitmap(), contentDescription: nil, contentScale: ContentScale.Crop,
                      modifier: context.modifier.size(size.dp).clip(CircleShape))
            }
        }
        #elseif canImport(UIKit)
        Image(uiImage: UIImage(data: data) ?? UIImage())
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
        #else
        EmptyView()
        #endif
    }
}
