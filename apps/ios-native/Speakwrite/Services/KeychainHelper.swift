import Foundation
import Security
import os

/// Simple Keychain wrapper for storing auth tokens securely.
enum KeychainHelper {
    private static let logger = Logger(subsystem: "io.speakwrite.app", category: "KeychainHelper")

    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Keychain save failed for key \(key, privacy: .public): value is not valid UTF-8")
            return false
        }
        return saveData(key: key, value: data)
    }

    static func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveData(key: String, value: Data) -> Bool {
        // kSecAttrAccessible cannot be changed on an existing item in place —
        // delete first, then re-add. This also migrates items previously stored
        // with kSecAttrAccessibleWhenUnlockedThisDeviceOnly on their next save.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "io.speakwrite.app",
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.error("SecItemDelete failed for key \(key, privacy: .public): OSStatus \(deleteStatus)")
        }

        // Add new item.
        // AfterFirstUnlock (not WhenUnlocked) so tokens remain readable while the
        // app runs in the background with the device locked.
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "io.speakwrite.app",
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("SecItemAdd failed for key \(key, privacy: .public): OSStatus \(addStatus)")
            return false
        }
        return true
    }

    static func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "io.speakwrite.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecSuccess && status != errSecItemNotFound {
                logger.error("SecItemCopyMatching failed for key \(key, privacy: .public): OSStatus \(status)")
            }
            return nil
        }
        return data
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "io.speakwrite.app",
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("SecItemDelete failed for key \(key, privacy: .public): OSStatus \(status)")
            return false
        }
        return true
    }
}
