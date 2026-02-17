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
        // Generate or restore App Attest key
        if let stored = UserDefaults.standard.string(forKey: Self.keyIdKey) {
            keyId = stored
        } else {
            let newKeyId = try await service.generateKey()
            keyId = newKeyId
            UserDefaults.standard.set(newKeyId, forKey: Self.keyIdKey)
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
