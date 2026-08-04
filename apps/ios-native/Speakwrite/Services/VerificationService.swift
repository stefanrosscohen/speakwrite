import Foundation

// MARK: - Verification Service

@Observable
@MainActor
final class VerificationService {
    private var cache: [String: VerificationStatus] = [:]
    private var failedAt: [String: Date] = [:]
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var authorProofCache: [String: [ProofRecord]] = [:]

    /// How long a failed verification stays cached before a retry is allowed.
    /// Failures are often transient (author's PDS briefly unreachable, proof
    /// record not yet indexed) — a permanent failure cache turns a blip into
    /// "this post is fake" for the rest of the session.
    private let failureRetryInterval: TimeInterval = 60

    private let verifier = AppAttestVerifier()

    func status(for postUri: String) -> VerificationStatus {
        cache[postUri] ?? .unverified
    }

    func verify(postUri: String, postText: String, authorDID: String, force: Bool = false) {
        if inFlight[postUri] != nil { return }

        if let cached = cache[postUri], !force {
            // Success and in-progress states are final for the session.
            // Failed states expire so transient errors can recover.
            if case .failed = cached {
                let lastAttempt = failedAt[postUri] ?? .distantPast
                guard Date().timeIntervalSince(lastAttempt) > failureRetryInterval else { return }
            } else {
                return
            }
        }

        cache[postUri] = .verifying

        let task = Task { [weak self] in
            guard let self else { return }
            let result = await self.performVerification(postUri: postUri, postText: postText, authorDID: authorDID)
            self.cache[postUri] = result
            if case .failed = result {
                self.failedAt[postUri] = Date()
            } else {
                self.failedAt.removeValue(forKey: postUri)
            }
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
            appId: proof.appId,
            mediaHashes: proof.mediaHashes
        )

        return await verifier.verify(proof: proofData, postText: postText)
    }

    /// Resolve PDS endpoint for a DID. Supports both did:plc (via the PLC
    /// directory) and did:web (via the domain's well-known DID document).
    private func resolvePDS(did: String) async throws -> String {
        struct DIDDoc: Decodable {
            struct Service: Decodable {
                let id: String
                let type: String?
                let serviceEndpoint: String
            }
            let service: [Service]?
        }

        let url: URL
        if did.hasPrefix("did:web:") {
            let host = String(did.dropFirst("did:web:".count))
                .removingPercentEncoding ?? String(did.dropFirst("did:web:".count))
            guard let didWebURL = URL(string: "https://\(host)/.well-known/did.json") else {
                throw URLError(.badURL)
            }
            url = didWebURL
        } else {
            let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did
            guard let plcURL = URL(string: "https://plc.directory/\(encoded)") else {
                throw URLError(.badURL)
            }
            url = plcURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let doc = try JSONDecoder().decode(DIDDoc.self, from: data)
        guard let pds = doc.service?.first(where: {
            $0.id.hasSuffix("#atproto_pds") || $0.type == "AtprotoPersonalDataServer"
        })?.serviceEndpoint else {
            throw URLError(.badServerResponse)
        }
        return pds
    }

    private func fetchProofs(did: String) async throws -> [ProofRecord] {
        let encoded = did.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? did

        // Resolve the author's PDS — proof records live on their PDS, not a central server
        let pds = try await resolvePDS(did: did)

        // Paginate: a single 100-record page silently broke verification for
        // authors with more than 100 proofs.
        var proofs: [ProofRecord] = []
        var cursor: String?
        let maxPages = 10

        for _ in 0..<maxPages {
            var urlString = "\(pds)/xrpc/com.atproto.repo.listRecords?repo=\(encoded)&collection=io.speakwrite.proof&limit=100"
            if let cursor,
               let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "&cursor=\(encodedCursor)"
            }

            let (data, response) = try await URLSession.shared.data(from: URL(string: urlString)!)

            guard let httpResponse = response as? HTTPURLResponse else { break }
            // 4xx → the repo genuinely has no accessible proofs (definitive).
            // 5xx → the PDS is having trouble (transient) — throw so the failure
            // is retried instead of being reported as "no proof record".
            if httpResponse.statusCode >= 500 {
                throw URLError(.badServerResponse)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                return proofs
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

            guard let next = result.cursor, !result.records.isEmpty else { break }
            cursor = next
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
