import Foundation
import SquashAnalyzerCore
#if SKIP
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
#elseif canImport(UIKit)
import UIKit
#endif

/// A player's photo as the small JPEG the live page shows (Core's
/// `LivePhotos`): a square crop of at most `side` pixels, compressed until it
/// fits the server's limit. Nil when there is no photo or it cannot be read.
public enum LivePhotoThumbnail {
    public static let side = 160

    public static func jpeg(from data: Data?) -> Data? {
        guard let data else { return nil }
        for quality in [70, 55, 40] {
            if let jpeg = render(data, quality: quality), jpeg.count <= LivePhotos.maxBytes {
                return jpeg
            }
        }
        return nil
    }

    /// Both players' thumbnails, as `LiveShare.start` takes them
    public static func photos(player1: Data?, player2: Data?) -> LivePhotos {
        LivePhotos(player1: jpeg(from: player1), player2: jpeg(from: player2))
    }

    private static func render(_ data: Data, quality: Int) -> Data? {
        #if SKIP
        let bytes = data.platformValue
        guard let full = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) else { return nil }
        let crop = min(full.getWidth(), full.getHeight())
        let square = Bitmap.createBitmap(full, (full.getWidth() - crop) / 2, (full.getHeight() - crop) / 2, crop, crop)
        let size = min(side, crop)
        let small = Bitmap.createScaledBitmap(square, size, size, true)
        let output = ByteArrayOutputStream()
        small.compress(Bitmap.CompressFormat.JPEG, quality, output)
        return Data(platformValue: output.toByteArray())
        #elseif canImport(UIKit)
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let crop = min(image.size.width, image.size.height)
        let size = min(CGFloat(side), crop)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let square = renderer.image { _ in
            // Centred square crop, scaled to `size`
            let scale = size / crop
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(in: CGRect(x: (size - width) / 2, y: (size - height) / 2, width: width, height: height))
        }
        return square.jpegData(compressionQuality: CGFloat(quality) / 100.0)
        #else
        return nil
        #endif
    }
}
