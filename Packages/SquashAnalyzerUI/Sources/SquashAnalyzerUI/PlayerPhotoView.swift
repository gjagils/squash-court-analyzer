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
        // Decoded once per render; the bytes are drawn straight from the result (T18)
        #if SKIP
        if let photo, let bitmap = BitmapFactory.decodeByteArray(photo.platformValue, 0, photo.count) {
            ComposeView { context in
                Image(bitmap: bitmap.asImageBitmap(), contentDescription: nil, contentScale: ContentScale.Crop,
                      modifier: context.modifier.size(size.dp).clip(CircleShape))
            }
        } else {
            initial
        }
        #elseif canImport(UIKit)
        if let photo, let image = UIImage(data: photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            initial
        }
        #else
        initial
        #endif
    }

    private var initial: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }
}
