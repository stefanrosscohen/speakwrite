import Foundation

// MARK: - Verification Service

@Observable
@MainActor
final class VerificationService {
    private var cache: [String: VerificationStatus] = [:]
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var authorProofCache: [String: [ProofRecord]] = [:]

    private let verifier = AppAttestVerifier()

    func status(for postUri: String) -> VerificationStatus {
        cache[postUri] ?? .unverified
    }

    func verify(postUri: String, postText: String, authorDID: String) {
        // Already cached or in-flight
        if cache[postUri] != nil || inFlight[postUri] != nil { return }

        cache[postUri] = .verifying

        let task = Task { [weak self] in
            guard let self else { return }
            let result = await self.performVerification(postUri: postUri, postText: postText, authorDID: authorDID)
            self.cache[postUri] = result
            self.inFlight.removeValue(forKey: postUri)
        }
        inFlight[postUri] = task
    }

    private func performVerification(postUri: String, postText: String, authorDID: String) async -> VerificationStatus {
        // Fetch proof records for this author (cached per DID)
        var proofs: [ProofRecord]
        if let cached = authorProofCache[authorDID] {
            proofs = cached
        } else {
            do {
                proofs = try await fetchProofs(did: authorDID)
                authorProofCache[authorDID] = proofs
            } catch {
                return .failed("Failed to fetch proofs: \(error.localizedDescription)")
            }
        }

        // Find proof matching this post URI — if not found, re-fetch in case of stale cache
        if !proofs.contains(where: { $0.postUri == postUri }) {
            do {
                proofs = try await fetchProofs(did: authorDID)
                authorProofCache[authorDID] = proofs
            } catch {
                return .failed("Failed to fetch proofs: \(error.localizedDescription)")
            }
        }

        guard let proof = proofs.first(where: { $0.postUri == postUri }) else {
            return .failed("No proof record")
        }

        // Run cryptographic verification
        let proofData = AppAttestVerifier.ProofData(
            postUri: proof.postUri,
            keyId: proof.keyId,
            attestationObject: proof.attestationObject,
            assertion: proof.assertion,
            contentHash: proof.contentHash,
            appId: proof.appId
        )

        return await verifier.verify(proof: proofData, postText: postText)
    }

    /// Resolve PDS endpoint for a DID via the PLC directory.
    private func resolvePDS(did: String) async throws -> String {
        let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did
        let url = URL(string: "https://plc.directory/\(encoded)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct DIDDoc: Decodable {
            struct Service: Decodable {
                let id: String
                let serviceEndpoint: String
            }
            let service: [Service]?
        }

        let doc = try JSONDecoder().decode(DIDDoc.self, from: data)
        guard let pds = doc.service?.first(where: { $0.id == "#atproto_pds" })?.serviceEndpoint else {
            throw URLError(.badServerResponse)
        }
        return pds
    }

    private func fetchProofs(did: String) async throws -> [ProofRecord] {
        let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did

        // Resolve the author's PDS — proof records live on their PDS, not a central server
        let pds = try await resolvePDS(did: did)
        let urlString = "\(pds)/xrpc/com.atproto.repo.listRecords?repo=\(encoded)&collection=io.speakwrite.proof&limit=100"

        let (data, response) = try await URLSession.shared.data(from: URL(string: urlString)!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            return []
        }

        let result = try JSONDecoder().decode(ListRecordsResponse.self, from: data)
        return result.records.compactMap { record -> ProofRecord? in
            guard let value = record.value else { return nil }
            return ProofRecord(
                postUri: value.postUri ?? "",
                keyId: value.keyId ?? "",
                attestationObject: value.attestationObject ?? "",
                assertion: value.assertion ?? "",
                contentHash: value.contentHash ?? "",
                appId: value.appId ?? ""
            )
        }
    }
}

// MARK: - Response Types

private struct ListRecordsResponse: Decodable {
    let records: [RecordEntry]
    let cursor: String?
}

private struct RecordEntry: Decodable {
    let uri: String
    let value: ProofRecordValue?
}

private struct ProofRecordValue: Decodable {
    let postUri: String?
    let keyId: String?
    let attestationObject: String?
    let assertion: String?
    let contentHash: String?
    let appId: String?
}

private struct ProofRecord {
    let postUri: String
    let keyId: String
    let attestationObject: String
    let assertion: String
    let contentHash: String
    let appId: String
}
