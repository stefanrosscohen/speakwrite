import Foundation
import SwiftData

@Model
final class Commitment {
    var document: Document?
    var sequenceNum: Int
    var commitmentHash: String
    var previousHash: String?
    var nonce: String           // hex-encoded
    var timestampMs: Double
    var commitmentType: String  // "behavioral" or "content_binding"
    var contentHash: String?
    var featureJSON: String?
    var documentHash: String?   // SHA-256 hex of document content at checkpoint
    var documentLength: Int
    var keystrokeCountAtCommit: Int

    init(
        document: Document? = nil,
        sequenceNum: Int,
        commitmentHash: String,
        previousHash: String? = nil,
        nonce: String,
        timestampMs: Double,
        commitmentType: String,
        contentHash: String? = nil,
        featureJSON: String? = nil,
        documentHash: String? = nil,
        documentLength: Int = 0,
        keystrokeCountAtCommit: Int = 0
    ) {
        self.document = document
        self.sequenceNum = sequenceNum
        self.commitmentHash = commitmentHash
        self.previousHash = previousHash
        self.nonce = nonce
        self.timestampMs = timestampMs
        self.commitmentType = commitmentType
        self.contentHash = contentHash
        self.featureJSON = featureJSON
        self.documentHash = documentHash
        self.documentLength = documentLength
        self.keystrokeCountAtCommit = keystrokeCountAtCommit
    }
}
