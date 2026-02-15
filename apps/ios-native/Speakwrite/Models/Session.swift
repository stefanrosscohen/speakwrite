import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: String
    var document: Document?
    var startedAt: Date
    var endedAt: Date?
    var keystrokeCount: Int
    var status: String // "active", "completed"

    @Relationship(deleteRule: .cascade, inverse: \Keystroke.session)
    var keystrokes: [Keystroke] = []

    @Relationship(deleteRule: .cascade, inverse: \FeatureVector.session)
    var featureVectors: [FeatureVector] = []

    init(id: String = UUID().uuidString, document: Document? = nil) {
        self.id = id
        self.document = document
        self.startedAt = Date()
        self.endedAt = nil
        self.keystrokeCount = 0
        self.status = "active"
    }
}
