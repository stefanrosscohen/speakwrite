import AuthenticationServices
import CryptoKit
import Foundation

// MARK: - AT Protocol Service

/// Handles AT Protocol OAuth (PKCE + DPoP) and publishing via XRPC.
@Observable
@MainActor
final class ATProtoService {
    private(set) var isLoggedIn = false
    private(set) var handle: String?
    private(set) var did: String?

    private var accessToken: String?
    private var refreshToken: String?
    private var pdsURL: String?
    private var tokenEndpointURL: String? // Persisted for token refresh
    private var dpopKeyPair: P256.Signing.PrivateKey?
    private var dpopNonce: String? // Server-provided nonce for DPoP
    private var authSession: ASWebAuthenticationSession? // Keep strong reference during OAuth
    private var presentationProvider: PresentationContextProvider? // Keep strong reference during OAuth

    // MARK: - Session Persistence

    /// Persist auth session to Keychain + UserDefaults so it survives app restarts.
    func persistSession() {
        UserDefaults.standard.set(handle, forKey: "sw_handle")
        UserDefaults.standard.set(did, forKey: "sw_did")
        UserDefaults.standard.set(pdsURL, forKey: "sw_pds")
        UserDefaults.standard.set(tokenEndpointURL, forKey: "sw_token_endpoint")
        if let token = accessToken {
            KeychainHelper.save(key: "sw_access_token", value: token)
        }
        if let token = refreshToken {
            KeychainHelper.save(key: "sw_refresh_token", value: token)
        }
        if let key = dpopKeyPair {
            KeychainHelper.saveData(key: "sw_dpop_key", value: key.rawRepresentation)
        }
    }

    /// Restore a previous auth session on app launch. Returns true if restored.
    @discardableResult
    func restoreSession() -> Bool {
        guard let h = UserDefaults.standard.string(forKey: "sw_handle"),
              let d = UserDefaults.standard.string(forKey: "sw_did"),
              let p = UserDefaults.standard.string(forKey: "sw_pds"),
              let at = KeychainHelper.load(key: "sw_access_token"), !at.isEmpty
        else { return false }

        handle = h
        did = d
        pdsURL = p
        accessToken = at
        refreshToken = KeychainHelper.load(key: "sw_refresh_token")
        tokenEndpointURL = UserDefaults.standard.string(forKey: "sw_token_endpoint")

        // Restore the DPoP key pair that was used during token exchange
        if let keyData = KeychainHelper.loadData(key: "sw_dpop_key"),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
            dpopKeyPair = key
        } else {
            // No persisted key — tokens are bound to the old key, so session is invalid.
            // Clean up partial restore.
            handle = nil; did = nil; pdsURL = nil; accessToken = nil; refreshToken = nil
            return false
        }

        isLoggedIn = true
        return true
    }

    // MARK: - OAuth Flow

    func resolveHandle(_ handle: String, serviceHost: String = "https://bsky.social") async throws -> (did: String, pds: String) {
        let url = URL(string: "\(serviceHost)/xrpc/com.atproto.identity.resolveHandle?handle=\(handle)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(ResolveHandleResponse.self, from: data)

        let didDocURL = URL(string: "https://plc.directory/\(result.did)")!
        let (didData, _) = try await URLSession.shared.data(from: didDocURL)
        let didDoc = try JSONDecoder().decode(DIDDocument.self, from: didData)

        guard let pds = didDoc.service?.first(where: { $0.type == "AtprotoPersonalDataServer" })?.serviceEndpoint else {
            throw ATProtoError.noPDS
        }

        return (did: result.did, pds: pds)
    }

    /// Discover the authorization server URL from a PDS's protected resource metadata.
    private func discoverAuthorizationServer(pds: String) async throws -> String {
        let url = URL(string: "\(pds)/.well-known/oauth-protected-resource")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resource = try JSONDecoder().decode(OAuthProtectedResource.self, from: data)
        guard let server = resource.authorizationServers.first else {
            throw ATProtoError.noPDS
        }
        return server
    }

    func signIn(handle: String, serviceHost: String = "https://bsky.social", presentationAnchor: ASPresentationAnchor) async throws {
        let (resolvedDID, pds) = try await resolveHandle(handle, serviceHost: serviceHost)

        // Discover the authorization server from the PDS's protected resource metadata
        let authServer = try await discoverAuthorizationServer(pds: pds)

        let metadataURL = URL(string: "\(authServer)/.well-known/oauth-authorization-server")!
        let (metaData, _) = try await URLSession.shared.data(from: metadataURL)
        let metadata = try JSONDecoder().decode(OAuthServerMetadata.self, from: metaData)

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = computeCodeChallenge(codeVerifier)
        dpopKeyPair = P256.Signing.PrivateKey()

        let state = UUID().uuidString
        let redirectURI = "io.speakwrite.www:/oauth/callback"
        let clientId = "https://www.speakwrite.io/app/client-metadata.json"

        let authParams: [(String, String)] = [
            ("response_type", "code"),
            ("client_id", clientId),
            ("redirect_uri", redirectURI),
            ("scope", "atproto transition:generic"),
            ("state", state),
            ("code_challenge", codeChallenge),
            ("code_challenge_method", "S256"),
            ("login_hint", handle),
        ]

        // Build the auth URL — use PAR if required by the server
        let authURL: URL
        if let parEndpoint = metadata.pushedAuthorizationRequestEndpoint {
            // Pushed Authorization Request: POST params to PAR endpoint, get request_uri back
            let parResult = try await performPAR(endpoint: parEndpoint, params: authParams)

            var components = URLComponents(string: metadata.authorizationEndpoint)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "request_uri", value: parResult.requestUri),
            ]
            authURL = components.url!
        } else {
            // Standard authorization request (no PAR)
            var components = URLComponents(string: metadata.authorizationEndpoint)!
            components.queryItems = authParams.map { URLQueryItem(name: $0.0, value: $0.1) }
            authURL = components.url!
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "io.speakwrite.www") { [weak self] url, error in
                self?.authSession = nil
                self?.presentationProvider = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ATProtoError.authCancelled)
                }
            }
            self.presentationProvider = PresentationContextProvider(anchor: presentationAnchor)
            session.presentationContextProvider = self.presentationProvider
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }

        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw ATProtoError.noAuthCode
        }

        try await exchangeCodeForTokens(
            code: code, codeVerifier: codeVerifier, redirectURI: redirectURI,
            clientId: clientId, tokenEndpoint: metadata.tokenEndpoint, pds: pds
        )

        self.handle = handle
        self.did = resolvedDID
        self.pdsURL = pds
        self.tokenEndpointURL = metadata.tokenEndpoint
        self.isLoggedIn = true
        persistSession()
    }

    /// Perform a Pushed Authorization Request (PAR), handling DPoP nonce exchange.
    private func performPAR(endpoint: String, params: [(String, String)]) async throws -> PARResponse {
        func buildRequest() throws -> URLRequest {
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            if let dpopHeader = try createDPoPProof(method: "POST", url: endpoint) {
                request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
            }
            let bodyString = params.map {
                "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.1)"
            }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            return request
        }

        func decodePARResponse(_ data: Data, statusCode: Int) throws -> PARResponse {
            if statusCode >= 200 && statusCode < 300 {
                return try JSONDecoder().decode(PARResponse.self, from: data)
            }
            // Try decoding as OAuth error
            if let oauthErr = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                throw ATProtoError.oauthError(oauthErr.error, oauthErr.errorDescription)
            }
            throw ATProtoError.oauthError("http_\(statusCode)", String(data: data, encoding: .utf8))
        }

        let request = try buildRequest()
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        // Capture DPoP nonce if provided
        if let nonce = httpResponse?.value(forHTTPHeaderField: "DPoP-Nonce") {
            dpopNonce = nonce

            // If 400 with a new nonce, it's likely a DPoP nonce challenge — retry
            if httpResponse?.statusCode == 400 {
                let retryRequest = try buildRequest()
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0
                // Capture nonce from retry too
                if let retryNonce = (retryResponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "DPoP-Nonce") {
                    dpopNonce = retryNonce
                }
                return try decodePARResponse(retryData, statusCode: retryStatus)
            }
        }

        return try decodePARResponse(data, statusCode: httpResponse?.statusCode ?? 0)
    }

    private func exchangeCodeForTokens(
        code: String, codeVerifier: String, redirectURI: String,
        clientId: String, tokenEndpoint: String, pds: String
    ) async throws {
        let bodyDict: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
            "code_verifier": codeVerifier,
        ]
        let bodyData = try JSONEncoder().encode(bodyDict)

        func buildRequest() throws -> URLRequest {
            var request = URLRequest(url: URL(string: tokenEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let dpopHeader = try createDPoPProof(method: "POST", url: tokenEndpoint) {
                request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
            }
            request.httpBody = bodyData
            return request
        }

        let request = try buildRequest()
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
            dpopNonce = nonce

            // Retry with nonce if we got a 400 (DPoP nonce challenge)
            if httpResponse.statusCode == 400 {
                let retryRequest = try buildRequest()
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                if let retryHttp = retryResponse as? HTTPURLResponse,
                   let retryNonce = retryHttp.value(forHTTPHeaderField: "DPoP-Nonce") {
                    dpopNonce = retryNonce
                }
                let tokens = try JSONDecoder().decode(TokenResponse.self, from: retryData)
                accessToken = tokens.accessToken
                refreshToken = tokens.refreshToken
                return
            }
        }

        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
    }

    // MARK: - Publishing

    private static let testFlightURL = "https://testflight.apple.com/join/speakwrite"

    func publishAttestedPost(text: String, attestation: AttestationRecord) async throws -> (uri: String, cid: String) {
        guard let pds = pdsURL, let did = did, let handle = handle else { throw ATProtoError.notLoggedIn }

        // Generate rkey upfront so we can construct the verify URL
        let rkey = generateTID()
        let verifyURL = "https://speakwrite.io/verify/\(handle)/\(rkey)"

        // Build footer (hidden in Speakwrite app, visible on Bluesky and other clients)
        let footer = "\n\n✓ Verify a human wrote this · Try Speakwrite"
        let publishText = text + footer

        // Parse @mentions from the original text and build facets
        var facets = try await buildMentionFacets(text: publishText)

        // Add link facets for the footer
        let footerStart = Array(text.utf8).count + Array("\n\n✓ ".utf8).count
        // "Verify a human wrote this" → speakwrite.io verification page
        let verifyText = "Verify a human wrote this"
        let verifyByteStart = footerStart
        let verifyByteEnd = verifyByteStart + Array(verifyText.utf8).count
        facets.append([
            "index": ["byteStart": verifyByteStart, "byteEnd": verifyByteEnd],
            "features": [["$type": "app.bsky.richtext.facet#link", "uri": verifyURL]]
        ])
        // "Try Speakwrite" → TestFlight download
        let separatorBytes = Array(" · ".utf8).count
        let tryText = "Try Speakwrite"
        let tryByteStart = verifyByteEnd + separatorBytes
        let tryByteEnd = tryByteStart + Array(tryText.utf8).count
        facets.append([
            "index": ["byteStart": tryByteStart, "byteEnd": tryByteEnd],
            "features": [["$type": "app.bsky.richtext.facet#link", "uri": Self.testFlightURL]]
        ])

        var postRecord: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": publishText,
            "tags": ["speakwrite"],
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]

        if !facets.isEmpty {
            postRecord["facets"] = facets
        }

        let postResult: CreateRecordResponse = try await createRecord(
            pds: pds, did: did, collection: "app.bsky.feed.post", record: postRecord, rkey: rkey
        )

        // Attestation proof record — verifiers check the attestationObject cert chain
        // against Apple's App Attest root CA, then verify the assertion signature
        let proofRecord: [String: Any] = [
            "$type": "io.speakwrite.proof",
            "postUri": postResult.uri,
            "keyId": attestation.keyId,
            "attestationObject": attestation.attestationObject,
            "assertion": attestation.assertion,
            "contentHash": attestation.contentHash,
            "appId": attestation.appId,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]

        let _: CreateRecordResponse? = try? await createRecord(
            pds: pds, did: did, collection: "io.speakwrite.proof", record: proofRecord
        )

        return (uri: postResult.uri, cid: postResult.cid)
    }

    // MARK: - @Mention Facets

    private func buildMentionFacets(text: String) async throws -> [[String: Any]] {
        var facets: [[String: Any]] = []

        // Find @mentions using regex
        let pattern = try NSRegularExpression(pattern: "@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?")
        let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let mention = String(text[range])
            let handle = String(mention.dropFirst()) // remove @

            // Resolve handle to DID
            guard let did = try? await resolveHandleToDID(handle) else { continue }

            // Calculate byte offsets
            let beforeMention = String(text[text.startIndex..<range.lowerBound])
            let byteStart = Array(beforeMention.utf8).count
            let byteEnd = byteStart + Array(mention.utf8).count

            let facet: [String: Any] = [
                "index": [
                    "byteStart": byteStart,
                    "byteEnd": byteEnd,
                ] as [String: Any],
                "features": [
                    [
                        "$type": "app.bsky.richtext.facet#mention",
                        "did": did,
                    ] as [String: Any]
                ],
            ]
            facets.append(facet)
        }

        return facets
    }

    func resolveHandleToDID(_ handle: String) async throws -> String {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=\(handle)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(ResolveHandleResponse.self, from: data)
        return result.did
    }

    // MARK: - User Search

    func searchUsers(query: String, limit: Int = 10) async throws -> [ProfileViewBasic] {
        let publicAPI = "https://api.bsky.app"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(publicAPI)/xrpc/app.bsky.actor.searchActors?q=\(encoded)&limit=\(limit)"

        let (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        let result = try JSONDecoder().decode(SearchActorsResponse.self, from: data)
        return result.actors
    }

    func searchUsersTypeahead(query: String, limit: Int = 8) async throws -> [ProfileViewBasic] {
        let publicAPI = "https://api.bsky.app"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(publicAPI)/xrpc/app.bsky.actor.searchActorsTypeahead?q=\(encoded)&limit=\(limit)"

        let (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        let result = try JSONDecoder().decode(SearchActorsTypeaheadResponse.self, from: data)
        return result.actors
    }

    // MARK: - Feed (Global Verified Posts)

    func fetchVerifiedFeed(cursor: String? = nil) async throws -> (posts: [VerifiedPost], cursor: String?) {
        let publicAPI = "https://api.bsky.app"

        // Single search: #speakwrite matches both tags array and text containing "speakwrite"
        var urlString = "\(publicAPI)/xrpc/app.bsky.feed.searchPosts?q=%23speakwrite&limit=25&sort=latest"
        if let cursor {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            urlString += "&cursor=\(encoded)"
        }

        let (data, response) = try await URLSession.shared.data(from: URL(string: urlString)!)

        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            return (posts: [], cursor: nil)
        }

        let result = try JSONDecoder().decode(SearchPostsResponse.self, from: data)
        let posts = result.posts.compactMap { post -> VerifiedPost? in
            guard post.record.isSpeakwrite else { return nil }
            return VerifiedPost(
                uri: post.uri, cid: post.cid, author: post.author,
                text: post.record.displayText, createdAt: post.record.safeCreatedAt,
                likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0, viewer: post.viewer
            )
        }

        return (posts: posts, cursor: result.cursor)
    }

    // MARK: - Timeline (Discover / For You Feed)

    func fetchTimeline(cursor: String? = nil) async throws -> (posts: [TimelinePost], cursor: String?) {
        let feedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
        let encodedFeed = feedURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? feedURI

        let data: Data
        if let pds = pdsURL, accessToken != nil {
            // Authenticated — viewer state (following, etc.) will be included
            var urlString = "\(pds)/xrpc/app.bsky.feed.getFeed?feed=\(encodedFeed)&limit=30"
            if let cursor { urlString += "&cursor=\(cursor)" }
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            // Fallback to public API (no viewer state)
            let publicAPI = "https://api.bsky.app"
            var urlString = "\(publicAPI)/xrpc/app.bsky.feed.getFeed?feed=\(encodedFeed)&limit=30"
            if let cursor { urlString += "&cursor=\(cursor)" }
            var request = URLRequest(url: URL(string: urlString)!)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            (data, _) = try await URLSession.shared.data(for: request)
        }

        let result = try JSONDecoder().decode(FeedResponse.self, from: data)

        return (posts: parseFeedPosts(result.feed), cursor: result.cursor)
    }

    // MARK: - Following Timeline (Authenticated)

    func fetchFollowingTimeline(cursor: String? = nil) async throws -> (posts: [TimelinePost], cursor: String?) {
        guard let pds = pdsURL, let myDID = did else { throw ATProtoError.notLoggedIn }

        var urlString = "\(pds)/xrpc/app.bsky.feed.getTimeline?limit=50"
        if let cursor { urlString += "&cursor=\(cursor)" }

        let (data, _) = try await authenticatedRequest(url: urlString, method: "GET")

        let result = try JSONDecoder().decode(FeedResponse.self, from: data)

        // Filter to only posts from followed accounts or the user's own posts.
        // getTimeline can include suggested/algorithmic posts from non-followed accounts.
        let allPosts = parseFeedPosts(result.feed)
        let filtered = allPosts.filter { post in
            // Own posts
            if post.author.did == myDID { return true }
            // Posts from followed authors
            if post.author.viewer?.following != nil { return true }
            // Reposts by someone you follow (the original author may not be followed)
            if post.repostedBy != nil { return true }
            return false
        }

        return (posts: filtered, cursor: result.cursor)
    }

    /// Parse feed items into TimelinePost array.
    private func parseFeedPosts(_ feedItems: [FeedItem]) -> [TimelinePost] {
        return feedItems.compactMap { item -> TimelinePost? in
            let post = item.post
            guard let text = post.record?.text else { return nil }

            // Strip speakwrite footer for clean display (backward compat with old posts)
            let displayText = Self.stripSpeakwriteFooter(text)

            // Extract repost attribution
            let repostedBy: String?
            if item.reason?.type == "app.bsky.feed.defs#reasonRepost",
               let by = item.reason?.by {
                repostedBy = by.displayName ?? by.handle
            } else {
                repostedBy = nil
            }

            return TimelinePost(
                uri: post.uri, cid: post.cid, author: post.author,
                text: displayText, createdAt: post.record?.createdAt ?? "",
                likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0, isVerified: false,
                viewer: post.viewer, repostedBy: repostedBy
            )
        }
    }

    // MARK: - Profile

    func getProfile(actor: String) async throws -> ProfileViewDetailed {
        let encoded = actor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? actor

        let data: Data
        if let pds = pdsURL, accessToken != nil {
            let urlString = "\(pds)/xrpc/app.bsky.actor.getProfile?actor=\(encoded)"
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            let publicAPI = "https://api.bsky.app"
            let urlString = "\(publicAPI)/xrpc/app.bsky.actor.getProfile?actor=\(encoded)"
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

        return try JSONDecoder().decode(ProfileViewDetailed.self, from: data)
    }

    func getAuthorFeed(actor: String, cursor: String? = nil) async throws -> (posts: [TimelinePost], cursor: String?) {
        let encoded = actor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? actor

        let data: Data
        if let pds = pdsURL, accessToken != nil {
            var urlString = "\(pds)/xrpc/app.bsky.feed.getAuthorFeed?actor=\(encoded)&limit=30"
            if let cursor { urlString += "&cursor=\(cursor)" }
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            let publicAPI = "https://api.bsky.app"
            var urlString = "\(publicAPI)/xrpc/app.bsky.feed.getAuthorFeed?actor=\(encoded)&limit=30"
            if let cursor { urlString += "&cursor=\(cursor)" }
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

        let result = try JSONDecoder().decode(FeedResponse.self, from: data)

        let posts = result.feed.compactMap { item -> TimelinePost? in
            let post = item.post
            guard let text = post.record?.text else { return nil }

            return TimelinePost(
                uri: post.uri, cid: post.cid, author: post.author,
                text: Self.stripSpeakwriteFooter(text), createdAt: post.record?.createdAt ?? "",
                likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0, isVerified: false,
                viewer: post.viewer, repostedBy: nil
            )
        }

        return (posts: posts, cursor: result.cursor)
    }

    // MARK: - Engagement

    func likePost(uri: String, cid: String) async throws -> String {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }
        let record: [String: Any] = [
            "$type": "app.bsky.feed.like",
            "subject": ["uri": uri, "cid": cid],
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let result: CreateRecordResponse = try await createRecord(
            pds: pds, did: did, collection: "app.bsky.feed.like", record: record
        )
        return result.uri
    }

    func unlikePost(likeUri: String) async throws {
        try await deleteRecord(collection: "app.bsky.feed.like", recordUri: likeUri)
    }

    func repost(uri: String, cid: String) async throws -> String {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }
        let record: [String: Any] = [
            "$type": "app.bsky.feed.repost",
            "subject": ["uri": uri, "cid": cid],
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let result: CreateRecordResponse = try await createRecord(
            pds: pds, did: did, collection: "app.bsky.feed.repost", record: record
        )
        return result.uri
    }

    func unrepost(repostUri: String) async throws {
        try await deleteRecord(collection: "app.bsky.feed.repost", recordUri: repostUri)
    }

    func replyToPost(text: String, parentUri: String, parentCid: String) async throws {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }
        let record: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "reply": [
                "root": ["uri": parentUri, "cid": parentCid],
                "parent": ["uri": parentUri, "cid": parentCid],
            ] as [String: Any],
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let _: CreateRecordResponse = try await createRecord(
            pds: pds, did: did, collection: "app.bsky.feed.post", record: record
        )
    }

    func quotePost(text: String, quotedUri: String, quotedCid: String) async throws {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }
        let record: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "embed": [
                "$type": "app.bsky.embed.record",
                "record": [
                    "uri": quotedUri,
                    "cid": quotedCid,
                ] as [String: Any],
            ] as [String: Any],
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let _: CreateRecordResponse = try await createRecord(
            pds: pds, did: did, collection: "app.bsky.feed.post", record: record
        )
    }

    // MARK: - Post Thread

    func getPostThread(uri: String) async throws -> PostThreadResponse {
        let publicAPI = "https://api.bsky.app"
        let encoded = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri
        let urlString = "\(publicAPI)/xrpc/app.bsky.feed.getPostThread?uri=\(encoded)&depth=10"

        let (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)

        return try JSONDecoder().decode(PostThreadResponse.self, from: data)
    }

    // MARK: - Follow / Unfollow

    func follow(did: String) async throws {
        guard let pds = pdsURL, let myDID = self.did else { throw ATProtoError.notLoggedIn }
        let record: [String: Any] = [
            "$type": "app.bsky.graph.follow",
            "subject": did,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let _: CreateRecordResponse = try await createRecord(
            pds: pds, did: myDID, collection: "app.bsky.graph.follow", record: record
        )
    }

    func unfollow(followUri: String) async throws {
        try await deleteRecord(collection: "app.bsky.graph.follow", recordUri: followUri)
    }

    // MARK: - XRPC Helpers

    private func createRecord<T: Decodable>(
        pds: String, did: String, collection: String, record: [String: Any], rkey: String? = nil
    ) async throws -> T {
        let url = "\(pds)/xrpc/com.atproto.repo.createRecord"
        var body: [String: Any] = ["repo": did, "collection": collection, "record": record]
        if let rkey { body["rkey"] = rkey }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await authenticatedRequest(url: url, method: "POST", body: bodyData)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Generate an AT Protocol TID (timestamp-based record key).
    private func generateTID() -> String {
        let base32 = Array("234567abcdefghijklmnopqrstuvwxyz")
        let now = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let clockId = UInt64.random(in: 0..<1024)
        let tid = (now << 10) | clockId
        var chars = [Character]()
        var remaining = tid
        for _ in 0..<13 {
            chars.insert(base32[Int(remaining & 0x1F)], at: 0)
            remaining >>= 5
        }
        return String(chars)
    }

    private func deleteRecord(collection: String, recordUri: String) async throws {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }
        let rkey = recordUri.components(separatedBy: "/").last ?? ""
        let url = "\(pds)/xrpc/com.atproto.repo.deleteRecord"
        let body: [String: Any] = ["repo": did, "collection": collection, "rkey": rkey]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _ = try await authenticatedRequest(url: url, method: "POST", body: bodyData)
    }

    /// Delete a post by URI.
    func deletePost(uri: String) async throws {
        try await deleteRecord(collection: "app.bsky.feed.post", recordUri: uri)
    }

    /// Upload an image blob to the PDS. Returns the blob JSON for use in profile updates.
    func uploadBlob(imageData: Data, mimeType: String) async throws -> [String: Any] {
        guard let pds = pdsURL, let token = accessToken else { throw ATProtoError.notLoggedIn }
        let url = "\(pds)/xrpc/com.atproto.repo.uploadBlob"

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("DPoP \(token)", forHTTPHeaderField: "Authorization")
        if let dpopHeader = try createDPoPProof(method: "POST", url: url, accessToken: token) {
            request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
        }
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)

        // Handle DPoP nonce
        if let httpResponse = response as? HTTPURLResponse,
           let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
            dpopNonce = nonce

            if httpResponse.statusCode == 401 {
                // Retry with nonce
                var retryReq = URLRequest(url: URL(string: url)!)
                retryReq.httpMethod = "POST"
                retryReq.setValue(mimeType, forHTTPHeaderField: "Content-Type")
                retryReq.setValue("DPoP \(token)", forHTTPHeaderField: "Authorization")
                if let dpopHeader = try createDPoPProof(method: "POST", url: url, accessToken: token) {
                    retryReq.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
                }
                retryReq.httpBody = imageData
                let (retryData, _) = try await URLSession.shared.data(for: retryReq)
                let blob = try JSONSerialization.jsonObject(with: retryData) as? [String: Any]
                return blob?["blob"] as? [String: Any] ?? [:]
            }
        }

        let blob = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return blob?["blob"] as? [String: Any] ?? [:]
    }

    /// Update the user's profile (display name, bio, avatar, banner).
    func updateProfile(displayName: String? = nil, description: String? = nil,
                       avatar: [String: Any]? = nil, banner: [String: Any]? = nil) async throws {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }

        // Get current profile record
        let getURL = "\(pds)/xrpc/com.atproto.repo.getRecord?repo=\(did)&collection=app.bsky.actor.profile&rkey=self"
        let (getData, _) = try await authenticatedRequest(url: getURL, method: "GET")
        let existing = try JSONSerialization.jsonObject(with: getData) as? [String: Any] ?? [:]
        var record = existing["value"] as? [String: Any] ?? ["$type": "app.bsky.actor.profile"]

        // Merge changes
        if let displayName { record["displayName"] = displayName }
        if let description { record["description"] = description }
        if let avatar { record["avatar"] = avatar }
        if let banner { record["banner"] = banner }

        // Put updated record
        let putURL = "\(pds)/xrpc/com.atproto.repo.putRecord"
        let body: [String: Any] = [
            "repo": did,
            "collection": "app.bsky.actor.profile",
            "rkey": "self",
            "record": record,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _ = try await authenticatedRequest(url: putURL, method: "POST", body: bodyData)
    }

    /// Refresh the access token using the stored refresh token.
    /// The refresh request is DPoP-bound with the same key pair used during initial token exchange.
    private func refreshAccessToken() async throws {
        guard let rt = refreshToken, let tokenEndpoint = tokenEndpointURL ?? resolveTokenEndpoint() else {
            print("[Auth] Refresh failed: no refresh token or token endpoint")
            throw ATProtoError.notLoggedIn
        }

        print("[Auth] Attempting token refresh at \(tokenEndpoint)")

        let clientId = "https://www.speakwrite.io/app/client-metadata.json"
        let bodyDict: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": rt,
            "client_id": clientId,
        ]
        let bodyData = try JSONEncoder().encode(bodyDict)

        func buildRefreshRequest() throws -> URLRequest {
            var request = URLRequest(url: URL(string: tokenEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let dpopHeader = try createDPoPProof(method: "POST", url: tokenEndpoint) {
                request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
            }
            request.httpBody = bodyData
            return request
        }

        let request = try buildRefreshRequest()
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
                dpopNonce = nonce
            }

            print("[Auth] Refresh response: \(httpResponse.statusCode)")

            // Retry with nonce if 400 or 401 (DPoP nonce challenge)
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                let retryRequest = try buildRefreshRequest()
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                if let retryHttp = retryResponse as? HTTPURLResponse {
                    if let retryNonce = retryHttp.value(forHTTPHeaderField: "DPoP-Nonce") {
                        dpopNonce = retryNonce
                    }
                    print("[Auth] Refresh retry response: \(retryHttp.statusCode)")
                    if retryHttp.statusCode >= 200 && retryHttp.statusCode < 300 {
                        let tokens = try JSONDecoder().decode(TokenResponse.self, from: retryData)
                        accessToken = tokens.accessToken
                        if let newRT = tokens.refreshToken { refreshToken = newRT }
                        persistSession()
                        print("[Auth] Token refreshed successfully (after nonce retry)")
                        return
                    }
                    let errorBody = String(data: retryData, encoding: .utf8) ?? ""
                    print("[Auth] Refresh retry failed: \(errorBody)")
                    throw ATProtoError.oauthError("refresh_failed_\(retryHttp.statusCode)", errorBody)
                }
                // Fallback: try to decode anyway
                let tokens = try JSONDecoder().decode(TokenResponse.self, from: retryData)
                accessToken = tokens.accessToken
                if let newRT = tokens.refreshToken { refreshToken = newRT }
                persistSession()
                return
            }

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
                accessToken = tokens.accessToken
                if let newRT = tokens.refreshToken { refreshToken = newRT }
                persistSession()
                print("[Auth] Token refreshed successfully")
                return
            }

            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("[Auth] Refresh failed: \(errorBody)")
            throw ATProtoError.oauthError("refresh_failed_\(httpResponse.statusCode)", errorBody)
        }

        // Non-HTTP response (shouldn't happen)
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokens.accessToken
        if let newRT = tokens.refreshToken { refreshToken = newRT }
        persistSession()
    }

    /// Try to discover the token endpoint from the PDS if not already stored.
    private func resolveTokenEndpoint() -> String? {
        // Synchronous check — for restored sessions that didn't persist the token endpoint.
        // The caller can fall back to re-login if this returns nil.
        guard pdsURL != nil else { return nil }
        // We can't do async from here, so return nil and let the refresh fail gracefully.
        // The user will need to re-login (one-time migration).
        return nil
    }

    /// Async version: discover token endpoint from PDS metadata.
    private func discoverTokenEndpoint() async throws -> String? {
        guard let pds = pdsURL else { return nil }
        let authServer = try await discoverAuthorizationServer(pds: pds)
        let metadataURL = URL(string: "\(authServer)/.well-known/oauth-authorization-server")!
        let (metaData, _) = try await URLSession.shared.data(from: metadataURL)
        let metadata = try JSONDecoder().decode(OAuthServerMetadata.self, from: metaData)
        tokenEndpointURL = metadata.tokenEndpoint
        UserDefaults.standard.set(metadata.tokenEndpoint, forKey: "sw_token_endpoint")
        return metadata.tokenEndpoint
    }

    private func authenticatedRequest(url: String, method: String, body: Data? = nil) async throws -> (Data, URLResponse) {
        guard accessToken != nil else { throw ATProtoError.notLoggedIn }

        func buildRequest() throws -> URLRequest {
            guard let token = accessToken else { throw ATProtoError.notLoggedIn }
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = method
            request.setValue("DPoP \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let dpopHeader = try createDPoPProof(method: method, url: url, accessToken: token) {
                request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
            }

            if let body { request.httpBody = body }
            return request
        }

        func captureNonce(from httpResponse: HTTPURLResponse) {
            if let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
                dpopNonce = nonce
            }
        }

        let request = try buildRequest()
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return (data, response)
        }

        captureNonce(from: httpResponse)

        // Handle 401 — could be DPoP nonce challenge OR expired token
        if httpResponse.statusCode == 401 {
            // Check if this is a token expiry error vs. a nonce issue
            let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorJSON?["message"] as? String ?? ""
            let isTokenExpired = errorMessage.contains("exp") || errorMessage.contains("invalid_token") || errorMessage.contains("expired")

            if !isTokenExpired {
                print("[Auth] Got 401 for \(url), attempting nonce retry")
                // First retry: might just need the fresh DPoP nonce
                let retryRequest = try buildRequest()
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                if let retryHttp = retryResponse as? HTTPURLResponse {
                    captureNonce(from: retryHttp)
                    if retryHttp.statusCode >= 200 && retryHttp.statusCode < 300 {
                        print("[Auth] Nonce retry succeeded")
                        return (retryData, retryResponse)
                    }
                }
            } else {
                print("[Auth] Got 401 for \(url) — token expired, skipping nonce retry")
            }

            // Token expired or nonce retry failed — try refreshing the access token
            if refreshToken != nil {
                // Discover token endpoint if we don't have it (migration for existing sessions)
                if tokenEndpointURL == nil {
                    print("[Auth] No token endpoint cached, discovering...")
                    tokenEndpointURL = try? await discoverTokenEndpoint()
                    print("[Auth] Discovered token endpoint: \(tokenEndpointURL ?? "nil")")
                }

                do {
                    try await refreshAccessToken()
                    // Retry with the fresh token
                    let freshRequest = try buildRequest()
                    let (freshData, freshResponse) = try await URLSession.shared.data(for: freshRequest)
                    if let freshHttp = freshResponse as? HTTPURLResponse {
                        captureNonce(from: freshHttp)
                        if freshHttp.statusCode >= 200 && freshHttp.statusCode < 300 {
                            print("[Auth] Request succeeded after token refresh")
                            return (freshData, freshResponse)
                        }
                        // If we get another nonce challenge after refresh, retry once more
                        if freshHttp.statusCode == 401 {
                            print("[Auth] Got 401 after refresh, trying one more time with fresh nonce")
                            let finalRequest = try buildRequest()
                            let (finalData, finalResponse) = try await URLSession.shared.data(for: finalRequest)
                            if let finalHttp = finalResponse as? HTTPURLResponse {
                                captureNonce(from: finalHttp)
                                if finalHttp.statusCode >= 200 && finalHttp.statusCode < 300 {
                                    print("[Auth] Final retry after refresh succeeded")
                                    return (finalData, finalResponse)
                                }
                                let errorBody = String(data: finalData, encoding: .utf8) ?? "HTTP \(finalHttp.statusCode)"
                                print("[Auth] Final retry failed: \(finalHttp.statusCode) \(errorBody)")
                                throw ATProtoError.oauthError("http_\(finalHttp.statusCode)", errorBody)
                            }
                            return (finalData, finalResponse)
                        }
                        let errorBody = String(data: freshData, encoding: .utf8) ?? "HTTP \(freshHttp.statusCode)"
                        print("[Auth] Request failed even after refresh: \(freshHttp.statusCode) \(errorBody)")
                        throw ATProtoError.oauthError("http_\(freshHttp.statusCode)", errorBody)
                    }
                    return (freshData, freshResponse)
                } catch {
                    print("[Auth] Token refresh error: \(error)")
                    throw error
                }
            }

            // No refresh token — throw the error
            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("[Auth] No refresh token available, failing with 401")
            throw ATProtoError.oauthError("http_\(httpResponse.statusCode)", errorBody)
        }

        // Throw on non-2xx responses
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw ATProtoError.oauthError("http_\(httpResponse.statusCode)", errorBody)
        }

        return (data, response)
    }

    // MARK: - Text Helpers

    /// Strip speakwrite footer from post text for clean display.
    static func stripSpeakwriteFooter(_ text: String) -> String {
        // Current footer: "✓ Verify a human wrote this · Try Speakwrite"
        if let range = text.range(of: "\n\n✓ Verify a human wrote this", options: .backwards) {
            return String(text[..<range.lowerBound])
        }
        // Legacy footer formats (old app versions)
        if let range = text.range(of: "\n\n✓ speakwrite", options: .backwards) {
            return String(text[..<range.lowerBound])
        }
        if let range = text.range(of: "\n\n❤️‍🔥 human verified · speakwrite", options: .backwards) {
            return String(text[..<range.lowerBound])
        }
        return text
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func computeCodeChallenge(_ verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - DPoP

    private func createDPoPProof(method: String, url: String, accessToken: String? = nil) throws -> String? {
        guard let key = dpopKeyPair else { return nil }

        let header: [String: Any] = [
            "typ": "dpop+jwt", "alg": "ES256",
            "jwk": [
                "kty": "EC", "crv": "P-256",
                "x": key.publicKey.rawRepresentation.prefix(32).base64URLEncoded,
                "y": key.publicKey.rawRepresentation.suffix(32).base64URLEncoded,
            ] as [String: Any],
        ]

        let now = Int(Date().timeIntervalSince1970)
        var payload: [String: Any] = [
            "jti": UUID().uuidString, "htm": method,
            "htu": url, "iat": now, "exp": now + 120,
        ]
        if let nonce = dpopNonce { payload["nonce"] = nonce }
        // Include access token hash when presenting a DPoP-bound token (RFC 9449 §4.2)
        if let token = accessToken {
            let tokenHash = SHA256.hash(data: Data(token.utf8))
            payload["ath"] = Data(tokenHash).base64URLEncoded
        }

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let headerB64 = headerData.base64URLEncoded
        let payloadB64 = payloadData.base64URLEncoded

        let signingInput = Data("\(headerB64).\(payloadB64)".utf8)
        let signature = try key.signature(for: signingInput)

        return "\(headerB64).\(payloadB64).\(signature.rawRepresentation.base64URLEncoded)"
    }

    // MARK: - Logout

    func logout() {
        UserDefaults.standard.removeObject(forKey: "sw_handle")
        UserDefaults.standard.removeObject(forKey: "sw_did")
        UserDefaults.standard.removeObject(forKey: "sw_pds")
        UserDefaults.standard.removeObject(forKey: "sw_token_endpoint")
        KeychainHelper.delete(key: "sw_access_token")
        KeychainHelper.delete(key: "sw_refresh_token")
        KeychainHelper.delete(key: "sw_dpop_key")

        accessToken = nil
        refreshToken = nil
        pdsURL = nil
        tokenEndpointURL = nil
        dpopKeyPair = nil
        dpopNonce = nil
        handle = nil
        did = nil
        isLoggedIn = false
    }
}

// MARK: - Private Response Types

struct ResolveHandleResponse: Decodable { let did: String }
private struct DIDDocument: Decodable { let service: [DIDService]? }
private struct DIDService: Decodable { let type: String; let serviceEndpoint: String }

private struct OAuthProtectedResource: Decodable {
    let authorizationServers: [String]
    enum CodingKeys: String, CodingKey {
        case authorizationServers = "authorization_servers"
    }
}

private struct OAuthServerMetadata: Decodable {
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let pushedAuthorizationRequestEndpoint: String?
    let requirePushedAuthorizationRequests: Bool?
    enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case requirePushedAuthorizationRequests = "require_pushed_authorization_requests"
    }
}

private struct PARResponse: Decodable {
    let requestUri: String
    let expiresIn: Int?
    enum CodingKeys: String, CodingKey {
        case requestUri = "request_uri"
        case expiresIn = "expires_in"
    }
}

private struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct CreateRecordResponse: Decodable { let uri: String; let cid: String }

private struct SearchPostsResponse: Decodable {
    let posts: [SearchPost]
    let cursor: String?
}

private struct SearchPost: Decodable {
    let uri: String; let cid: String; let author: PostAuthor
    let record: PostRecord
    let likeCount: Int?; let repostCount: Int?; let replyCount: Int?
    let viewer: PostViewer?
}

private struct PostRecord: Decodable {
    let text: String
    let createdAt: String?
    let tags: [String]?

    var safeCreatedAt: String { createdAt ?? "" }

    /// Whether this post is a genuine Speakwrite post (has tag or old-format footer).
    var isSpeakwrite: Bool {
        tags?.contains("speakwrite") == true ||
        text.contains("#speakwrite") ||
        (text.contains("human verified") && text.contains("speakwrite"))
    }

    /// Post text with speakwrite footer stripped for display.
    var displayText: String {
        // Current footer
        if let range = text.range(of: "\n\n✓ Verify a human wrote this", options: .backwards) {
            return String(text[..<range.lowerBound])
        }
        // Legacy footer formats (old app versions)
        if let range = text.range(of: "\n\n✓ speakwrite", options: .backwards) {
            return String(text[..<range.lowerBound])
        }
        if let range = text.range(of: "\n\n❤️‍🔥 human verified · speakwrite", options: .backwards) {
            return String(text[..<range.lowerBound])
        }
        return text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Default to empty string if text is missing (defensive against bad API data)
        text = (try? container.decode(String.self, forKey: .text)) ?? ""
        createdAt = try? container.decode(String.self, forKey: .createdAt)
        tags = try? container.decode([String].self, forKey: .tags)
    }

    enum CodingKeys: String, CodingKey { case text, createdAt, tags }
}

// MARK: - Public Response Types

struct PostAuthor: Codable {
    let did: String; let handle: String; let displayName: String?
    let avatar: String?; let viewer: AuthorViewer?
}

struct AuthorViewer: Codable {
    let following: String?; let followedBy: String?; let muted: Bool?; let blockedBy: Bool?
}

struct PostViewer: Codable {
    let like: String?; let repost: String?
}

struct FeedResponse: Decodable { let feed: [FeedItem]; let cursor: String? }
struct FeedItem: Decodable {
    let post: FeedPost
    let reason: FeedReason?
}
struct FeedReason: Decodable {
    let type: String?
    let by: PostAuthor?
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case by
    }
}
struct FeedPost: Decodable {
    let uri: String; let cid: String; let author: PostAuthor
    let record: FeedPostRecord?
    let likeCount: Int?; let repostCount: Int?; let replyCount: Int?
    let viewer: PostViewer?
}
struct FeedPostRecord: Decodable { let text: String?; let createdAt: String?; let tags: [String]? }

struct VerifiedPost: Identifiable {
    let uri: String; let cid: String; let author: PostAuthor
    let text: String; let createdAt: String
    let likeCount: Int; let repostCount: Int; let replyCount: Int
    let viewer: PostViewer?
    var id: String { uri }
}

struct TimelinePost: Identifiable {
    let uri: String; let cid: String; let author: PostAuthor
    let text: String; let createdAt: String
    let likeCount: Int; let repostCount: Int; let replyCount: Int
    let isVerified: Bool; let viewer: PostViewer?
    let repostedBy: String? // Display name or handle of the reposter
    var id: String { uri }
}

struct ProfileViewDetailed: Codable {
    let did: String; let handle: String; let displayName: String?
    let description: String?; let avatar: String?; let banner: String?
    let followersCount: Int?; let followsCount: Int?; let postsCount: Int?
    let viewer: ProfileViewer?
}

struct ProfileViewer: Codable {
    let following: String?; let followedBy: String?; let muted: Bool?; let blockedBy: Bool?
}

// MARK: - Thread Types

struct PostThreadResponse: Decodable {
    let thread: ThreadNode
}

final class ThreadNode: Decodable {
    let post: FeedPost?
    let replies: [ThreadNode]?
    let parent: ThreadNode?

    enum CodingKeys: String, CodingKey {
        case post, replies, parent
        case type = "$type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        if type == "app.bsky.feed.defs#threadViewPost" {
            post = try container.decodeIfPresent(FeedPost.self, forKey: .post)
            replies = try container.decodeIfPresent([ThreadNode].self, forKey: .replies)
            parent = try container.decodeIfPresent(ThreadNode.self, forKey: .parent)
        } else {
            post = nil; replies = nil; parent = nil
        }
    }
}

/// Navigation value for post detail — wraps URI+CID to distinguish from profile navigation (String DID).
struct PostNavigation: Hashable {
    let uri: String
    let cid: String
    let authorHandle: String
    let authorDID: String
    let authorAvatar: String?
    let authorDisplayName: String?
    let text: String
    let createdAt: String
    let likeCount: Int
    let repostCount: Int
    let replyCount: Int
    let viewerLike: String?
    let viewerRepost: String?
    let isVerified: Bool
}

// MARK: - ASWebAuthenticationSession presentation

private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}

// MARK: - Errors

enum ATProtoError: Error, LocalizedError {
    case noPDS, authCancelled, noAuthCode, notLoggedIn
    case oauthError(String, String?) // error code, description
    var errorDescription: String? {
        switch self {
        case .noPDS: return "Could not find PDS for this handle"
        case .authCancelled: return "Authentication was cancelled"
        case .noAuthCode: return "No authorization code received"
        case .notLoggedIn: return "Not logged in"
        case .oauthError(let code, let desc): return "OAuth error (\(code)): \(desc ?? "unknown")"
        }
    }
}

struct ProfileViewBasic: Codable, Identifiable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    var id: String { did }
}

struct SearchActorsResponse: Decodable {
    let actors: [ProfileViewBasic]
}

struct SearchActorsTypeaheadResponse: Decodable {
    let actors: [ProfileViewBasic]
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
