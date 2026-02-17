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
    }

    func verify(proof: ProofData, postText: String) -> VerificationStatus {
        // 1. Content hash: SHA256(postText) must match proof.contentHash
        let expectedHash = Data(SHA256.hash(data: Data(postText.utf8)))
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

        // 6. Verify signature: nonce = SHA256(authenticatorData || clientDataHash)
        //    clientDataHash = SHA256(postText) (the content hash bytes, not hex)
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
