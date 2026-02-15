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
    private var dpopKeyPair: P256.Signing.PrivateKey?
    private var dpopNonce: String? // Server-provided nonce for DPoP

    // MARK: - Session Persistence

    /// Persist auth session to Keychain + UserDefaults so it survives app restarts.
    func persistSession() {
        UserDefaults.standard.set(handle, forKey: "sw_handle")
        UserDefaults.standard.set(did, forKey: "sw_did")
        UserDefaults.standard.set(pdsURL, forKey: "sw_pds")
        if let token = accessToken {
            KeychainHelper.save(key: "sw_access_token", value: token)
        }
        if let token = refreshToken {
            KeychainHelper.save(key: "sw_refresh_token", value: token)
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
        dpopKeyPair = P256.Signing.PrivateKey() // Fresh DPoP key each launch
        isLoggedIn = true
        return true
    }

    // MARK: - OAuth Flow

    func resolveHandle(_ handle: String) async throws -> (did: String, pds: String) {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=\(handle)")!
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

    func signIn(handle: String, presentationAnchor: ASPresentationAnchor) async throws {
        let (resolvedDID, pds) = try await resolveHandle(handle)

        let metadataURL = URL(string: "\(pds)/.well-known/oauth-authorization-server")!
        let (metaData, _) = try await URLSession.shared.data(from: metadataURL)
        let metadata = try JSONDecoder().decode(OAuthServerMetadata.self, from: metaData)

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = computeCodeChallenge(codeVerifier)
        dpopKeyPair = P256.Signing.PrivateKey()

        let state = UUID().uuidString
        let redirectURI = "io.speakwrite.app://oauth/callback"
        let clientId = "https://www.speakwrite.io/app/client-metadata.json"

        var components = URLComponents(string: metadata.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "atproto transition:generic"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        let authURL = components.url!

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "io.speakwrite.app") { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ATProtoError.authCancelled)
                }
            }
            session.presentationContextProvider = PresentationContextProvider(anchor: presentationAnchor)
            session.prefersEphemeralWebBrowserSession = false
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
        self.isLoggedIn = true
        persistSession()
    }

    private func exchangeCodeForTokens(
        code: String, codeVerifier: String, redirectURI: String,
        clientId: String, tokenEndpoint: String, pds: String
    ) async throws {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let dpopHeader = try createDPoPProof(method: "POST", url: tokenEndpoint) {
            request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
        }

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
            dpopNonce = nonce
        }

        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
    }

    // MARK: - Publishing

    func publishProofPost(bundle: ProofBundle, postText: String) async throws -> (uri: String, cid: String) {
        guard let pds = pdsURL, let did = did else { throw ATProtoError.notLoggedIn }

        let footer = "\n\n\u{2705} \(bundle.totalKeystrokeCount) keystrokes \u{00b7} \(bundle.commitments.count) commitments"
        let maxContentLen = 300 - footer.count
        let trimmedContent = postText.count > maxContentLen
            ? String(postText.prefix(maxContentLen - 1)) + "\u{2026}"
            : postText
        let fullText = trimmedContent + footer

        let postRecord: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": fullText,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]

        let postResult: CreateRecordResponse = try await createRecord(
            pds: pds, did: did, collection: "app.bsky.feed.post", record: postRecord
        )

        let bundleJSON = try JSONEncoder().encode(bundle)
        let proofRecord: [String: Any] = [
            "$type": "io.speakwrite.proof",
            "proof": String(data: bundleJSON, encoding: .utf8) ?? "{}",
            "postUri": postResult.uri,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]

        let _: CreateRecordResponse? = try? await createRecord(
            pds: pds, did: did, collection: "io.speakwrite.proof", record: proofRecord
        )

        return (uri: postResult.uri, cid: postResult.cid)
    }

    // MARK: - Feed (Global Verified Posts)

    func fetchVerifiedFeed(cursor: String? = nil) async throws -> (posts: [VerifiedPost], cursor: String?) {
        let publicAPI = "https://public.api.bsky.app"

        var urlString = "\(publicAPI)/xrpc/app.bsky.feed.searchPosts?q=%E2%9C%85%20keystrokes%20%C2%B7%20commitments&limit=25"
        if let cursor { urlString += "&cursor=\(cursor)" }

        let data: Data
        if accessToken != nil {
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

        let result = try JSONDecoder().decode(SearchPostsResponse.self, from: data)

        let posts = result.posts.map { post in
            VerifiedPost(
                uri: post.uri, cid: post.cid, author: post.author,
                text: post.record.text, createdAt: post.record.createdAt,
                likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0, viewer: post.viewer
            )
        }

        return (posts: posts, cursor: result.cursor)
    }

    // MARK: - Timeline (Bluesky Discover Feed)

    func fetchTimeline(cursor: String? = nil) async throws -> (posts: [TimelinePost], cursor: String?) {
        let publicAPI = "https://public.api.bsky.app"

        let feedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
        let encodedFeed = feedURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? feedURI

        var urlString = "\(publicAPI)/xrpc/app.bsky.feed.getFeed?feed=\(encodedFeed)&limit=30"
        if let cursor { urlString += "&cursor=\(cursor)" }

        let data: Data
        if accessToken != nil {
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

        let result = try JSONDecoder().decode(FeedResponse.self, from: data)

        let posts = result.feed.compactMap { item -> TimelinePost? in
            let post = item.post
            guard let text = post.record?.text else { return nil }
            let isVerified = text.contains("\u{2705}") && text.contains("keystrokes") && text.contains("commitments")

            return TimelinePost(
                uri: post.uri, cid: post.cid, author: post.author,
                text: text, createdAt: post.record?.createdAt ?? "",
                likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0, isVerified: isVerified,
                viewer: post.viewer
            )
        }

        return (posts: posts, cursor: result.cursor)
    }

    // MARK: - Profile

    func getProfile(actor: String) async throws -> ProfileViewDetailed {
        let publicAPI = "https://public.api.bsky.app"
        let encoded = actor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? actor
        let urlString = "\(publicAPI)/xrpc/app.bsky.actor.getProfile?actor=\(encoded)"

        let data: Data
        if accessToken != nil {
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

        return try JSONDecoder().decode(ProfileViewDetailed.self, from: data)
    }

    func getAuthorFeed(actor: String, cursor: String? = nil) async throws -> (posts: [TimelinePost], cursor: String?) {
        let publicAPI = "https://public.api.bsky.app"
        let encoded = actor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? actor

        var urlString = "\(publicAPI)/xrpc/app.bsky.feed.getAuthorFeed?actor=\(encoded)&limit=30"
        if let cursor { urlString += "&cursor=\(cursor)" }

        let data: Data
        if accessToken != nil {
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

        let result = try JSONDecoder().decode(FeedResponse.self, from: data)

        let posts = result.feed.compactMap { item -> TimelinePost? in
            let post = item.post
            guard let text = post.record?.text else { return nil }
            let isVerified = text.contains("\u{2705}") && text.contains("keystrokes") && text.contains("commitments")

            return TimelinePost(
                uri: post.uri, cid: post.cid, author: post.author,
                text: text, createdAt: post.record?.createdAt ?? "",
                likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                replyCount: post.replyCount ?? 0, isVerified: isVerified,
                viewer: post.viewer
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
        let publicAPI = "https://public.api.bsky.app"
        let encoded = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri
        let urlString = "\(publicAPI)/xrpc/app.bsky.feed.getPostThread?uri=\(encoded)&depth=10"

        let data: Data
        if accessToken != nil {
            (data, _) = try await authenticatedRequest(url: urlString, method: "GET")
        } else {
            (data, _) = try await URLSession.shared.data(from: URL(string: urlString)!)
        }

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
        pds: String, did: String, collection: String, record: [String: Any]
    ) async throws -> T {
        let url = "\(pds)/xrpc/com.atproto.repo.createRecord"
        let body: [String: Any] = ["repo": did, "collection": collection, "record": record]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await authenticatedRequest(url: url, method: "POST", body: bodyData)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func deleteRecord(collection: String, recordUri: String) async throws {
        guard let pds = pdsURL, let did = self.did else { throw ATProtoError.notLoggedIn }
        let rkey = recordUri.components(separatedBy: "/").last ?? ""
        let url = "\(pds)/xrpc/com.atproto.repo.deleteRecord"
        let body: [String: Any] = ["repo": did, "collection": collection, "rkey": rkey]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _ = try await authenticatedRequest(url: url, method: "POST", body: bodyData)
    }

    private func authenticatedRequest(url: String, method: String, body: Data? = nil) async throws -> (Data, URLResponse) {
        guard let accessToken else { throw ATProtoError.notLoggedIn }

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let dpopHeader = try createDPoPProof(method: method, url: url) {
            request.setValue(dpopHeader, forHTTPHeaderField: "DPoP")
        }

        if let body { request.httpBody = body }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           let nonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce") {
            dpopNonce = nonce
        }

        return (data, response)
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

    private func createDPoPProof(method: String, url: String) throws -> String? {
        guard let key = dpopKeyPair else { return nil }

        let header: [String: Any] = [
            "typ": "dpop+jwt", "alg": "ES256",
            "jwk": [
                "kty": "EC", "crv": "P-256",
                "x": key.publicKey.rawRepresentation.prefix(32).base64URLEncoded,
                "y": key.publicKey.rawRepresentation.suffix(32).base64URLEncoded,
            ] as [String: Any],
        ]

        var payload: [String: Any] = [
            "jti": UUID().uuidString, "htm": method,
            "htu": url, "iat": Int(Date().timeIntervalSince1970),
        ]
        if let nonce = dpopNonce { payload["nonce"] = nonce }

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
        KeychainHelper.delete(key: "sw_access_token")
        KeychainHelper.delete(key: "sw_refresh_token")

        accessToken = nil
        refreshToken = nil
        pdsURL = nil
        dpopKeyPair = nil
        dpopNonce = nil
        handle = nil
        did = nil
        isLoggedIn = false
    }
}

// MARK: - Private Response Types

private struct ResolveHandleResponse: Decodable { let did: String }
private struct DIDDocument: Decodable { let service: [DIDService]? }
private struct DIDService: Decodable { let type: String; let serviceEndpoint: String }

private struct OAuthServerMetadata: Decodable {
    let authorizationEndpoint: String
    let tokenEndpoint: String
    enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
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

private struct PostRecord: Decodable { let text: String; let createdAt: String }

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
struct FeedItem: Decodable { let post: FeedPost }
struct FeedPost: Decodable {
    let uri: String; let cid: String; let author: PostAuthor
    let record: FeedPostRecord?
    let likeCount: Int?; let repostCount: Int?; let replyCount: Int?
    let viewer: PostViewer?
}
struct FeedPostRecord: Decodable { let text: String?; let createdAt: String? }

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
    var errorDescription: String? {
        switch self {
        case .noPDS: return "Could not find PDS for this handle"
        case .authCancelled: return "Authentication was cancelled"
        case .noAuthCode: return "No authorization code received"
        case .notLoggedIn: return "Not logged in"
        }
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
