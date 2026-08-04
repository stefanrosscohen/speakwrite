import CryptoKit
import Foundation
import Security

// MARK: - Verification Status

enum VerificationStatus: Equatable {
    case unverified
    case verifying
    case verified
    case failed(String)
    /// The proof could not be checked (author's PDS unreachable, network down).
    /// Distinct from `.failed` — the proof may be fine; we just couldn't see it.
    case unavailable(String)
}

// MARK: - Verification Report

/// One step of the verification pipeline, for display in the proof detail sheet.
struct VerificationCheck: Identifiable, Equatable {
    let name: String
    let detail: String
    let passed: Bool
    var id: String { name }
}

/// Full result of verifying a post's proof — status plus the individual checks
/// and the evidence (hash, key) that was verified.
struct VerificationReport: Equatable {
    let status: VerificationStatus
    let checks: [VerificationCheck]
    let contentHash: String?
    let keyId: String?

    static func failure(_ message: String, checks: [VerificationCheck] = [],
                        contentHash: String? = nil, keyId: String? = nil) -> VerificationReport {
        VerificationReport(status: .failed(message), checks: checks, contentHash: contentHash, keyId: keyId)
    }
}

// MARK: - App Attest Verifier

actor AppAttestVerifier {
    private let rootCertificate: SecCertificate?

    init() {
        // Load Apple App Attest Root CA from bundle
        if let url = Bundle.main.url(forResource: "AppleAppAttestRootCA", withExtension: "cer"),
           let data = try? Data(contentsOf: url),
           let cert = SecCertificateCreateWithData(nil, data as CFData) {
            rootCertificate = cert
        } else {
            rootCertificate = nil
        }
    }

    struct ProofData {
        let postUri: String
        let keyId: String
        let attestationObject: String  // Base64
        let assertion: String          // Base64
        let contentHash: String        // Hex
        let appId: String
        let mediaHashes: [String]?     // Hex SHA-256 of each media blob
    }

    func verify(proof: ProofData, postText: String) -> VerificationReport {
        var checks: [VerificationCheck] = []

        func fail(_ name: String, _ detail: String) -> VerificationReport {
            checks.append(VerificationCheck(name: name, detail: detail, passed: false))
            return .failure(detail, checks: checks, contentHash: proof.contentHash, keyId: proof.keyId)
        }

        // 1. Content hash verification
        // Text-only (no media): SHA256(text) == contentHash
        // With media: SHA256(SHA256(text) + sorted_media_hashes) == contentHash
        let textHash = Data(SHA256.hash(data: Data(postText.utf8)))

        let expectedHash: Data
        if let mediaHashes = proof.mediaHashes, !mediaHashes.isEmpty {
            // Composite hash: SHA256(SHA256(text) + sorted media hash bytes)
            var compositeInput = textHash
            for hashHex in mediaHashes.sorted() {
                if let hashData = Data(hexString: hashHex) {
                    compositeInput.append(hashData)
                }
            }
            expectedHash = Data(SHA256.hash(data: compositeInput))
        } else {
            expectedHash = textHash
        }

        let expectedHex = expectedHash.map { String(format: "%02x", $0) }.joined()

        guard expectedHex == proof.contentHash else {
            return fail("Content hash", "The post text does not match the signed hash")
        }
        checks.append(VerificationCheck(
            name: "Content hash",
            detail: "SHA-256 of the post matches the signed hash",
            passed: true
        ))

        // 2. Decode attestation object (CBOR) → extract x5c cert chain + authData
        guard let attestationData = Data(base64Encoded: proof.attestationObject) else {
            return fail("Attestation", "Invalid attestation encoding")
        }

        guard let attestationCBOR = try? CBORDecoder.decode(attestationData) else {
            return fail("Attestation", "Invalid attestation CBOR")
        }

        // Extract attestation statement x5c certificates
        guard let attStmt = attestationCBOR["attStmt"],
              let x5cArray = attStmt["x5c"]?.arrayValue,
              !x5cArray.isEmpty else {
            return fail("Attestation", "No certificates in attestation")
        }

        let certDatas = x5cArray.compactMap { $0.dataValue }
        guard !certDatas.isEmpty else {
            return fail("Attestation", "Invalid certificate data")
        }

        // 3. Validate certificate chain against Apple App Attest Root CA
        guard let rootCert = rootCertificate else {
            return fail("Certificate chain", "Apple Root CA not available")
        }

        let secCerts = certDatas.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
        guard secCerts.count == certDatas.count else {
            return fail("Certificate chain", "Failed to parse certificates")
        }

        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(secCerts as CFArray, policy, &trust)
        guard status == errSecSuccess, let trust else {
            return fail("Certificate chain", "Failed to create trust chain")
        }

        SecTrustSetAnchorCertificates(trust, [rootCert] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)

        // App Attest leaf certs are short-lived (~72 hours). Evaluate the chain
        // at the time the leaf cert was issued, not the current time. This lets us
        // verify proofs long after the cert expires while still confirming Apple
        // signed the key on a genuine device.
        if let notBefore = Self.extractNotBefore(from: certDatas[0]) {
            SecTrustSetVerifyDate(trust, notBefore as CFDate)
        }

        var error: CFError?
        let trusted = SecTrustEvaluateWithError(trust, &error)
        guard trusted else {
            return fail("Certificate chain", "Chain does not validate against Apple's Root CA")
        }
        checks.append(VerificationCheck(
            name: "Certificate chain",
            detail: "Signed by Apple's App Attest Root CA — genuine device",
            passed: true
        ))

        // 4. Extract P-256 public key from leaf certificate
        guard let leafKey = SecTrustCopyKey(trust) else {
            return fail("Device signature", "Failed to extract public key from certificate")
        }

        var extractError: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(leafKey, &extractError) as Data? else {
            return fail("Device signature", "Failed to export public key")
        }

        guard let publicKey = try? P256.Signing.PublicKey(x963Representation: keyData) else {
            return fail("Device signature", "Invalid P-256 public key")
        }

        // 5. Decode assertion (CBOR) → extract signature + authenticatorData
        guard let assertionData = Data(base64Encoded: proof.assertion) else {
            return fail("Device signature", "Invalid assertion encoding")
        }

        guard let assertionCBOR = try? CBORDecoder.decode(assertionData) else {
            return fail("Device signature", "Invalid assertion CBOR")
        }

        guard let signatureData = assertionCBOR["signature"]?.dataValue,
              let authenticatorData = assertionCBOR["authenticatorData"]?.dataValue else {
            return fail("Device signature", "Missing signature in assertion")
        }

        // 6. Verify signature: nonce = SHA256(authenticatorData || clientDataHash)
        //    clientDataHash = content hash bytes (text-only or composite with media)
        let contentHashBytes = expectedHash
        var nonceInput = Data()
        nonceInput.append(authenticatorData)
        nonceInput.append(contentHashBytes)
        let nonce = Data(SHA256.hash(data: nonceInput))

        guard let signature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData) else {
            return fail("Device signature", "Invalid ECDSA signature")
        }

        let isValid = publicKey.isValidSignature(signature, for: nonce)
        guard isValid else {
            return fail("Device signature", "Secure Enclave signature does not verify")
        }
        checks.append(VerificationCheck(
            name: "Device signature",
            detail: "P-256 ECDSA signature from the Secure Enclave verifies",
            passed: true
        ))

        return VerificationReport(
            status: .verified,
            checks: checks,
            contentHash: proof.contentHash,
            keyId: proof.keyId
        )
    }

    // MARK: - X.509 notBefore Extraction

    /// Extract the notBefore date from a DER-encoded X.509 certificate by walking
    /// the ASN.1 structure: Certificate → TBSCertificate → Validity → notBefore.
    private static func extractNotBefore(from certData: Data) -> Date? {
        var offset = 0
        let bytes = [UInt8](certData)

        func readTagAndLength() -> (tag: UInt8, length: Int)? {
            guard offset < bytes.count else { return nil }
            let tag = bytes[offset]; offset += 1
            guard offset < bytes.count else { return nil }
            var length = Int(bytes[offset]); offset += 1
            if length & 0x80 != 0 {
                let numBytes = length & 0x7F
                guard offset + numBytes <= bytes.count else { return nil }
                length = 0
                for _ in 0..<numBytes {
                    length = (length << 8) | Int(bytes[offset]); offset += 1
                }
            }
            return (tag, length)
        }

        func skipElement() -> Bool {
            guard let (_, length) = readTagAndLength() else { return false }
            offset += length
            return offset <= bytes.count
        }

        func parseTime() -> Date? {
            guard let (tag, length) = readTagAndLength() else { return nil }
            guard tag == 0x17 || tag == 0x18 else { return nil } // UTCTime or GeneralizedTime
            guard offset + length <= bytes.count else { return nil }
            let timeBytes = bytes[offset..<(offset + length)]
            offset += length
            guard let timeStr = String(bytes: timeBytes, encoding: .ascii) else { return nil }
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(identifier: "UTC")
            if tag == 0x17 { // UTCTime: YYMMDDHHMMSSZ
                fmt.dateFormat = "yyMMddHHmmss'Z'"
            } else { // GeneralizedTime: YYYYMMDDHHMMSSZ
                fmt.dateFormat = "yyyyMMddHHmmss'Z'"
            }
            return fmt.date(from: timeStr)
        }

        // Certificate SEQUENCE
        guard let (t0, _) = readTagAndLength(), t0 == 0x30 else { return nil }
        // TBSCertificate SEQUENCE
        guard let (t1, _) = readTagAndLength(), t1 == 0x30 else { return nil }
        // Skip version [0] EXPLICIT (context tag 0xA0) if present
        if offset < bytes.count && bytes[offset] == 0xA0 { guard skipElement() else { return nil } }
        // Skip serialNumber INTEGER
        guard skipElement() else { return nil }
        // Skip signature AlgorithmIdentifier SEQUENCE
        guard skipElement() else { return nil }
        // Skip issuer Name SEQUENCE
        guard skipElement() else { return nil }
        // Validity SEQUENCE
        guard let (tv, _) = readTagAndLength(), tv == 0x30 else { return nil }
        // notBefore
        return parseTime()
    }
}

// MARK: - Data Hex Extension

extension Data {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
