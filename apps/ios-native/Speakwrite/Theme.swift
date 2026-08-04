import SwiftUI
import UIKit

// MARK: - Appearance Mode

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case dark = 1
    case light = 2

    var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// MARK: - Theme

enum Theme {

    // MARK: - Spacing

    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32

    // MARK: - Avatar Sizes

    static let avatarSmall: CGFloat = 30
    static let avatarMedium: CGFloat = 42
    static let avatarLarge: CGFloat = 80

    // MARK: - Corner Radius

    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 16

    // MARK: - Typography
    //
    // Sans carries post content; monospaced carries the app's own voice
    // (headers, stats, proof language). All tokens are Dynamic Type aware.

    static var title: Font { .system(.title3, weight: .bold) }
    static var headline: Font { .system(.headline, weight: .semibold) }
    static var body: Font { .system(.subheadline) }
    static var bodyEmphasis: Font { .system(.subheadline, weight: .semibold) }
    static var subhead: Font { .system(.footnote) }
    static var caption: Font { .system(.caption) }

    static var mono: Font { .system(.footnote, design: .monospaced) }
    static var monoSmall: Font { .system(.caption2, design: .monospaced) }
    static var monoTitle: Font { .system(.title3, design: .monospaced, weight: .bold) }
    static var monoBody: Font { .system(.subheadline, design: .monospaced) }
    static var monoCaption: Font { .system(.caption, design: .monospaced, weight: .medium) }
    static var monoHeadline: Font { .system(.callout, design: .monospaced, weight: .semibold) }
    static var monoBold: Font { .system(.footnote, design: .monospaced, weight: .bold) }
    static var monoStat: Font { .system(.callout, design: .monospaced, weight: .bold) }
}

// MARK: - Semantic Colors
//
// All colors are dynamic (trait-collection driven), so views never need to
// read `colorScheme` just to pick a color.

extension Theme {

    private static func dynamic(dark: UIColor, light: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Backgrounds
    static let background = dynamic(
        dark: UIColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1),
        light: UIColor(red: 0.98, green: 0.98, blue: 0.975, alpha: 1)
    )

    static let surface = dynamic(
        dark: UIColor(red: 0.09, green: 0.09, blue: 0.095, alpha: 1),
        light: UIColor(red: 0.955, green: 0.955, blue: 0.95, alpha: 1)
    )

    static let surfaceElevated = dynamic(
        dark: UIColor(red: 0.13, green: 0.13, blue: 0.135, alpha: 1),
        light: .white
    )

    // Text
    static let textPrimary = dynamic(
        dark: .white,
        light: UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
    )

    static let textSecondary = dynamic(
        dark: UIColor(white: 0.64, alpha: 1),
        light: UIColor(white: 0.38, alpha: 1)
    )

    static let textTertiary = dynamic(
        dark: UIColor(white: 0.52, alpha: 1),
        light: UIColor(white: 0.5, alpha: 1)
    )

    // Accent — Speakwrite green. Foreground on accent is always ink.
    static let accent = Color(red: 0.0, green: 0.85, blue: 0.30)
    static let onAccent = Color.black
    static var accentSubtle: Color { accent.opacity(0.15) }

    // Verification states
    static let verified = accent
    static let verifying = dynamic(
        dark: UIColor(white: 0.55, alpha: 1),
        light: UIColor(white: 0.55, alpha: 1)
    )
    static let verificationFailed = Color.orange

    // Separator
    static let separator = dynamic(
        dark: UIColor(white: 0.14, alpha: 1),
        light: UIColor(white: 0.88, alpha: 1)
    )

    // Semantic
    static let error = Color.red
    static let liked = Color.pink

    // UIKit bridges for UITextView-based surfaces
    static let uiTextPrimary = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
    }
    static let uiAccent = UIColor(red: 0.0, green: 0.85, blue: 0.30, alpha: 1)
}

// MARK: - Count Formatting

/// Abbreviates counts the way social clients do: 999, 1.2K, 43K, 1.1M.
func formatCount(_ count: Int) -> String {
    switch count {
    case ..<1000:
        return "\(count)"
    case ..<10_000:
        let value = Double(count) / 1000
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))K"
            : String(format: "%.1fK", rounded)
    case ..<1_000_000:
        return "\(count / 1000)K"
    default:
        let value = Double(count) / 1_000_000
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))M"
            : String(format: "%.1fM", rounded)
    }
}

// MARK: - Relative Time Utility

func relativeTimeString(from isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: isoString) {
        return formatRelativeDate(date)
    }
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: isoString) {
        return formatRelativeDate(date)
    }
    return ""
}

private func formatRelativeDate(_ date: Date) -> String {
    let seconds = Int(-date.timeIntervalSinceNow)
    if seconds < 60 { return "\(max(seconds, 0))s" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 7 { return "\(days)d" }
    let weeks = days / 7
    return "\(weeks)w"
}
