import PhotosUI
import SquashAnalyzerCore
import UIKit

/// The avatar of the player account (4.0): the system photo picker over the
/// app, the picked photo made a 512 px square JPEG like a player photo
@MainActor
final class IOSAvatarSource: NSObject, AccountAvatarSource, PHPickerViewControllerDelegate {
    private var pending: CheckedContinuation<Data?, Never>?

    func pickAvatar() async throws -> Data? {
        guard pending == nil, let top = Self.topController() else { return nil }
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        return await withCheckedContinuation { continuation in
            pending = continuation
            top.present(picker, animated: true)
        }
    }

    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let provider = results.first?.itemProvider
        Task { @MainActor in
            picker.dismiss(animated: true)
            guard let provider, provider.canLoadObject(ofClass: UIImage.self) else {
                self.finish(nil)
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                let normalized = data.flatMap { PlayerPhoto.normalized($0) }
                Task { @MainActor in self.finish(normalized) }
            }
        }
    }

    private func finish(_ data: Data?) {
        pending?.resume(returning: data)
        pending = nil
    }

    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
