import CryptoKit
import Foundation

enum SpeakwriteCrypto {
    /// SHA-256 hash of a string, returned as lowercase hex.
    static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        return sha256Hex(data)
    }

    /// SHA-256 hash of raw data, returned as lowercase hex.
    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Hex.encode(Data(digest))
    }

    /// Incremental commitment hash: SHA-256(previous_bytes || nonce || data).
    /// If `previous` is nil (first commitment), only nonce || data are hashed.
    /// Must produce identical output to the TypeScript `commitmentHash()`.
    static func commitmentHash(previous: String?, nonce: Data, data: Data) -> String {
        var combined = Data()
        if let previous, let previousBytes = Hex.decode(previous) {
            combined.append(previousBytes)
        }
        combined.append(nonce)
        combined.append(data)
        let digest = SHA256.hash(data: combined)
        return Hex.encode(Data(digest))
    }

    /// Content binding hash: SHA-256(chainTip_bytes || "CONTENT_BINDING" || contentHash_bytes).
    /// Binds the final document content to the entire commitment chain.
    /// Must produce identical output to the TypeScript `contentBindingHash()`.
    static func contentBindingHash(chainTip: String, contentHash: String) -> String {
        guard let tipBytes = Hex.decode(chainTip),
              let hashBytes = Hex.decode(contentHash) else {
            fatalError("Invalid hex in contentBindingHash")
        }
        var combined = Data()
        combined.append(tipBytes)
        combined.append(Data("CONTENT_BINDING".utf8))
        combined.append(hashBytes)
        let digest = SHA256.hash(data: combined)
        return Hex.encode(Data(digest))
    }

    /// Generate 32 random bytes for use as a commitment nonce.
    static func randomNonce() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            fatalError("Failed to generate random nonce: \(status)")
        }
        return Data(bytes)
    }
}
