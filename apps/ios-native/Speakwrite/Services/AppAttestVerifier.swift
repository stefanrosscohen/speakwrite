import CryptoKit
import Foundation
import Security

// MARK: - Verification Status

enum VerificationStatus: Equatable {
    case unverified
    case verifying
    case verified
    case failed(String)
}

// MARK: - App Attest Verifier

actor AppAttestVerifier {
    /// Apple Developer team identifier for Speakwrite (see project.pbxproj
    /// DEVELOPMENT_TEAM). App Attest's rpIdHash is SHA-256 of the full App ID
    /// "<teamID>.<bundleID>"; the proof record's appId field only carries the
    /// bundle identifier, so the team prefix is fixed here.
    private static let teamIdentifier = "J3Y68ZC9L2"
    private static let defaultBundleId = "io.speakwrite.app"

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

    func verify(proof: ProofData, postText: String) -> VerificationStatus {
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
            return .failed("Content hash mismatch")
        }

        // 2. Decode attestation object (CBOR) → extract x5c cert chain + authData
        guard let attestationData = Data(base64Encoded: proof.attestationObject) else {
            return .failed("Invalid attestation base64")
        }

        guard let attestationCBOR = try? CBORDecoder.decode(attestationData) else {
            return .failed("Invalid attestation CBOR")
        }

        // Extract attestation statement x5c certificates
        guard let attStmt = attestationCBOR["attStmt"],
              let x5cArray = attStmt["x5c"]?.arrayValue,
              !x5cArray.isEmpty else {
            return .failed("No x5c certificates in attestation")
        }

        let certDatas = x5cArray.compactMap { $0.dataValue }
        guard !certDatas.isEmpty else {
            return .failed("Invalid x5c certificate data")
        }

        // 3. Validate certificate chain against Apple App Attest Root CA
        guard let rootCert = rootCertificate else {
            return .failed("Apple Root CA not available")
        }

        let secCerts = certDatas.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
        guard secCerts.count == certDatas.count else {
            return .failed("Failed to create SecCertificate objects")
        }

        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(secCerts as CFArray, policy, &trust)
        guard status == errSecSuccess, let trust else {
            return .failed("Failed to create SecTrust")
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
            return .failed("Certificate chain validation failed")
        }

        // 4. Extract P-256 public key from leaf certificate
        guard let leafKey = SecTrustCopyKey(trust) else {
            return .failed("Failed to extract public key from certificate")
        }

        var extractError: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(leafKey, &extractError) as Data? else {
            return .failed("Failed to export public key")
        }

        guard let publicKey = try? P256.Signing.PublicKey(x963Representation: keyData) else {
            return .failed("Invalid P-256 public key")
        }

        // 4a. Key ID binding: an App Attest key identifier is the SHA-256 of the
        // leaf certificate's public key (X9.63 uncompressed point), base64-encoded.
        // This ties proof.keyId to the attested key instead of trusting the field.
        guard let keyIdData = Data(base64Encoded: proof.keyId) else {
            return .failed("Invalid key ID base64")
        }
        let publicKeyHash = Data(SHA256.hash(data: keyData))
        guard publicKeyHash == keyIdData else {
            return .failed("Key ID does not match certificate public key")
        }

        // 4b. Validate the attestation object's own authenticator data.
        if let fmt = attestationCBOR["fmt"]?.stringValue, fmt != "apple-appattest" {
            return .failed("Unexpected attestation format")
        }
        guard let attestAuthData = attestationCBOR["authData"]?.dataValue else {
            return .failed("Missing authData in attestation")
        }
        let attestBytes = [UInt8](attestAuthData)
        // rpIdHash(32) + flags(1) + counter(4) + aaguid(16) + credIdLen(2) = 55 bytes minimum
        guard attestBytes.count >= 55 else {
            return .failed("Attestation authenticator data too short")
        }

        // rpIdHash (bytes 0..32) must be SHA-256 of the full App ID
        // "<teamID>.<bundleID>". The proof record stores only the bundle id.
        let bundleId = proof.appId.isEmpty ? Self.defaultBundleId : proof.appId
        let fullAppId = "\(Self.teamIdentifier).\(bundleId)"
        let expectedRpIdHash = Data(SHA256.hash(data: Data(fullAppId.utf8)))
        guard Data(attestBytes[0..<32]) == expectedRpIdHash else {
            return .failed("App ID mismatch in attestation")
        }

        // aaguid (bytes 37..53) must be the production App Attest environment:
        // "appattest" followed by 7 zero bytes. The sandbox environment
        // ("appattestdevelop") is rejected — development keys prove nothing
        // about App Store / TestFlight builds.
        let productionAAGUID: [UInt8] = [
            0x61, 0x70, 0x70, 0x61, 0x74, 0x74, 0x65, 0x73, 0x74, // "appattest"
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]
        guard Array(attestBytes[37..<53]) == productionAAGUID else {
            return .failed("Attestation not from production App Attest environment")
        }

        // credentialId must equal the key ID — binds this attestation object
        // to the key whose assertions we verify.
        let credLen = Int(attestBytes[53]) << 8 | Int(attestBytes[54])
        guard credLen <= attestBytes.count - 55 else {
            return .failed("Attestation credential ID out of bounds")
        }
        guard Data(attestBytes[55..<(55 + credLen)]) == keyIdData else {
            return .failed("Credential ID does not match key ID")
        }

        // 4c. Nonce binding: the leaf certificate carries Apple's extension
        // OID 1.2.840.113635.100.8.2 whose value is
        // SHA256(attestation authData || clientDataHash). At key registration
        // the app uses clientDataHash = SHA256(keyId utf8) — see
        // DeviceAttestation.initialize() and the site verifier's
        // verifyAttestationNonce(). This proves the cert was issued for
        // exactly this authenticator data.
        guard let certNonce = Self.extractAttestationNonce(from: certDatas[0]) else {
            return .failed("Attestation nonce extension not found")
        }
        let keyIdHash = Data(SHA256.hash(data: Data(proof.keyId.utf8)))
        var attestNonceInput = attestAuthData
        attestNonceInput.append(keyIdHash)
        guard certNonce == Data(SHA256.hash(data: attestNonceInput)) else {
            return .failed("Attestation nonce mismatch")
        }

        // 5. Decode assertion (CBOR) → extract signature + authenticatorData
        guard let assertionData = Data(base64Encoded: proof.assertion) else {
            return .failed("Invalid assertion base64")
        }

        guard let assertionCBOR = try? CBORDecoder.decode(assertionData) else {
            return .failed("Invalid assertion CBOR")
        }

        guard let signatureData = assertionCBOR["signature"]?.dataValue,
              let authenticatorData = assertionCBOR["authenticatorData"]?.dataValue else {
            return .failed("Missing signature or authenticatorData in assertion")
        }

        // 5a. Assertion authenticator data: rpIdHash(32) + flags(1) + counter(4).
        let assertBytes = [UInt8](authenticatorData)
        guard assertBytes.count >= 37 else {
            return .failed("Assertion authenticator data too short")
        }

        // rpIdHash must match SHA-256 of the same App ID as the attestation.
        guard Data(assertBytes[0..<32]) == expectedRpIdHash else {
            return .failed("App ID mismatch in assertion")
        }

        // Counter (bytes 33..37, big-endian), parsed without trapping. Every
        // generateAssertion() call increments the key's counter, so a genuine
        // assertion always carries a counter >= 1. Verification here is
        // stateless (any feed post can be verified in isolation), so strict
        // per-key monotonicity across posts cannot be enforced — we require a
        // positive counter, which rejects attestation authData replayed as an
        // assertion (attestation authData has counter 0).
        let counter = UInt32(assertBytes[33]) << 24
            | UInt32(assertBytes[34]) << 16
            | UInt32(assertBytes[35]) << 8
            | UInt32(assertBytes[36])
        guard counter >= 1 else {
            return .failed("Invalid assertion counter")
        }

        // 6. Verify signature: nonce = SHA256(authenticatorData || clientDataHash)
        //    clientDataHash = content hash bytes (text-only or composite with media)
        let contentHashBytes = expectedHash
        var nonceInput = Data()
        nonceInput.append(authenticatorData)
        nonceInput.append(contentHashBytes)
        let nonce = Data(SHA256.hash(data: nonceInput))

        guard let signature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData) else {
            return .failed("Invalid ECDSA signature")
        }

        let isValid = publicKey.isValidSignature(signature, for: nonce)
        guard isValid else {
            return .failed("Signature verification failed")
        }

        return .verified
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
                // Bound the long-form length to 4 bytes: anything longer either
                // overflows Int (trap) or exceeds any real certificate size.
                guard numBytes <= 4, numBytes <= bytes.count - offset else { return nil }
                length = 0
                for _ in 0..<numBytes {
                    length = (length << 8) | Int(bytes[offset]); offset += 1
                }
            }
            // Reject lengths that run past the end of the buffer (also keeps
            // all subsequent offset arithmetic overflow-free).
            guard length <= bytes.count - offset else { return nil }
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

    // MARK: - Apple App Attest Nonce Extension Extraction

    /// Extract the nonce from the Apple App Attest leaf certificate extension
    /// (OID 1.2.840.113635.100.8.2) by walking the DER structure:
    /// Certificate → TBSCertificate → extensions [3] → Extension with the
    /// Apple OID → OCTET STRING wrapping SEQUENCE { [1] { OCTET STRING nonce } }.
    /// Returns nil (never traps) on any malformed input.
    private static func extractAttestationNonce(from certData: Data) -> Data? {
        let bytes = [UInt8](certData)
        var offset = 0

        // DER-encoded OID 1.2.840.113635.100.8.2
        let appleNonceOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x63, 0x64, 0x08, 0x02]

        func readTagAndLength() -> (tag: UInt8, length: Int)? {
            guard offset < bytes.count else { return nil }
            let tag = bytes[offset]; offset += 1
            guard offset < bytes.count else { return nil }
            var length = Int(bytes[offset]); offset += 1
            if length & 0x80 != 0 {
                let numBytes = length & 0x7F
                guard numBytes <= 4, numBytes <= bytes.count - offset else { return nil }
                length = 0
                for _ in 0..<numBytes {
                    length = (length << 8) | Int(bytes[offset]); offset += 1
                }
            }
            guard length <= bytes.count - offset else { return nil }
            return (tag, length)
        }

        func skipElement() -> Bool {
            guard let (_, length) = readTagAndLength() else { return false }
            offset += length
            return true
        }

        // Certificate SEQUENCE
        guard let (t0, _) = readTagAndLength(), t0 == 0x30 else { return nil }
        // TBSCertificate SEQUENCE
        guard let (t1, tbsLen) = readTagAndLength(), t1 == 0x30 else { return nil }
        let tbsEnd = offset + tbsLen
        // version [0] EXPLICIT, if present
        if offset < bytes.count && bytes[offset] == 0xA0 { guard skipElement() else { return nil } }
        // serialNumber, signature, issuer, validity, subject, subjectPublicKeyInfo
        for _ in 0..<6 { guard skipElement() else { return nil } }
        // Optional issuerUniqueID [1] / subjectUniqueID [2], then extensions [3]
        while offset < tbsEnd {
            let tag = bytes[offset]
            if tag == 0xA1 || tag == 0xA2 {
                guard skipElement() else { return nil }
                continue
            }
            guard tag == 0xA3 else { return nil }
            // extensions [3] EXPLICIT wrapper → SEQUENCE OF Extension
            guard readTagAndLength() != nil else { return nil }
            guard let (ts, seqLen) = readTagAndLength(), ts == 0x30 else { return nil }
            let seqEnd = offset + seqLen
            while offset < seqEnd {
                // Extension ::= SEQUENCE { extnID OID, critical BOOLEAN OPTIONAL,
                //                          extnValue OCTET STRING }
                guard let (te, extLen) = readTagAndLength(), te == 0x30 else { return nil }
                let extEnd = offset + extLen
                guard let (toid, oidLen) = readTagAndLength(), toid == 0x06 else { return nil }
                let matches = oidLen == appleNonceOID.count
                    && Array(bytes[offset..<(offset + oidLen)]) == appleNonceOID
                offset += oidLen
                guard matches else {
                    offset = extEnd // skip this extension entirely
                    continue
                }
                // Optional critical BOOLEAN
                if offset < bytes.count && bytes[offset] == 0x01 {
                    guard skipElement() else { return nil }
                }
                // extnValue OCTET STRING
                guard let (tval, _) = readTagAndLength(), tval == 0x04 else { return nil }
                // Inner SEQUENCE { [1] { OCTET STRING nonce } }
                guard let (tseq, innerLen) = readTagAndLength(), tseq == 0x30 else { return nil }
                let innerEnd = offset + innerLen
                while offset < innerEnd {
                    guard let (tctx, ctxLen) = readTagAndLength() else { return nil }
                    if tctx == 0xA1 {
                        guard let (toct, nonceLen) = readTagAndLength(), toct == 0x04 else { return nil }
                        return Data(bytes[offset..<(offset + nonceLen)])
                    }
                    offset += ctxLen
                }
                return nil
            }
            return nil
        }
        return nil
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
