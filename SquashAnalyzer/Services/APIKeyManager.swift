import Foundation
import Security
import SquashAnalyzerCore

/// Manages secure storage of API keys using Keychain
final class APIKeyManager {
    static let shared = APIKeyManager()

    private let service = "com.squashanalyzer.apikeys"
    private let openAIKey = "openai_api_key"

    private init() {}

    /// The key as last read or written; the Keychain is only asked once
    private var cachedKey: String?? = nil

    // MARK: - OpenAI API Key

    var openAIAPIKey: String? {
        get {
            if let cachedKey { return cachedKey }
            let key = retrieve(key: openAIKey)
            cachedKey = .some(key)
            return key
        }
        set { _ = setOpenAIKey(newValue) }
    }

    /// Saves (or with nil/empty removes) the key; false when the Keychain
    /// refused, so the screen can say so instead of "Opgeslagen!"
    @discardableResult
    func setOpenAIKey(_ value: String?) -> Bool {
        cachedKey = nil
        if let value, !value.isEmpty {
            return save(key: openAIKey, value: value)
        }
        return delete(key: openAIKey)
    }

    // MARK: - Keychain Operations

    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Replace an existing item
        guard delete(key: key) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// True when the item is gone (also when there was none)
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

/// The shared AI Coach code reads the key through `APIKeyStore`
extension APIKeyManager: APIKeyStore {}
