import Foundation
import CryptoKit
import LocalAuthentication
import UIKit

@MainActor
class SecureVaultService: ObservableObject {
    static let shared = SecureVaultService()

    @Published var secrets: [String] = [] // Just the names, not values

    private let keychainPrefix = "voiceday_vault_"

    init() {
        loadSecretNames()
    }

    // MARK: - Store Secret

    func storeSecret(name: String, value: String) throws {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Encrypt the value
        let encryptedData = try encrypt(value)

        // Store in Keychain
        let key = keychainPrefix + normalizedName
        KeychainService.save(key: key, value: encryptedData.base64EncodedString())

        // Update names list
        if !secrets.contains(normalizedName) {
            secrets.append(normalizedName)
            saveSecretNames()
        }

        print("🔐 Stored secret: \(normalizedName)")
    }

    // MARK: - Retrieve Secret

    func retrieveSecret(name: String) throws -> String {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keychainPrefix + normalizedName

        guard let base64String = KeychainService.load(key: key),
              let encryptedData = Data(base64Encoded: base64String) else {
            throw VaultError.secretNotFound(name: normalizedName)
        }

        let decryptedValue = try decrypt(encryptedData)
        print("🔓 Retrieved secret: \(normalizedName)")
        return decryptedValue
    }

    // MARK: - Delete Secret

    func deleteSecret(name: String) {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keychainPrefix + normalizedName

        KeychainService.delete(key: key)
        secrets.removeAll { $0 == normalizedName }
        saveSecretNames()

        print("🗑️ Deleted secret: \(normalizedName)")
    }

    // MARK: - List Secrets

    func listSecrets() -> [String] {
        return secrets
    }

    // MARK: - Encryption

    private func encrypt(_ plaintext: String) throws -> Data {
        guard let data = plaintext.data(using: .utf8) else {
            throw VaultError.encryptionFailed
        }

        // Use device-specific key derived from a fixed salt + device ID
        let key = getEncryptionKey()

        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw VaultError.encryptionFailed
        }

        return combined
    }

    private func decrypt(_ ciphertext: Data) throws -> String {
        let key = getEncryptionKey()

        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw VaultError.decryptionFailed
        }

        return plaintext
    }

    private func getEncryptionKey() -> SymmetricKey {
        // Create a device-specific encryption key
        // This uses a combination of a fixed salt and the device's unique identifier
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "default-device-id"
        let salt = "Gadfly-Vault-2024"
        let keyMaterial = salt + deviceId

        let keyData = Data(keyMaterial.utf8)
        let hash = SHA256.hash(data: keyData)
        return SymmetricKey(data: hash)
    }

    // MARK: - Persistence of Secret Names

    private func loadSecretNames() {
        if let names = UserDefaults.standard.array(forKey: "vault_secret_names") as? [String] {
            secrets = names
        }
    }

    private func saveSecretNames() {
        UserDefaults.standard.set(secrets, forKey: "vault_secret_names")
    }
}

// MARK: - Errors

enum VaultError: LocalizedError {
    case secretNotFound(name: String)
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .secretNotFound(let name):
            return "No secret found with the name '\(name)'"
        case .encryptionFailed:
            return "Failed to encrypt the secret"
        case .decryptionFailed:
            return "Failed to decrypt the secret"
        }
    }
}
