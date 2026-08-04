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
        // The key ID and the attestation object must live and die together.
        // Both are stored in the Keychain: the key ID previously lived in
        // UserDefaults, which is wiped on reinstall while the Keychain
        // persists — leaving a stale attestation object paired with a fresh
        // key, so every subsequent post failed signature verification.
        if keyId == nil {
            if let stored = KeychainHelper.load(key: Self.keyIdKey), !stored.isEmpty {
                keyId = stored
            } else if let legacy = UserDefaults.standard.string(forKey: Self.keyIdKey) {
                // Migrate pre-existing installs (key ID was in UserDefaults)
                keyId = legacy
                KeychainHelper.save(key: Self.keyIdKey, value: legacy)
                UserDefaults.standard.removeObject(forKey: Self.keyIdKey)
            }
        }

        if keyId == nil {
            // Fresh key — any attestation object left over in the Keychain
            // belongs to a previous install's key and must not be reused.
            KeychainHelper.delete(key: Self.attestDataKey)
            attestationData = nil
            let newKeyId = try await service.generateKey()
            keyId = newKeyId
            KeychainHelper.save(key: Self.keyIdKey, value: newKeyId)
        }

        guard let currentKeyId = keyId else { throw AttestationError.keyGenerationFailed }

        // Attest the key with Apple (once per key)
        if attestationData == nil {
            if let stored = KeychainHelper.loadData(key: Self.attestDataKey) {
                attestationData = stored
            } else {
                do {
                    let challenge = Data(SHA256.hash(data: Data(currentKeyId.utf8)))
                    let data = try await service.attestKey(currentKeyId, clientDataHash: challenge)
                    attestationData = data
                    KeychainHelper.saveData(key: Self.attestDataKey, value: data)
                } catch {
                    // The stored key may have been invalidated (e.g. Keychain
                    // restored onto a different device). Mint a fresh key and
                    // retry once before giving up.
                    let newKeyId = try await service.generateKey()
                    keyId = newKeyId
                    KeychainHelper.save(key: Self.keyIdKey, value: newKeyId)
                    let challenge = Data(SHA256.hash(data: Data(newKeyId.utf8)))
                    let data = try await service.attestKey(newKeyId, clientDataHash: challenge)
                    attestationData = data
                    KeychainHelper.saveData(key: Self.attestDataKey, value: data)
                    return newKeyId
                }
            }
        }

        return currentKeyId
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
