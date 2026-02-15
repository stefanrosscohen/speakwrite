import SwiftUI
import UIKit

/// Protocol for receiving keystroke events from the capture text view.
protocol KeystrokeCaptureDelegate: AnyObject {
    func didRecordKeystroke(_ event: KeystrokeEvent)
    func textDidChange(_ text: String)
}

/// Lightweight keystroke event (not persisted — converted to Keystroke model for storage).
struct KeystrokeEvent {
    let eventType: String      // "KeyDown", "KeyUp"
    let key: String            // "a", "Enter", "Backspace"
    let code: String           // "KeyA", "Enter", "Backspace"
    let timestampMs: Double    // milliseconds since boot
    let shiftKey: Bool
    let ctrlKey: Bool
    let altKey: Bool
    let metaKey: Bool
    let isRepeat: Bool
    let isComposing: Bool
    let sequenceNumber: Int
}

// MARK: - UITextView subclass with keystroke capture

/// Custom UITextView that captures keystroke timing for behavioral analysis.
/// Handles both software keyboard (insertText/deleteBackward) and hardware keyboard (pressesBegan/pressesEnded).
class CaptureTextView: UITextView {
    weak var captureDelegate: KeystrokeCaptureDelegate?
    private var sequenceCounter = 0
    private var isComposing = false

    private func nowMs() -> Double {
        ProcessInfo.processInfo.systemUptime * 1000
    }

    private func nextSequence() -> Int {
        let seq = sequenceCounter
        sequenceCounter += 1
        return seq
    }

    // MARK: - Software keyboard capture

    override func insertText(_ text: String) {
        // Capture before the insert so we record what key was pressed
        let key: String
        let code: String
        switch text {
        case "\n":
            key = "Enter"
            code = "Enter"
        case "\t":
            key = "Tab"
            code = "Tab"
        default:
            key = text
            code = text.count == 1 ? "Key\(text.uppercased())" : text
        }

        let event = KeystrokeEvent(
            eventType: "KeyDown",
            key: key,
            code: code,
            timestampMs: nowMs(),
            shiftKey: false,
            ctrlKey: false,
            altKey: false,
            metaKey: false,
            isRepeat: false,
            isComposing: isComposing,
            sequenceNumber: nextSequence()
        )
        captureDelegate?.didRecordKeystroke(event)

        // Synthetic KeyUp immediately after (software keyboard doesn't have distinct up events)
        let upEvent = KeystrokeEvent(
            eventType: "KeyUp",
            key: key,
            code: code,
            timestampMs: nowMs() + 1, // 1ms after keydown
            shiftKey: false,
            ctrlKey: false,
            altKey: false,
            metaKey: false,
            isRepeat: false,
            isComposing: isComposing,
            sequenceNumber: nextSequence()
        )
        captureDelegate?.didRecordKeystroke(upEvent)

        super.insertText(text)
        captureDelegate?.textDidChange(self.text)
    }

    override func deleteBackward() {
        let event = KeystrokeEvent(
            eventType: "KeyDown",
            key: "Backspace",
            code: "Backspace",
            timestampMs: nowMs(),
            shiftKey: false,
            ctrlKey: false,
            altKey: false,
            metaKey: false,
            isRepeat: false,
            isComposing: isComposing,
            sequenceNumber: nextSequence()
        )
        captureDelegate?.didRecordKeystroke(event)

        let upEvent = KeystrokeEvent(
            eventType: "KeyUp",
            key: "Backspace",
            code: "Backspace",
            timestampMs: nowMs() + 1,
            shiftKey: false,
            ctrlKey: false,
            altKey: false,
            metaKey: false,
            isRepeat: false,
            isComposing: isComposing,
            sequenceNumber: nextSequence()
        )
        captureDelegate?.didRecordKeystroke(upEvent)

        super.deleteBackward()
        captureDelegate?.textDidChange(self.text)
    }

    // MARK: - Hardware keyboard capture

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let uiKey = press.key else { continue }
            let keystroke = KeystrokeEvent(
                eventType: "KeyDown",
                key: uiKey.characters,
                code: String(describing: uiKey.keyCode.rawValue),
                timestampMs: nowMs(),
                shiftKey: uiKey.modifierFlags.contains(.shift),
                ctrlKey: uiKey.modifierFlags.contains(.control),
                altKey: uiKey.modifierFlags.contains(.alternate),
                metaKey: uiKey.modifierFlags.contains(.command),
                isRepeat: false,
                isComposing: isComposing,
                sequenceNumber: nextSequence()
            )
            captureDelegate?.didRecordKeystroke(keystroke)
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let uiKey = press.key else { continue }
            let keystroke = KeystrokeEvent(
                eventType: "KeyUp",
                key: uiKey.characters,
                code: String(describing: uiKey.keyCode.rawValue),
                timestampMs: nowMs(),
                shiftKey: uiKey.modifierFlags.contains(.shift),
                ctrlKey: uiKey.modifierFlags.contains(.control),
                altKey: uiKey.modifierFlags.contains(.alternate),
                metaKey: uiKey.modifierFlags.contains(.command),
                isRepeat: false,
                isComposing: isComposing,
                sequenceNumber: nextSequence()
            )
            captureDelegate?.didRecordKeystroke(keystroke)
        }
        super.pressesEnded(presses, with: event)
        captureDelegate?.textDidChange(self.text)
    }

    // MARK: - Composition tracking (for IME input)

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        isComposing = true
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }

    override func unmarkText() {
        isComposing = false
        super.unmarkText()
    }

    /// Reset sequence counter (call when starting a new session).
    func resetSequence() {
        sequenceCounter = 0
    }
}

// MARK: - SwiftUI wrapper

struct CaptureTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Start typing..."
    var captureDelegate: KeystrokeCaptureDelegate?

    func makeUIView(context: Context) -> CaptureTextView {
        let textView = CaptureTextView()
        textView.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        textView.textColor = UIColor(named: "textPrimary") ?? .label
        textView.backgroundColor = .clear
        textView.autocorrectionType = .no  // Disable autocorrect for clean keystroke capture
        textView.autocapitalizationType = .sentences
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.captureDelegate = captureDelegate
        textView.delegate = context.coordinator
        textView.text = text
        return textView
    }

    func updateUIView(_ textView: CaptureTextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        textView.captureDelegate = captureDelegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: CaptureTextEditor

        init(_ parent: CaptureTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
