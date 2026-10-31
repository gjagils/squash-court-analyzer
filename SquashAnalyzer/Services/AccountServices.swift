import Foundation
import Security
import AuthenticationServices
import CryptoKit
import SquashAnalyzerCore
import SquashAnalyzerUI

// 4.0, the player account (Core's `PlayerAccount`), behind
// Features.shared.playerAccount: what only the iPhone does. The refresh token
// and the device key go in the Keychain; Sign in with Apple is native
// (AuthenticationServices) and its token goes to Firebase through Core.

/// The account's secrets in the Keychain, the counterpart of Android's `KeystoreAccountSecrets`
final class KeychainAccountSecrets: AccountSecretStore {
    private let service = "com.squashanalyzer.account"
    private let account = "account_secrets"

    var accountSecrets: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let identity: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            guard let newValue, let data = newValue.data(using: .utf8) else {
                SecItemDelete(identity as CFDictionary)
                return
            }
            // Replace in place, as APIKeyManager does: a failed add never loses the old value first
            let updated = SecItemUpdate(identity as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updated == errSecItemNotFound {
                var query = identity
                query[kSecValueData as String] = data
                // Only on this iPhone, and only once it was unlocked after a restart
                query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                SecItemAdd(query as CFDictionary, nil)
            }
        }
    }
}

/// Sign in with Apple for Mijn account. Needs the "Sign in with Apple"
/// capability on the App ID and in the entitlements (not set yet: Gerd-Jan's
/// list in docs/wijzigingen-builds.md), so the button only shows with
/// SQUASH_APPLE_SIGN_IN=YES.
@MainActor
enum AppleAccountSignIn {
    /// Only once the capability is there: SQUASH_APPLE_SIGN_IN=YES (Info.plist SquashAppleSignIn)
    static var isAvailable: Bool {
        Features.isOn(Bundle.main.infoDictionary?["SquashAppleSignIn"] as? String)
    }

    static var providers: [AccountProviderSignIn] {
        guard isAvailable else { return [] }
        return [AccountProviderSignIn(title: appText("INLOGGEN MET APPLE")) { done in AppleAuthorization.shared.start(done) }]
    }

    /// Before deleting an Apple account: a fresh sign-in, for the code to revoke
    static var reauthorize: AccountProviderSignIn? {
        guard isAvailable else { return nil }
        return AccountProviderSignIn(title: appText("INLOGGEN MET APPLE")) { done in AppleAuthorization.shared.start(done) }
    }
}

@MainActor
final class AppleAuthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleAuthorization()

    private var nonce = ""
    private var done: ((AccountProviderToken?) -> Void)?
    private var controller: ASAuthorizationController?

    func start(_ done: @escaping (AccountProviderToken?) -> Void) {
        self.done = done
        // Firebase checks that the token carries the SHA-256 of this nonce
        nonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        controller.performRequests()
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let idToken = credential?.identityToken.flatMap { data in String(data: data, encoding: .utf8) }
        let code = credential?.authorizationCode.flatMap { data in String(data: data, encoding: .utf8) }
        Task { @MainActor in
            guard let idToken else {
                self.finish(nil)
                return
            }
            self.finish(AccountProviderToken(providerId: "apple.com", idToken: idToken, nonce: self.nonce, authorizationCode: code))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { scene in scene as? UIWindowScene }
            return scenes.flatMap { scene in scene.windows }.first { window in window.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    private func finish(_ token: AccountProviderToken?) {
        let callback = done
        done = nil
        controller = nil
        callback?(token)
    }

    private static func randomNonce() -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz")
        var generator = SystemRandomNumberGenerator()
        return String((0..<32).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] })
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { byte in String(format: "%02x", byte) }.joined()
    }
}
