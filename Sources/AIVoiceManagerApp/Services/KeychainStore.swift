import Foundation
import Security

// ponytail: thin SecItem wrapper, no protocol; tests don't touch the Keychain
/// The Gemini API key — one for every project, in the login Keychain (never UserDefaults, never a project file).
enum KeychainStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.aivoicemanager.gemini",
         kSecAttrAccount as String: "api-key"]
    }

    static func load() -> String? {
        var item: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Replaces any saved key. Returns false if the Keychain refused (locked, denied).
    @discardableResult
    static func save(_ key: String) -> Bool {
        remove()
        var add = query
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func remove() {
        SecItemDelete(query as CFDictionary)
    }
}
