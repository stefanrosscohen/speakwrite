import Foundation

// MARK: - Proof Bundle types (JSON-serializable, matches TypeScript format)

struct ProofBundle: Codable {
    let version: String
    let documentId: String
    let contentHash: String
    let bindingHash: String
    let totalKeystrokeCount: Int
    let createdAt: String
    let commitments: [ProofCommitment]
    let deviceAttestation: DeviceAttestationData?

    enum CodingKeys: String, CodingKey {
        case version
        case documentId = "document_id"
        case contentHash = "content_hash"
        case bindingHash = "binding_hash"
        case totalKeystrokeCount = "total_keystroke_count"
        case createdAt = "created_at"
        case commitments
        case deviceAttestation = "device_attestation"
    }
}

struct ProofCommitment: Codable {
    let sequenceNum: Int
    let commitmentHash: String
    let previousHash: String?
    let nonce: String
    let timestampMs: Double
    let commitmentType: String
    let contentHash: String?
    // v2 fields — openable commitments + incremental content hashing
    let featuresJson: String?
    let documentHash: String?
    let documentLength: Int?
    let keystrokeCount: Int?

    enum CodingKeys: String, CodingKey {
        case sequenceNum = "sequence_num"
        case commitmentHash = "commitment_hash"
        case previousHash = "previous_hash"
        case nonce
        case timestampMs = "timestamp_ms"
        case commitmentType = "commitment_type"
        case contentHash = "content_hash"
        case featuresJson = "features_json"
        case documentHash = "document_hash"
        case documentLength = "document_length"
        case keystrokeCount = "keystroke_count"
    }
}

struct DeviceAttestationData: Codable {
    let platform: String
    let attestationType: String
    let attestationLevel: String
    let devicePublicKey: String
    let appId: String
    let attestationCertificate: String?
    let sessionBinding: SessionBindingData?
    let checkpointSignatures: [CheckpointSignatureData]
    let finalSignature: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case attestationType = "attestation_type"
        case attestationLevel = "attestation_level"
        case devicePublicKey = "device_public_key"
        case appId = "app_id"
        case attestationCertificate = "attestation_certificate"
        case sessionBinding = "session_binding"
        case checkpointSignatures = "checkpoint_signatures"
        case finalSignature = "final_signature"
    }
}

struct SessionBindingData: Codable {
    let sessionId: String
    let biometricGate: Bool
    let sessionStartSignature: String?
    let sessionStartTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case biometricGate = "biometric_gate"
        case sessionStartSignature = "session_start_signature"
        case sessionStartTimestamp = "session_start_timestamp"
    }
}

struct CheckpointSignatureData: Codable {
    let sequenceNum: Int
    let commitmentHash: String
    let signature: String

    enum CodingKeys: String, CodingKey {
        case sequenceNum = "sequence_num"
        case commitmentHash = "commitment_hash"
        case signature
    }
}

// MARK: - Proof Service

/// Creates content bindings and exports proof bundles.
@MainActor
final class ProofService {
    private let attestation: DeviceAttestationService

    init(attestation: DeviceAttestationService) {
        self.attestation = attestation
    }

    /// Create the content binding and export the full proof bundle.
    func exportProofBundle(
        content: String,
        document: Document,
        commitments: [Commitment],
        keystrokeCount: Int
    ) async throws -> ProofBundle {
        // Compute content hash
        let contentHash = SpeakwriteCrypto.sha256Hex(content)

        // Get chain tip (last behavioral commitment hash)
        guard let chainTip = commitments.last?.commitmentHash else {
            throw ProofError.noCommitments
        }

        // Compute content binding hash
        let bindingHash = SpeakwriteCrypto.contentBindingHash(
            chainTip: chainTip,
            contentHash: contentHash
        )

        // Create the content binding commitment
        let bindingTimestampMs = ProcessInfo.processInfo.systemUptime * 1000

        // Sign the final binding with Secure Enclave
        let finalSig = try await attestation.signFinal(
            contentHash: contentHash,
            bindingHash: bindingHash
        )

        // Build commitment list (behavioral + content_binding)
        var proofCommitments: [ProofCommitment] = commitments.map { c in
            ProofCommitment(
                sequenceNum: c.sequenceNum,
                commitmentHash: c.commitmentHash,
                previousHash: c.previousHash,
                nonce: c.nonce,
                timestampMs: c.timestampMs,
                commitmentType: c.commitmentType,
                contentHash: nil,
                featuresJson: c.featureJSON,
                documentHash: c.documentHash,
                documentLength: c.documentLength,
                keystrokeCount: c.keystrokeCountAtCommit
            )
        }

        // Add the content binding commitment
        let bindingCommitment = ProofCommitment(
            sequenceNum: commitments.count,
            commitmentHash: bindingHash,
            previousHash: chainTip,
            nonce: "",
            timestampMs: bindingTimestampMs,
            commitmentType: "content_binding",
            contentHash: contentHash,
            featuresJson: nil,
            documentHash: nil,
            documentLength: nil,
            keystrokeCount: nil
        )
        proofCommitments.append(bindingCommitment)

        // Get device attestation envelope
        let envelope = await attestation.getAttestationEnvelope()
        let attestationData: DeviceAttestationData?
        if let envelope {
            attestationData = DeviceAttestationData(
                platform: envelope.platform,
                attestationType: envelope.attestationType,
                attestationLevel: envelope.attestationLevel,
                devicePublicKey: envelope.devicePublicKey,
                appId: envelope.appId,
                attestationCertificate: envelope.attestationCertificate,
                sessionBinding: envelope.sessionBinding.map { sb in
                    SessionBindingData(
                        sessionId: sb.sessionId,
                        biometricGate: sb.biometricGate,
                        sessionStartSignature: sb.sessionStartSignature,
                        sessionStartTimestamp: sb.sessionStartTimestamp
                    )
                },
                checkpointSignatures: envelope.checkpointSignatures.map { cs in
                    CheckpointSignatureData(
                        sequenceNum: cs.sequenceNum,
                        commitmentHash: cs.commitmentHash,
                        signature: cs.signature
                    )
                },
                finalSignature: envelope.finalSignature
            )
        } else {
            attestationData = nil
        }

        // Update document
        document.contentHash = contentHash
        document.updatedAt = Date()

        return ProofBundle(
            version: "2.0.0",
            documentId: document.id,
            contentHash: contentHash,
            bindingHash: bindingHash,
            totalKeystrokeCount: keystrokeCount,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            commitments: proofCommitments,
            deviceAttestation: attestationData
        )
    }

    /// Serialize proof bundle to JSON string.
    func bundleToJSON(_ bundle: ProofBundle) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ProofError.serializationFailed
        }
        return json
    }
}

enum ProofError: Error, LocalizedError {
    case noCommitments
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .noCommitments: return "No commitments in chain"
        case .serializationFailed: return "Failed to serialize proof bundle"
        }
    }
}
