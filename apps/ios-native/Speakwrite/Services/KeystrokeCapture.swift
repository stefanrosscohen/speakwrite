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
    private var lastHardwareKeyPressAt: TimeInterval = 0

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
        // During IME composition, multi-character insertions are expected:
        // committing a CJK candidate calls insertText with the whole composed
        // string. Check markedTextRange directly in addition to the isComposing
        // flag — some IMEs commit while the marked range is still active without
        // a matching unmarkText, and the flag alone can miss (or outlive) the
        // composition, which would block valid input and miscount violations.
        // Swift's Character handles emoji correctly — "🇺🇸".count == 1
        let composing = isComposing || markedTextRange != nil
        if text.count > 1 && !composing {
            // Likely dictation or programmatic insertion — block it
            violationCount += 1
            restrictionDelegate?.violationCountDidChange(violationCount)
            return
        }

        // Hardware keyboards deliver characters through the text-input system
        // as ordinary single-char insertText calls — pressesBegan alone can't
        // stop them. Drop any insertion arriving right after a hardware key
        // press so external keyboards genuinely don't type.
        if ProcessInfo.processInfo.systemUptime - lastHardwareKeyPressAt < 0.15 {
            violationCount += 1
            restrictionDelegate?.violationCountDidChange(violationCount)
            return
        }

        // Dictation streams results through the composition path, so the
        // multi-char check above can't catch it — refuse input while the
        // active input mode is dictation.
        if textInputMode?.primaryLanguage == "dictation" {
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
        // Stamp the press time — insertText uses it to drop the characters
        // these key presses produce (see insertText).
        lastHardwareKeyPressAt = ProcessInfo.processInfo.systemUptime
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
        // Dictation stages interim results as marked text — refuse it so the
        // composition path can't be used as a dictation loophole. Genuine IME
        // keyboards report a language ("ja-JP", "zh-Hans"), dictation reports
        // "dictation".
        if textInputMode?.primaryLanguage == "dictation" {
            violationCount += 1
            restrictionDelegate?.violationCountDidChange(violationCount)
            return
        }
        // nil/empty marked text means composition ended or was cancelled —
        // don't leave the flag stuck on, or dictation could slip through later.
        isComposing = !(markedText?.isEmpty ?? true)
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

    /// Serif body font that tracks Dynamic Type — the compose editor is where
    /// the human writes, so it uses the same editorial voice as post display.
    static var editorFont: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .body)
        if let serifDescriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: serifDescriptor, size: 0)
        }
        return base
    }

    /// The seal green, matching Theme.accent, for mention highlighting.
    static var editorAccentColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 52 / 255.0, green: 208 / 255.0, blue: 124 / 255.0, alpha: 1)
                : UIColor(red: 18 / 255.0, green: 122 / 255.0, blue: 68 / 255.0, alpha: 1)
        }
    }

    func makeUIView(context: Context) -> InputRestrictedTextView {
        let textView = InputRestrictedTextView()
        textView.font = Self.editorFont
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
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

        // Placeholder — previously accepted as a parameter but never rendered,
        // leaving reply/quote composers as a blank void.
        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = Self.editorFont
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .tertiaryLabel
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.isAccessibilityElement = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: textView.textContainerInset.top),
            placeholderLabel.leadingAnchor.constraint(
                equalTo: textView.leadingAnchor,
                constant: textView.textContainerInset.left + textView.textContainer.lineFragmentPadding
            ),
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: textView.widthAnchor, constant: -2 * textView.textContainer.lineFragmentPadding),
        ])
        placeholderLabel.isHidden = !text.isEmpty
        context.coordinator.placeholderLabel = placeholderLabel

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
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        textView.restrictionDelegate = inputDelegate
    }

    /// Applies the accent color to @mention handles in the text view.
    static func applyMentionHighlighting(_ textView: UITextView) {
        guard let text = textView.text, !text.isEmpty else { return }

        let defaultColor = UIColor.label
        let accentColor = editorAccentColor

        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: textView.font ?? editorFont,
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
            .font: textView.font ?? editorFont,
            .foregroundColor: defaultColor
        ]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: InputRestrictedEditor
        weak var placeholderLabel: UILabel?

        init(_ parent: InputRestrictedEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel?.isHidden = !textView.text.isEmpty
            // Rewriting attributedText while IME composition is active
            // (Japanese/Chinese/Korean marked text) discards the provisional
            // text and cancels the composition — skip until it commits.
            // textViewDidChange fires again after the commit (markedTextRange
            // becomes nil), so highlighting is reapplied then.
            guard textView.markedTextRange == nil else { return }
            InputRestrictedEditor.applyMentionHighlighting(textView)
        }
    }
}
