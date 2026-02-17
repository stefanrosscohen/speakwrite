import SwiftUI
import UIKit

/// Protocol for receiving text changes and keystroke counts from the input-restricted text view.
protocol InputRestrictedDelegate: AnyObject {
    func textDidChange(_ text: String)
    func keystrokeCountDidChange(_ count: Int)
    func violationCountDidChange(_ count: Int)
}

// MARK: - UITextView subclass with input restrictions

/// Custom UITextView that enforces soft-keyboard-only input.
/// Blocks paste, dictation, autocorrect, hardware keyboard, and other non-typing input methods.
/// This is the v3 replacement for behavioral analysis — the restriction IS the guarantee.
class InputRestrictedTextView: UITextView {
    weak var inputDelegate: InputRestrictedDelegate?
    private var keystrokeCount = 0
    private var isComposing = false

    /// Number of input restriction violations detected this session.
    private(set) var violationCount = 0

    // MARK: - Block paste, cut, and other non-typing actions

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Block paste, cut, and other clipboard-related actions
        let blockedActions: [Selector] = [
            #selector(UIResponderStandardEditActions.paste(_:)),
            #selector(UIResponderStandardEditActions.cut(_:)),
            NSSelectorFromString("_share:"),       // Share sheet
            NSSelectorFromString("_define:"),      // Look up
            NSSelectorFromString("_translate:"),   // Translate
            NSSelectorFromString("_promptForReplace:"), // Replace...
        ]
        if blockedActions.contains(action) {
            violationCount += 1
            inputDelegate?.violationCountDidChange(violationCount)
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: - Software keyboard input (with dictation blocking)

    override func insertText(_ text: String) {
        // Dictation inserts bulk text in a single call.
        // During IME composition, multi-character insertions are expected.
        // Swift's Character handles emoji correctly — "🇺🇸".count == 1
        if text.count > 1 && !isComposing {
            // Likely dictation or programmatic insertion — block it
            violationCount += 1
            inputDelegate?.violationCountDidChange(violationCount)
            return
        }

        super.insertText(text)
        keystrokeCount += 1
        inputDelegate?.keystrokeCountDidChange(keystrokeCount)
        inputDelegate?.textDidChange(self.text)
    }

    override func deleteBackward() {
        super.deleteBackward()
        keystrokeCount += 1
        inputDelegate?.keystrokeCountDidChange(keystrokeCount)
        inputDelegate?.textDidChange(self.text)
    }

    // MARK: - Block hardware keyboard

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Consume hardware keyboard events without calling super
        violationCount += presses.count
        inputDelegate?.violationCountDidChange(violationCount)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Consume hardware keyboard events without calling super
    }

    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Consume hardware keyboard events without calling super
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Consume hardware keyboard events without calling super
    }

    // MARK: - IME composition tracking (for CJK input)

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        isComposing = true
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }

    override func unmarkText() {
        isComposing = false
        super.unmarkText()
        inputDelegate?.textDidChange(self.text)
    }

    /// Reset counters (call when starting a new session).
    func resetCounters() {
        keystrokeCount = 0
        violationCount = 0
    }
}

// MARK: - SwiftUI wrapper

struct InputRestrictedEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Start typing..."
    var inputDelegate: InputRestrictedDelegate?

    func makeUIView(context: Context) -> InputRestrictedTextView {
        let textView = InputRestrictedTextView()
        textView.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        textView.textColor = UIColor(named: "textPrimary") ?? .label
        textView.backgroundColor = .clear

        // Disable all auto-correction and smart text features
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no

        textView.inputDelegate = inputDelegate
        textView.delegate = context.coordinator
        textView.text = text
        return textView
    }

    func updateUIView(_ textView: InputRestrictedTextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        textView.inputDelegate = inputDelegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: InputRestrictedEditor

        init(_ parent: InputRestrictedEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
