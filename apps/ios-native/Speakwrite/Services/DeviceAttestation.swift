import CryptoKit
import DeviceCheck
import Foundation

// MARK: - Types

struct AttestationRecord: Codable {
    let keyId: String
    let attestationObject: String  // Base64 — Apple's cert chain proving key is on genuine device
    let assertion: String          // Base64 — App Attest assertion over content hash
    let contentHash: String
    let appId: String
    let mediaHashes: [String]?     // SHA-256 hex of each attached media blob (optional for backward compat)
}

// MARK: - Service

actor DeviceAttestationService {
    private let service = DCAppAttestService.shared

    private var keyId: String?
    private var attestationData: Data?

    private static let keyIdKey = "speakwrite_attest_key_id"
    private static let attestDataKey = "speakwrite_attest_data"

    var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    // MARK: - Public API

    func initialize() async throws -> String {
        // Restore the App Attest key ID. It must live in the Keychain next to
        // the attestation blob — storing it in UserDefaults (cleared on app
        // deletion, while the Keychain survives) meant a reinstall paired a
        // fresh key with the old key's attestation, breaking every proof.
        if let stored = KeychainHelper.load(key: Self.keyIdKey), !stored.isEmpty {
            keyId = stored
        } else if let legacy = UserDefaults.standard.string(forKey: Self.keyIdKey) {
            // One-time migration from the old UserDefaults location
            keyId = legacy
            KeychainHelper.save(key: Self.keyIdKey, value: legacy)
            UserDefaults.standard.removeObject(forKey: Self.keyIdKey)
        } else {
            // No key ID — any attestation blob in the Keychain belongs to a
            // key we no longer know; discard it so key and blob stay paired.
            KeychainHelper.delete(key: Self.attestDataKey)
            let newKeyId = try await service.generateKey()
            keyId = newKeyId
            KeychainHelper.save(key: Self.keyIdKey, value: newKeyId)
        }

        guard let keyId else { throw AttestationError.keyGenerationFailed }

        // Attest the key with Apple (once per key)
        if let stored = KeychainHelper.loadData(key: Self.attestDataKey) {
            attestationData = stored
        } else {
            let challenge = Data(SHA256.hash(data: Data(keyId.utf8)))
            let data = try await service.attestKey(keyId, clientDataHash: challenge)
            attestationData = data
            KeychainHelper.saveData(key: Self.attestDataKey, value: data)
        }

        return keyId
    }

    func generateAssertion(contentHash: Data) async throws -> Data {
        guard let keyId else { throw AttestationError.keyGenerationFailed }
        return try await service.generateAssertion(keyId, clientDataHash: contentHash)
    }

    var attestationObjectBase64: String? {
        attestationData?.base64EncodedString()
    }
}

// MARK: - Errors

enum AttestationError: Error, LocalizedError {
    case keyGenerationFailed
    case notAttested

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate attestation key"
        case .notAttested: return "Device not attested"
        }
    }
}
