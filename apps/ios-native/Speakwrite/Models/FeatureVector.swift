import Foundation
import SwiftData

@Model
final class FeatureVector {
    var session: Session?
    var tier1JSON: String
    var tier2JSON: String
    var createdAt: Date

    init(session: Session? = nil, tier1JSON: String, tier2JSON: String) {
        self.session = session
        self.tier1JSON = tier1JSON
        self.tier2JSON = tier2JSON
        self.createdAt = Date()
    }
}
