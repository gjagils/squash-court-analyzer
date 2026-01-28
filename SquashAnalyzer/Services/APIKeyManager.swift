import Foundation
import Security

/// Manages secure storage of API keys using Keychain
final class APIKeyManager {
    static let shared = APIKeyManager()

    private let service = "com.squashanalyzer.apikeys"
    private let openAIKey = "openai_api_key"

    private init() {}

    // MARK: - OpenAI API Key

    var openAIAPIKey: String? {
        get { retrieve(key: openAIKey) }
        set {
            if let value = newValue {
                save(key: openAIKey, value: value)
            } else {
                delete(key: openAIKey)
            }
        }
    }

    var hasOpenAIKey: Bool {
        openAIAPIKey != nil && !openAIAPIKey!.isEmpty
    }

    // MARK: - Keychain Operations

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
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

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
