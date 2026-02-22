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
    weak var restrictionDelegate: InputRestrictedDelegate?
    private var keystrokeCount = 0
    private var isComposing = false

    /// Number of input restriction violations detected this session.
    private(set) var violationCount = 0

    // MARK: - Block paste, cut, and other non-typing actions

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Block paste, cut, and other clipboard-related actions.
        // Don't count violations here — iOS queries available actions proactively
        // (e.g. when building the editing menu), which would cause false positives.
        let blockedActions: [Selector] = [
            #selector(UIResponderStandardEditActions.paste(_:)),
            #selector(UIResponderStandardEditActions.cut(_:)),
            NSSelectorFromString("_share:"),       // Share sheet
            NSSelectorFromString("_define:"),      // Look up
            NSSelectorFromString("_translate:"),   // Translate
            NSSelectorFromString("_promptForReplace:"), // Replace...
        ]
        if blockedActions.contains(action) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    // Count violations only when the user explicitly triggers a blocked action.
    override func paste(_ sender: Any?) {
        violationCount += 1
        restrictionDelegate?.violationCountDidChange(violationCount)
    }

    override func cut(_ sender: Any?) {
        violationCount += 1
        restrictionDelegate?.violationCountDidChange(violationCount)
    }

    // MARK: - Software keyboard input (with dictation blocking)

    override func insertText(_ text: String) {
        // Dictation inserts bulk text in a single call.
        // During IME composition, multi-character insertions are expected.
        // Swift's Character handles emoji correctly — "🇺🇸".count == 1
        if text.count > 1 && !isComposing {
            // Likely dictation or programmatic insertion — block it
            violationCount += 1
            restrictionDelegate?.violationCountDidChange(violationCount)
            return
        }

        super.insertText(text)
        keystrokeCount += 1
        restrictionDelegate?.keystrokeCountDidChange(keystrokeCount)
        restrictionDelegate?.textDidChange(self.text)
    }

    override func deleteBackward() {
        super.deleteBackward()
        keystrokeCount += 1
        restrictionDelegate?.keystrokeCountDidChange(keystrokeCount)
        restrictionDelegate?.textDidChange(self.text)
    }

    // MARK: - Block hardware keyboard

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Only count presses that have a key (actual hardware keyboard)
        // Software keyboard generates UIPress events without a key property
        let hardwareKeys = presses.filter { $0.key != nil }
        guard !hardwareKeys.isEmpty else { return }
        violationCount += hardwareKeys.count
        restrictionDelegate?.violationCountDidChange(violationCount)
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
        restrictionDelegate?.textDidChange(self.text)
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

        textView.restrictionDelegate = inputDelegate
        textView.delegate = context.coordinator
        textView.text = text
        Self.applyMentionHighlighting(textView)
        return textView
    }

    func updateUIView(_ textView: InputRestrictedTextView, context: Context) {
        if textView.text != text {
            textView.text = text
            Self.applyMentionHighlighting(textView)
            // Place cursor at end — programmatic text changes (e.g. mention insertion)
            // should leave the cursor ready for the user to keep typing
            let endPos = (textView.text as NSString).length
            textView.selectedRange = NSRange(location: endPos, length: 0)
        }
        textView.restrictionDelegate = inputDelegate
    }

    /// Applies blue foreground color to @mention handles in the text view.
    static func applyMentionHighlighting(_ textView: UITextView) {
        guard let text = textView.text, !text.isEmpty else { return }

        let defaultColor = UIColor(named: "textPrimary") ?? .label
        let accentColor = UIColor(named: "AccentColor") ?? .systemBlue

        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: textView.font ?? .monospacedSystemFont(ofSize: 17, weight: .regular),
            .foregroundColor: defaultColor
        ])

        let pattern = try? NSRegularExpression(
            pattern: "@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
        )
        if let pattern {
            let matches = pattern.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: accentColor, range: match.range)
            }
        }

        let selectedRange = textView.selectedRange
        textView.attributedText = attributed
        textView.selectedRange = selectedRange
        // Reset typing attributes so new text after a mention is default color
        textView.typingAttributes = [
            .font: textView.font ?? .monospacedSystemFont(ofSize: 17, weight: .regular),
            .foregroundColor: defaultColor
        ]
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
            InputRestrictedEditor.applyMentionHighlighting(textView)
        }
    }
}
