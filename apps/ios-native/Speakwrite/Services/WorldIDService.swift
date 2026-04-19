import Foundation
import UIKit

// MARK: - WorldID Proof

struct WorldIDProof {
    let nullifierHash: String
    let merkleRoot: String
    let proof: String
    let verificationLevel: String
}

// MARK: - WorldID Verification Status

enum WorldIDStatus: Equatable {
    case notVerified
    case verifying
    case verified(at: String)
    case failed(String)
}

// MARK: - WorldID Service

/// Handles World ID verification via the World App deep-link flow and the
/// speakwrite-bot backend verification endpoint.
@Observable
@MainActor
final class WorldIDService {

    // Override via WORLDID_APP_ID in Info.plist / xcconfig for production.
    private static let appID: String = {
        Bundle.main.infoDictionary?["WORLDID_APP_ID"] as? String ?? "app_staging_speakwrite"
    }()

    private static let action = "verify-speakwrite-user"
    private static let callbackScheme = "io.speakwrite.www"
    private static let callbackHost = "worldid-callback"

    // Filled in at launch; points to the deployed speakwrite-bot.
    private static let botBaseURL: String = {
        Bundle.main.infoDictionary?["SPEAKWRITE_BOT_URL"] as? String
            ?? "https://speakwrite-bot.fly.dev"
    }()

    var status: WorldIDStatus = .notVerified
    var pendingDID: String?

    // MARK: - Start Verification

    /// Opens the World App for verification. The app must be installed.
    /// Call `handleCallback(url:)` from the app's `onOpenURL` handler.
    func startVerification(did: String) {
        guard status != .verifying else { return }

        pendingDID = did
        status = .verifying

        var components = URLComponents()
        components.scheme = "worldapp"
        components.host = "wld"
        components.queryItems = [
            URLQueryItem(name: "t", value: "wld_link"),
            URLQueryItem(name: "app_id", value: Self.appID),
            URLQueryItem(name: "action", value: Self.action),
            URLQueryItem(name: "signal", value: did),
            URLQueryItem(name: "redirect_url", value: "\(Self.callbackScheme)://\(Self.callbackHost)"),
            URLQueryItem(name: "credential_types", value: "orb_credential,device_credential"),
        ]

        guard let url = components.url else {
            status = .failed("Invalid World App URL")
            return
        }

        Task {
            let opened = await UIApplication.shared.open(url)
            if !opened {
                status = .failed("World App is not installed")
            }
        }
    }

    // MARK: - Handle Callback

    /// Returns `true` if the URL was a WorldID callback and was handled.
    @discardableResult
    func handleCallback(url: URL) -> Bool {
        guard url.scheme == Self.callbackScheme, url.host == Self.callbackHost else {
            return false
        }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func param(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard
            let nullifierHash = param("nullifier_hash"),
            let merkleRoot = param("merkle_root"),
            let proof = param("proof")
        else {
            status = .failed("Incomplete proof in callback")
            return true
        }

        let worldProof = WorldIDProof(
            nullifierHash: nullifierHash,
            merkleRoot: merkleRoot,
            proof: proof,
            verificationLevel: param("credential_type") ?? "orb"
        )

        Task { await sendProofToBackend(worldProof) }
        return true
    }

    // MARK: - Send Proof to Backend

    private func sendProofToBackend(_ worldProof: WorldIDProof) async {
        guard let did = pendingDID else {
            status = .failed("No pending DID for verification")
            return
        }

        let urlString = "\(Self.botBaseURL)/api/worldid/verify"
        guard let url = URL(string: urlString) else {
            status = .failed("Invalid bot URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer io.speakwrite.app", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "did": did,
            "nullifier_hash": worldProof.nullifierHash,
            "merkle_root": worldProof.merkleRoot,
            "proof": worldProof.proof,
            "verification_level": worldProof.verificationLevel,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                status = .failed("Invalid server response")
                return
            }

            if http.statusCode == 200 {
                struct SuccessResponse: Decodable { let verifiedAt: String }
                if let result = try? JSONDecoder().decode(SuccessResponse.self, from: data) {
                    status = .verified(at: result.verifiedAt)
                    UserDefaults.standard.set(did, forKey: "worldid_verified_did")
                    UserDefaults.standard.set(result.verifiedAt, forKey: "worldid_verified_at")
                } else {
                    status = .verified(at: ISO8601DateFormatter().string(from: Date()))
                }
            } else {
                struct ErrorResponse: Decodable { let error: String }
                let msg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
                    ?? "Verification failed (\(http.statusCode))"
                status = .failed(msg)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Persist / Restore

    func restoreIfVerified(did: String) {
        let storedDID = UserDefaults.standard.string(forKey: "worldid_verified_did")
        let storedAt = UserDefaults.standard.string(forKey: "worldid_verified_at")
        if storedDID == did, let at = storedAt {
            status = .verified(at: at)
        }
    }

    func checkStatus(did: String) async {
        let urlString = "\(Self.botBaseURL)/api/worldid/status/\(did.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? did)"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct StatusResponse: Decodable { let verified: Bool; let verifiedAt: String? }
            if let result = try? JSONDecoder().decode(StatusResponse.self, from: data), result.verified {
                status = .verified(at: result.verifiedAt ?? "")
                UserDefaults.standard.set(did, forKey: "worldid_verified_did")
                UserDefaults.standard.set(result.verifiedAt, forKey: "worldid_verified_at")
            }
        } catch {
            // Silently ignore — status check is best-effort
        }
    }
}
