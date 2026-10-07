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
        // Android decodes each photo once (PhotoBitmapCache), not on every recompose
        #if SKIP
        if let photo, let bitmap = PhotoBitmapCache.shared.bitmap(for: photo) {
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

#if SKIP
/// Decoded player photos, so a recompose does not decode the JPEG again.
/// Keyed by content, because Skip's `Data` hashes by array identity; Compose's
/// `remember` is not an option here (it broke the Skip build, see
/// docs/skip-valkuilen.md). Only touched from the UI thread.
final class PhotoBitmapCache {
    static let shared = PhotoBitmapCache()
    private let limit = 64
    private var entries: [Int: PhotoBitmapEntry] = [:]
    private var order: [Int] = []

    func bitmap(for photo: Data) -> android.graphics.Bitmap? {
        let key = photo.platformValue.contentHashCode()
        if let entry = entries[key], entry.photo == photo { return entry.bitmap }
        guard let bitmap = BitmapFactory.decodeByteArray(photo.platformValue, 0, photo.count) else { return nil }
        if entries[key] == nil { order.append(key) }
        entries[key] = PhotoBitmapEntry(photo: photo, bitmap: bitmap)
        if order.count > limit {
            let oldest = order.removeFirst()
            entries[oldest] = nil
        }
        return bitmap
    }
}

struct PhotoBitmapEntry {
    let photo: Data
    let bitmap: android.graphics.Bitmap
}
#endif
