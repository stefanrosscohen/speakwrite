import Foundation

// MARK: - Verification Service

@Observable
@MainActor
final class VerificationService {
    private var cache: [String: VerificationStatus] = [:]
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var authorProofCache: [String: [ProofRecord]] = [:]

    /// Post URIs whose last verification attempt failed transiently (network/5xx/429).
    /// These are NOT cached as .failed — the row retries on its next appearance,
    /// after a short cooldown to avoid hammering while scrolling.
    private var retryNotBefore: [String: Date] = [:]

    /// DID → resolved PDS endpoint, with expiry.
    private var pdsCache: [String: (endpoint: String, expiresAt: Date)] = [:]

    private static let fetchErrorCooldown: TimeInterval = 30
    private static let pdsCacheTTL: TimeInterval = 3600
    private static let maxProofPages = 5
    private static let proofPageLimit = 100

    private let verifier = AppAttestVerifier()

    func status(for postUri: String) -> VerificationStatus {
        cache[postUri] ?? .unverified
    }

    func verify(postUri: String, postText: String, authorDID: String) {
        // Already cached or in-flight
        if cache[postUri] != nil || inFlight[postUri] != nil { return }

        // Recent transient failure — wait out the cooldown before retrying
        if let notBefore = retryNotBefore[postUri], notBefore > Date() { return }
        retryNotBefore.removeValue(forKey: postUri)

        cache[postUri] = .verifying

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.performVerification(postUri: postUri, postText: postText, authorDID: authorDID)
                self.cache[postUri] = result
            } catch {
                // Transient fetch failure (network error, non-2xx, bad payload).
                // Don't cache a permanent .failed — clear the placeholder so the
                // UI retries on the row's next appearance.
                self.cache.removeValue(forKey: postUri)
                self.retryNotBefore[postUri] = Date().addingTimeInterval(Self.fetchErrorCooldown)
            }
            self.inFlight.removeValue(forKey: postUri)
        }
        inFlight[postUri] = task
    }

    private func performVerification(postUri: String, postText: String, authorDID: String) async throws -> VerificationStatus {
        // Fetch proof records for this author (cached per DID)
        var proofs: [ProofRecord]
        if let cached = authorProofCache[authorDID] {
            proofs = cached
        } else {
            proofs = try await fetchProofs(did: authorDID)
            authorProofCache[authorDID] = proofs
        }

        // Find proof matching this post URI — if not found, re-fetch in case of stale cache
        if !proofs.contains(where: { $0.postUri == postUri }) {
            proofs = try await fetchProofs(did: authorDID)
            authorProofCache[authorDID] = proofs
        }

        // The fetch genuinely succeeded and no proof exists — this is a definitive,
        // cacheable outcome (the post was not published through Speakwrite).
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

    // MARK: - DID resolution

    /// Resolve the PDS endpoint for a DID. Supports did:plc (via plc.directory)
    /// and did:web (via the host's /.well-known/did.json). Results are cached
    /// in memory for an hour.
    private func resolvePDS(did: String) async throws -> String {
        if let cached = pdsCache[did], cached.expiresAt > Date() {
            return cached.endpoint
        }

        let endpoint: String
        if did.hasPrefix("did:web:") {
            endpoint = try await resolveWebDID(did)
        } else {
            endpoint = try await resolvePLCDID(did)
        }

        pdsCache[did] = (endpoint, Date().addingTimeInterval(Self.pdsCacheTTL))
        return endpoint
    }

    private func resolvePLCDID(_ did: String) async throws -> String {
        let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did
        guard let url = URL(string: "https://plc.directory/\(encoded)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.ensureSuccess(response)
        return try Self.pdsEndpoint(fromDIDDocument: data)
    }

    private func resolveWebDID(_ did: String) async throws -> String {
        // did:web:example.com          → https://example.com/.well-known/did.json
        // did:web:example.com:some:path → https://example.com/some/path/did.json
        let identifier = String(did.dropFirst("did:web:".count))
        let segments = identifier
            .split(separator: ":")
            .map { String($0).removingPercentEncoding ?? String($0) }
        guard let host = segments.first, !host.isEmpty else {
            throw URLError(.badURL)
        }

        let urlString: String
        if segments.count == 1 {
            urlString = "https://\(host)/.well-known/did.json"
        } else {
            urlString = "https://\(host)/\(segments.dropFirst().joined(separator: "/"))/did.json"
        }
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.ensureSuccess(response)
        return try Self.pdsEndpoint(fromDIDDocument: data)
    }

    private static func pdsEndpoint(fromDIDDocument data: Data) throws -> String {
        struct DIDDoc: Decodable {
            struct Service: Decodable {
                let id: String
                let type: String?
                let serviceEndpoint: String
            }
            let service: [Service]?
        }

        let doc = try JSONDecoder().decode(DIDDoc.self, from: data)
        guard let pds = doc.service?.first(where: {
            $0.id.hasSuffix("#atproto_pds") || $0.type == "AtprotoPersonalDataServer"
        })?.serviceEndpoint else {
            throw URLError(.badServerResponse)
        }
        return pds
    }

    // MARK: - Proof fetching

    private func fetchProofs(did: String) async throws -> [ProofRecord] {
        let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did

        // Resolve the author's PDS — proof records live on their PDS, not a central server
        let pds = try await resolvePDS(did: did)

        var entries: [RecordEntry] = []
        var cursor: String?

        // Follow the pagination cursor up to a sane bound (5 pages / 500 records)
        for _ in 0..<Self.maxProofPages {
            var urlString = "\(pds)/xrpc/com.atproto.repo.listRecords?repo=\(encoded)&collection=io.speakwrite.proof&limit=\(Self.proofPageLimit)"
            if let cursor {
                let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
                urlString += "&cursor=\(encodedCursor)"
            }
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }

            let (data, response) = try await URLSession.shared.data(from: url)
            // Non-2xx (429/5xx/etc.) is a transient fetch failure, NOT "no proofs" —
            // throw so the caller treats it as retryable instead of caching .failed.
            try Self.ensureSuccess(response)

            let page = try JSONDecoder().decode(ListRecordsResponse.self, from: data)
            entries.append(contentsOf: page.records)

            guard let next = page.cursor, !next.isEmpty, !page.records.isEmpty else { break }
            cursor = next
        }

        return entries.compactMap { record -> ProofRecord? in
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
        }
    }

    private static func ensureSuccess(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
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
