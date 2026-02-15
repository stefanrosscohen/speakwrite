import Foundation
import SwiftData

@Model
final class Keystroke {
    var session: Session?
    var eventType: String    // "KeyDown", "KeyUp"
    var key: String          // "a", "Enter", "Backspace"
    var code: String         // "KeyA", "Enter", "Backspace"
    var timestampMs: Double  // milliseconds
    var shiftKey: Bool
    var ctrlKey: Bool
    var altKey: Bool
    var metaKey: Bool
    var isRepeat: Bool
    var isComposing: Bool
    var sequenceNumber: Int

    init(
        session: Session? = nil,
        eventType: String,
        key: String,
        code: String,
        timestampMs: Double,
        shiftKey: Bool = false,
        ctrlKey: Bool = false,
        altKey: Bool = false,
        metaKey: Bool = false,
        isRepeat: Bool = false,
        isComposing: Bool = false,
        sequenceNumber: Int
    ) {
        self.session = session
        self.eventType = eventType
        self.key = key
        self.code = code
        self.timestampMs = timestampMs
        self.shiftKey = shiftKey
        self.ctrlKey = ctrlKey
        self.altKey = altKey
        self.metaKey = metaKey
        self.isRepeat = isRepeat
        self.isComposing = isComposing
        self.sequenceNumber = sequenceNumber
    }
}
