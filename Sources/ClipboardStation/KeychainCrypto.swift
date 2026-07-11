import CryptoKit
import Foundation
import Security

enum CryptoStoreError: Error {
    case keyCreationFailed(OSStatus)
    case keyReadFailed(OSStatus)
    case invalidKeyData
}

final class KeychainCrypto {
    private let service = "com.local.clipboard-station"
    private let account = "snippet-storage-key"

    func encrypt(_ data: Data) throws -> Data {
        let key = try symmetricKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw CryptoStoreError.invalidKeyData
        }
        return combined
    }

    func decrypt(_ data: Data) throws -> Data {
        let key = try symmetricKey()
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    private func symmetricKey() throws -> SymmetricKey {
        if let stored = try readKeyData() {
            guard stored.count == 32 else {
                throw CryptoStoreError.invalidKeyData
            }
            return SymmetricKey(data: stored)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw CryptoStoreError.keyCreationFailed(status)
        }

        let keyData = Data(bytes)
        try saveKeyData(keyData)
        return SymmetricKey(data: keyData)
    }

    private func readKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CryptoStoreError.keyReadFailed(status)
        }
        return item as? Data
    }

    private func saveKeyData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            return
        }
        guard status == errSecSuccess else {
            throw CryptoStoreError.keyCreationFailed(status)
        }
    }
}
