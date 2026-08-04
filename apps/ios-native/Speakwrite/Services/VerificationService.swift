import Foundation

// MARK: - Verification Service

@Observable
@MainActor
final class VerificationService {
    private var cache: [String: VerificationStatus] = [:]
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var authorProofCache: [String: [ProofRecord]] = [:]
    /// Timestamp of the last proof fetch per author, so a missing proof only
    /// triggers one re-fetch per author per interval instead of one per row.
    private var authorFetchedAt: [String: Date] = [:]
    /// De-duplicates concurrent proof fetches for the same author — N visible
    /// rows from one author must produce one network call, not N.
    private var authorFetchTasks: [String: Task<[ProofRecord]?, Never>] = [:]

    private let verifier = AppAttestVerifier()
    private static let refetchInterval: TimeInterval = 60

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
            if let result {
                self.cache[postUri] = result
            } else {
                // Transient network failure — clear the entry so scrolling back
                // retries instead of permanently showing a wrong state
                self.cache.removeValue(forKey: postUri)
            }
            self.inFlight.removeValue(forKey: postUri)
        }
        inFlight[postUri] = task
    }

    /// Fetch proofs for an author, coalescing concurrent callers into one
    /// network request. Returns nil on network failure.
    private func fetchProofsCoalesced(did: String) async -> [ProofRecord]? {
        if let existing = authorFetchTasks[did] {
            return await existing.value
        }
        let task = Task<[ProofRecord]?, Never> { [weak self] in
            do {
                return try await self?.fetchProofs(did: did)
            } catch {
                return nil
            }
        }
        authorFetchTasks[did] = task
        let result = await task.value
        authorFetchTasks.removeValue(forKey: did)
        if let result {
            authorProofCache[did] = result
            authorFetchedAt[did] = Date()
        }
        return result
    }

    /// Returns nil for a transient failure (do not cache), or a final status.
    private func performVerification(postUri: String, postText: String, authorDID: String) async -> VerificationStatus? {
        // Fetch proof records for this author (cached per DID)
        var proofs: [ProofRecord]
        if let cached = authorProofCache[authorDID] {
            proofs = cached
        } else if let fetched = await fetchProofsCoalesced(did: authorDID) {
            proofs = fetched
        } else {
            return nil
        }

        // Proof not in cache: re-fetch at most once per interval per author
        // (the post may be newer than the cached proof list)
        if !proofs.contains(where: { $0.postUri == postUri }) {
            let lastFetch = authorFetchedAt[authorDID] ?? .distantPast
            if Date().timeIntervalSince(lastFetch) > Self.refetchInterval {
                if let fetched = await fetchProofsCoalesced(did: authorDID) {
                    proofs = fetched
                } else {
                    return nil
                }
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
            appId: proof.appId,
            mediaHashes: proof.mediaHashes
        )

        return await verifier.verify(proof: proofData, postText: postText)
    }

    /// Resolve PDS endpoint for a DID via the PLC directory.
    private func resolvePDS(did: String) async throws -> String {
        let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did
        guard let url = URL(string: "https://plc.directory/\(encoded)") else {
            throw URLError(.badURL)
        }
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

        // Paginate: authors with more than one page of proofs must still verify
        var proofs: [ProofRecord] = []
        var cursor: String?
        for _ in 0..<4 {
            var urlString = "\(pds)/xrpc/com.atproto.repo.listRecords?repo=\(encoded)&collection=io.speakwrite.proof&limit=100"
            if let cursor {
                let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
                urlString += "&cursor=\(encodedCursor)"
            }
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                // A real error must throw (transient, retryable) — returning []
                // here would cache "no proof" for a network hiccup
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(ListRecordsResponse.self, from: data)
            proofs.append(contentsOf: result.records.compactMap { record -> ProofRecord? in
                guard let value = record.value else { return nil }
                return ProofRecord(
                    postUri: value.postUri ?? "",
                    keyId: value.keyId ?? "",
                    attestationObject: value.attestationObject ?? "",
                    assertion: value.assertion ?? "",
                    contentHash: value.contentHash ?? "",
                    appId: value.appId ?? "",
                    mediaHashes: value.mediaHashes
                )
            })

            cursor = result.cursor
            if cursor == nil || result.records.isEmpty { break }
        }
        return proofs
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
    let mediaHashes: [String]?
}

private struct ProofRecord {
    let postUri: String
    let keyId: String
    let attestationObject: String
    let assertion: String
    let contentHash: String
    let appId: String
    let mediaHashes: [String]?
}
