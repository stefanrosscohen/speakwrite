import CryptoKit
import DeviceCheck
import Foundation
import LocalAuthentication

// MARK: - Types

struct AttestationSupport {
    let appAttest: Bool
    let secureEnclave: Bool
    let platform = "apple"
}

struct SessionStart {
    let sessionId: String
    let timestamp: String
    let signature: String // base64
    let biometricGate = true
}

struct CheckpointSignature {
    let sequenceNum: Int
    let commitmentHash: String
    let signature: String // base64
}

struct FinalSignature {
    let contentHash: String
    let bindingHash: String
    let signature: String // base64
}

struct AttestationEnvelope: Codable {
    let platform: String
    let attestationType: String
    let attestationLevel: String
    let devicePublicKey: String
    let appId: String
    let attestationCertificate: String?
    let sessionBinding: SessionBinding?
    let checkpointSignatures: [CheckpointSignatureRecord]
    let finalSignature: String?

    struct SessionBinding: Codable {
        let sessionId: String
        let biometricGate: Bool
        let sessionStartSignature: String?
        let sessionStartTimestamp: String?
    }

    struct CheckpointSignatureRecord: Codable {
        let sequenceNum: Int
        let commitmentHash: String
        let signature: String
    }
}

// MARK: - Service

/// Standalone device attestation service.
/// Refactored from DeviceAttestationPlugin.swift (Capacitor plugin).
/// Uses App Attest + Secure Enclave + biometric gating.
actor DeviceAttestationService {
    private let service = DCAppAttestService.shared

    private var keyId: String?
    private var attestationData: Data?
    private var sessionId: String?
    private var sessionTimestamp: String?
    private var sessionSignature: Data?
    private var checkpointSignatures: [AttestationEnvelope.CheckpointSignatureRecord] = []
    private var finalSignatureData: Data?
    private var signingKey: SecureEnclave.P256.Signing.PrivateKey?

    private static let keyIdKey = "speakwrite_attest_key_id"
    private static let seKeyTag = "speakwrite_se_key"

    // MARK: - Public API

    nonisolated func isSupported() -> AttestationSupport {
        AttestationSupport(
            appAttest: DCAppAttestService.shared.isSupported,
            secureEnclave: SecureEnclave.isAvailable
        )
    }

    func initialize() async throws -> (keyId: String, publicKey: String) {
        // Generate or restore App Attest key
        if let stored = UserDefaults.standard.string(forKey: Self.keyIdKey) {
            keyId = stored
        } else {
            let newKeyId = try await service.generateKey()
            keyId = newKeyId
            UserDefaults.standard.set(newKeyId, forKey: Self.keyIdKey)
        }

        guard let keyId else { throw AttestationError.keyGenerationFailed }

        // Attest the key with Apple
        let challenge = Data(SHA256.hash(data: Data(keyId.utf8)))
        do {
            attestationData = try await service.attestKey(keyId, clientDataHash: challenge)
        } catch {
            // App Attest may fail on simulator or certain devices
            attestationData = nil
        }

        // Generate or restore Secure Enclave signing key
        if let existingKey = try? loadSEKey() {
            signingKey = existingKey
        } else {
            let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .biometryCurrentSet],
                nil
            )!
            let newKey = try SecureEnclave.P256.Signing.PrivateKey(
                accessControl: accessControl
            )
            try saveSEKey(newKey)
            signingKey = newKey
        }

        guard let key = signingKey else { throw AttestationError.keyGenerationFailed }
        let pubKeyBase64 = key.publicKey.rawRepresentation.base64EncodedString()

        return (keyId: keyId, publicKey: pubKeyBase64)
    }

    func startSession() async throws -> SessionStart {
        // Restore SE key if needed
        if signingKey == nil {
            signingKey = try loadSEKey()
        }
        guard let key = signingKey else { throw AttestationError.noSigningKey }

        let sid = UUID().uuidString
        let timestamp = ISO8601DateFormatter().string(from: Date())

        sessionId = sid
        sessionTimestamp = timestamp
        checkpointSignatures = []
        finalSignatureData = nil

        // Sign session start (triggers biometric prompt)
        let payload = Data("\(sid)|\(timestamp)".utf8)
        let signature = try key.signature(for: payload)
        sessionSignature = signature.rawRepresentation

        return SessionStart(
            sessionId: sid,
            timestamp: timestamp,
            signature: signature.rawRepresentation.base64EncodedString()
        )
    }

    func signCheckpoint(commitmentHash: String, sequenceNum: Int) throws -> CheckpointSignature {
        guard sessionId != nil else { throw AttestationError.noActiveSession }
        guard let key = signingKey else { throw AttestationError.noSigningKey }

        let payload = Data("\(sequenceNum)|\(commitmentHash)".utf8)
        let signature = try key.signature(for: payload)
        let sigBase64 = signature.rawRepresentation.base64EncodedString()

        let record = AttestationEnvelope.CheckpointSignatureRecord(
            sequenceNum: sequenceNum,
            commitmentHash: commitmentHash,
            signature: sigBase64
        )
        checkpointSignatures.append(record)

        return CheckpointSignature(
            sequenceNum: sequenceNum,
            commitmentHash: commitmentHash,
            signature: sigBase64
        )
    }

    func signFinal(contentHash: String, bindingHash: String) throws -> FinalSignature {
        guard sessionId != nil else { throw AttestationError.noActiveSession }
        guard let key = signingKey else { throw AttestationError.noSigningKey }

        let payload = Data("\(contentHash)|\(bindingHash)".utf8)
        let signature = try key.signature(for: payload)
        finalSignatureData = signature.rawRepresentation

        return FinalSignature(
            contentHash: contentHash,
            bindingHash: bindingHash,
            signature: signature.rawRepresentation.base64EncodedString()
        )
    }

    func getAttestationEnvelope() -> AttestationEnvelope? {
        guard let key = signingKey else { return nil }

        let pubKeyBase64 = key.publicKey.rawRepresentation.base64EncodedString()
        let bundleId = Bundle.main.bundleIdentifier ?? "io.speakwrite.app"

        var sessionBinding: AttestationEnvelope.SessionBinding?
        if let sid = sessionId {
            sessionBinding = AttestationEnvelope.SessionBinding(
                sessionId: sid,
                biometricGate: true,
                sessionStartSignature: sessionSignature?.base64EncodedString(),
                sessionStartTimestamp: sessionTimestamp
            )
        }

        return AttestationEnvelope(
            platform: "apple",
            attestationType: keyId != nil ? "app_attest" : "secure_enclave_only",
            attestationLevel: keyId != nil ? "platform_attested" : "hardware_unverified",
            devicePublicKey: pubKeyBase64,
            appId: bundleId,
            attestationCertificate: attestationData?.base64EncodedString(),
            sessionBinding: sessionBinding,
            checkpointSignatures: checkpointSignatures,
            finalSignature: finalSignatureData?.base64EncodedString()
        )
    }

    // MARK: - Keychain Helpers

    private func saveSEKey(_ key: SecureEnclave.P256.Signing.PrivateKey) throws {
        let data = key.dataRepresentation
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.seKeyTag,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AttestationError.keychainError(status)
        }
    }

    private func loadSEKey() throws -> SecureEnclave.P256.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.seKeyTag,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
    }
}

// MARK: - Errors

enum AttestationError: Error, LocalizedError {
    case keyGenerationFailed
    case noSigningKey
    case noActiveSession
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate attestation key"
        case .noSigningKey: return "No signing key available"
        case .noActiveSession: return "No active session"
        case .keychainError(let status): return "Keychain error: \(status)"
        }
    }
}
