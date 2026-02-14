import Foundation
import Capacitor
import DeviceCheck
import CryptoKit
import LocalAuthentication

/// Capacitor plugin providing App Attest + Secure Enclave attestation for Speakwrite.
///
/// Flow:
///   1. `initialize()` — Generate SE key, attest with Apple (one-time)
///   2. `startSession()` — Require biometric, return session signature
///   3. `signCheckpoint(data)` — Sign a commitment checkpoint hash
///   4. `signFinal(data)` — Sign the final content binding
///   5. `getAttestationEnvelope()` — Return full attestation data for proof bundle
@objc(DeviceAttestationPlugin)
public class DeviceAttestationPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "DeviceAttestationPlugin"
    public let jsName = "DeviceAttestation"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initialize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signCheckpoint", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signFinal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAttestationEnvelope", returnType: CAPPluginReturnPromise),
    ]

    private let service = DCAppAttestService.shared
    private var keyId: String?
    private var attestationData: Data?
    private var sessionId: String?
    private var sessionSignature: Data?
    private var checkpointSignatures: [[String: Any]] = []

    // Secure Enclave key for session signing (biometric-gated)
    private var signingKey: SecureEnclave.P256.Signing.PrivateKey?

    // MARK: - Plugin Methods

    /// Check if device attestation is available on this device.
    @objc func isSupported(_ call: CAPPluginCall) {
        call.resolve([
            "appAttest": service.isSupported,
            "secureEnclave": SecureEnclave.isAvailable,
            "platform": "apple",
        ])
    }

    /// One-time initialization: generate App Attest key and Secure Enclave signing key.
    @objc func initialize(_ call: CAPPluginCall) {
        guard service.isSupported else {
            call.reject("App Attest is not supported on this device")
            return
        }

        guard SecureEnclave.isAvailable else {
            call.reject("Secure Enclave is not available on this device")
            return
        }

        Task {
            do {
                // 1. Generate App Attest key
                let keyId = try await service.generateKey()
                self.keyId = keyId

                // Persist key ID
                UserDefaults.standard.set(keyId, forKey: "speakwrite_attest_key_id")

                // 2. Attest the key with Apple
                //    In production, the challenge should come from your server.
                //    For now, we use a self-generated challenge and store the attestation locally.
                let challenge = Data(SHA256.hash(data: Data(keyId.utf8)))
                let attestation = try await service.attestKey(keyId, clientDataHash: challenge)
                self.attestationData = attestation

                // 3. Generate Secure Enclave signing key with biometric access control
                let accessControl = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    [.privateKeyUsage, .biometryCurrentSet],
                    nil
                )!

                let key = try SecureEnclave.P256.Signing.PrivateKey(
                    accessControl: accessControl
                )
                self.signingKey = key

                // Store key data for persistence
                let keyData = key.dataRepresentation
                KeychainHelper.save(key: "speakwrite_se_key", data: keyData)

                let publicKey = key.publicKey.rawRepresentation

                call.resolve([
                    "keyId": keyId,
                    "publicKey": publicKey.base64EncodedString(),
                    "attestationPresent": true,
                ])
            } catch {
                call.reject("Initialization failed: \(error.localizedDescription)")
            }
        }
    }

    /// Start a new attested session. Requires biometric authentication.
    @objc func startSession(_ call: CAPPluginCall) {
        guard let key = signingKey else {
            // Try to restore from keychain
            if let keyData = KeychainHelper.load(key: "speakwrite_se_key") {
                do {
                    signingKey = try SecureEnclave.P256.Signing.PrivateKey(
                        dataRepresentation: keyData
                    )
                } catch {
                    call.reject("Failed to restore signing key: \(error.localizedDescription)")
                    return
                }
            } else {
                call.reject("Not initialized. Call initialize() first.")
                return
            }
        }

        // Restore App Attest key ID if needed
        if keyId == nil {
            keyId = UserDefaults.standard.string(forKey: "speakwrite_attest_key_id")
        }

        let sid = UUID().uuidString
        self.sessionId = sid
        self.checkpointSignatures = []

        // Sign session start (this will trigger Face ID / Touch ID)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let payload = "\(sid)|\(timestamp)".data(using: .utf8)!

        do {
            let signature = try (signingKey ?? key).signature(for: payload)
            self.sessionSignature = signature.rawRepresentation

            call.resolve([
                "sessionId": sid,
                "timestamp": timestamp,
                "signature": signature.rawRepresentation.base64EncodedString(),
                "biometricGate": true,
            ])
        } catch {
            call.reject("Biometric authentication failed: \(error.localizedDescription)")
        }
    }

    /// Sign a commitment checkpoint with the Secure Enclave key.
    @objc func signCheckpoint(_ call: CAPPluginCall) {
        guard let key = signingKey else {
            call.reject("No active session. Call startSession() first.")
            return
        }

        guard let commitmentHash = call.getString("commitmentHash"),
              let sequenceNum = call.getInt("sequenceNum") else {
            call.reject("Missing required parameters: commitmentHash, sequenceNum")
            return
        }

        let payload = "\(sequenceNum)|\(commitmentHash)".data(using: .utf8)!

        do {
            let signature = try key.signature(for: payload)

            let checkpoint: [String: Any] = [
                "sequenceNum": sequenceNum,
                "commitmentHash": commitmentHash,
                "signature": signature.rawRepresentation.base64EncodedString(),
            ]

            checkpointSignatures.append(checkpoint)

            call.resolve(checkpoint)
        } catch {
            call.reject("Signing failed: \(error.localizedDescription)")
        }
    }

    /// Sign the final content binding with the Secure Enclave key.
    @objc func signFinal(_ call: CAPPluginCall) {
        guard let key = signingKey else {
            call.reject("No active session. Call startSession() first.")
            return
        }

        guard let contentHash = call.getString("contentHash"),
              let bindingHash = call.getString("bindingHash") else {
            call.reject("Missing required parameters: contentHash, bindingHash")
            return
        }

        let payload = "\(contentHash)|\(bindingHash)".data(using: .utf8)!

        do {
            let signature = try key.signature(for: payload)

            call.resolve([
                "contentHash": contentHash,
                "bindingHash": bindingHash,
                "signature": signature.rawRepresentation.base64EncodedString(),
            ])
        } catch {
            call.reject("Final signing failed: \(error.localizedDescription)")
        }
    }

    /// Get the full attestation envelope for inclusion in the proof bundle.
    @objc func getAttestationEnvelope(_ call: CAPPluginCall) {
        guard let key = signingKey else {
            call.reject("Not initialized")
            return
        }

        var envelope: [String: Any] = [
            "platform": "apple",
            "attestationType": keyId != nil ? "app_attest" : "secure_enclave_only",
            "attestationLevel": keyId != nil ? "platform_attested" : "hardware_unverified",
            "devicePublicKey": key.publicKey.rawRepresentation.base64EncodedString(),
            "appId": Bundle.main.bundleIdentifier ?? "io.speakwrite.app",
        ]

        if let attestation = attestationData {
            envelope["attestationCertificate"] = attestation.base64EncodedString()
        }

        if let sid = sessionId {
            var sessionBinding: [String: Any] = [
                "sessionId": sid,
                "biometricGate": true,
            ]
            if let sig = sessionSignature {
                sessionBinding["sessionStartSignature"] = sig.base64EncodedString()
            }
            envelope["sessionBinding"] = sessionBinding
        }

        envelope["checkpointSignatures"] = checkpointSignatures

        call.resolve(envelope)
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        SecItemDelete(query as CFDictionary) // Remove old if exists
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
}
