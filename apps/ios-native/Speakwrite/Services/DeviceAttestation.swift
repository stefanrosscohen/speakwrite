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

    /// Single-flight guard: concurrent initialize() callers all await the same task,
    /// so key generation/attestation can't interleave across actor suspension points.
    private var initTask: Task<String, Error>?

    private static let keyIdKey = "speakwrite_attest_key_id"

    /// Legacy (pre-namespaced) Keychain key. The keyId lives in UserDefaults (wiped on
    /// uninstall) while the Keychain survives — so after a reinstall the old key's
    /// attestation blob could be paired with a freshly generated key, breaking
    /// verification forever. Blobs are now stored under a keyId-namespaced key.
    private static let legacyAttestDataKey = "speakwrite_attest_data"

    private static func attestDataKey(for keyId: String) -> String {
        "speakwrite_attest_data_\(keyId)"
    }

    var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    // MARK: - Public API

    func initialize() async throws -> String {
        // Fast path: already provisioned in memory.
        if let keyId, attestationData != nil { return keyId }

        // Single-flight: join an in-progress initialization if one exists.
        if let initTask { return try await initTask.value }

        let task = Task<String, Error> { try await performInitialize() }
        initTask = task
        defer { initTask = nil }
        return try await task.value
    }

    func generateAssertion(contentHash: Data) async throws -> Data {
        guard let currentKeyId = keyId else { throw AttestationError.keyGenerationFailed }
        do {
            return try await service.generateAssertion(currentKeyId, clientDataHash: contentHash)
        } catch let error as DCError where error.code == .invalidKey {
            // The Secure Enclave no longer has this key (device migration/restore).
            // Clear persisted state, provision a fresh key once, and retry.
            // If the retry fails too, the error propagates.
            clearPersistedState()
            let freshKeyId = try await initialize()
            return try await service.generateAssertion(freshKeyId, clientDataHash: contentHash)
        }
    }

    var attestationObjectBase64: String? {
        attestationData?.base64EncodedString()
    }

    // MARK: - Provisioning

    private func performInitialize() async throws -> String {
        migrateLegacyStorageIfNeeded()
        do {
            return try await provision()
        } catch let error as DCError where error.code == .invalidKey {
            // attestKey rejected the stored key — the Secure Enclave no longer has it
            // (device migration/restore). Re-provision a fresh key once; if that fails
            // too, propagate the error.
            clearPersistedState()
            return try await provision()
        }
    }

    private func provision() async throws -> String {
        // Generate or restore App Attest key
        let resolvedKeyId: String
        if let existing = keyId {
            resolvedKeyId = existing
        } else if let stored = UserDefaults.standard.string(forKey: Self.keyIdKey) {
            keyId = stored
            resolvedKeyId = stored
        } else {
            let newKeyId = try await service.generateKey()
            keyId = newKeyId
            UserDefaults.standard.set(newKeyId, forKey: Self.keyIdKey)
            // A fresh key invalidates any previously stored attestation blob.
            KeychainHelper.delete(key: Self.legacyAttestDataKey)
            resolvedKeyId = newKeyId
        }

        // Attest the key with Apple (once per key). The blob is stored under a key
        // namespaced by keyId so it can never be paired with a different key.
        if attestationData == nil {
            if let stored = KeychainHelper.loadData(key: Self.attestDataKey(for: resolvedKeyId)) {
                attestationData = stored
            } else {
                let challenge = Data(SHA256.hash(data: Data(resolvedKeyId.utf8)))
                let data = try await service.attestKey(resolvedKeyId, clientDataHash: challenge)
                attestationData = data
                KeychainHelper.saveData(key: Self.attestDataKey(for: resolvedKeyId), value: data)
            }
        }

        return resolvedKeyId
    }

    // MARK: - Storage maintenance

    /// One-time migration of the legacy (non-namespaced) attestation blob.
    /// - Normal upgrade (keyId still in UserDefaults): the blob belongs to that key —
    ///   move it to the namespaced entry.
    /// - Reinstall (keyId gone, UserDefaults wiped): the blob belongs to a lost key —
    ///   delete it so it can't be paired with a freshly generated key.
    private func migrateLegacyStorageIfNeeded() {
        guard let legacyBlob = KeychainHelper.loadData(key: Self.legacyAttestDataKey) else { return }
        if let storedKeyId = UserDefaults.standard.string(forKey: Self.keyIdKey) {
            if KeychainHelper.loadData(key: Self.attestDataKey(for: storedKeyId)) == nil {
                KeychainHelper.saveData(key: Self.attestDataKey(for: storedKeyId), value: legacyBlob)
            }
        }
        KeychainHelper.delete(key: Self.legacyAttestDataKey)
    }

    /// Remove all persisted attestation state (keyId + blobs) and reset memory,
    /// so the next initialize() provisions from scratch.
    private func clearPersistedState() {
        if let currentKeyId = keyId {
            KeychainHelper.delete(key: Self.attestDataKey(for: currentKeyId))
        }
        if let storedKeyId = UserDefaults.standard.string(forKey: Self.keyIdKey) {
            KeychainHelper.delete(key: Self.attestDataKey(for: storedKeyId))
        }
        KeychainHelper.delete(key: Self.legacyAttestDataKey)
        UserDefaults.standard.removeObject(forKey: Self.keyIdKey)
        keyId = nil
        attestationData = nil
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
