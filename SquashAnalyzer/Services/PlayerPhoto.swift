import Foundation
import UIKit

/// Normalises player photos to a small square JPEG so the database and backups stay compact.
enum PlayerPhoto {
    static let maxDimension: CGFloat = 512

    /// Center-crops to a square and scales down to at most 512px; nil when the data is not an image.
    static func normalized(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        let target = min(side, maxDimension)
        let scale = target / side
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (target - drawSize.width) / 2, y: (target - drawSize.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let square = renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return square.jpegData(compressionQuality: 0.82)
    }
}
