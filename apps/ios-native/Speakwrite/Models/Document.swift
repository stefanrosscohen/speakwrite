import Foundation
import SwiftData

@Model
final class Document {
    @Attribute(.unique) var id: String
    var title: String
    var contentJSON: String
    var contentHash: String?
    var wordCount: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Session.document)
    var sessions: [Session] = []

    @Relationship(deleteRule: .cascade, inverse: \Commitment.document)
    var commitments: [Commitment] = []

    init(id: String = UUID().uuidString, title: String = "", contentJSON: String = "") {
        self.id = id
        self.title = title
        self.contentJSON = contentJSON
        self.contentHash = nil
        self.wordCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
