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
//
// Design language: "Signed ink."
// The product proves a human wrote something, so the visual language pairs
// editorial warmth (serif post text on paper/ink surfaces) with cryptographic
// precision (monospace reserved for proofs, hashes, and the seal).
//
// Rules:
// - Post text is serif. It's the human artifact.
// - UI chrome is the system sans, always via Dynamic Type text styles.
// - Monospace appears only on proof/crypto elements (hashes, seal details,
//   keystroke counter) — never for general chrome.
// - One accent: the seal green. Deep emerald in light mode (readable as text
//   on paper), mint in dark mode.

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

    // MARK: - Typography (Dynamic Type)
    //
    // Every token maps to a text style so the whole app scales with the
    // user's accessibility settings. Base sizes match the previous fixed
    // sizes at the default content size category.

    /// Screen titles — 20pt base.
    static var title: Font { .system(.title3, design: .default).weight(.bold) }
    /// Row/name emphasis — 17pt base.
    static var headline: Font { .system(.headline) }
    /// General UI text — 15pt base.
    static var body: Font { .system(.subheadline) }
    /// Secondary rows — 13pt base.
    static var subhead: Font { .system(.footnote) }
    /// Metadata — 12pt base.
    static var caption: Font { .system(.caption) }

    /// Post body text — serif, 17pt base. The human artifact.
    static var postBody: Font { .system(.body, design: .serif) }
    /// Large serif for display moments (login tagline, empty states).
    static var display: Font { .system(.title2, design: .serif).weight(.semibold) }

    // Monospace suite — proof/crypto surfaces only.
    static var mono: Font { .system(.footnote, design: .monospaced) }
    static var monoSmall: Font { .system(.caption2, design: .monospaced) }
    static var monoTitle: Font { .system(.title3, design: .monospaced).weight(.bold) }
    static var monoBody: Font { .system(.subheadline, design: .monospaced) }
    static var monoCaption: Font { .system(.caption, design: .monospaced).weight(.medium) }
    static var monoHeadline: Font { .system(.callout, design: .monospaced).weight(.semibold) }
    static var monoBold: Font { .system(.footnote, design: .monospaced).weight(.bold) }
    static var monoStat: Font { .system(.callout, design: .monospaced).weight(.bold) }
}

// MARK: - Adaptive Colors

extension Theme {

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1)
    }

    // Backgrounds — warm paper in light, near-black ink in dark.

    /// App background.
    static let bg = adaptive(light: rgb(250, 249, 246), dark: rgb(10, 10, 12))
    /// Inset surface (cards, fields).
    static let surfaceColor = adaptive(light: rgb(243, 241, 237), dark: rgb(20, 20, 23))
    /// Elevated surface (sheets, menus).
    static let surfaceElevatedColor = adaptive(light: .white, dark: rgb(28, 28, 31))

    // Text

    static let ink = adaptive(light: rgb(26, 25, 23), dark: rgb(242, 241, 238))
    static let inkSecondary = adaptive(light: rgb(110, 106, 99), dark: rgb(156, 154, 148))
    static let inkTertiary = adaptive(light: rgb(165, 161, 153), dark: rgb(96, 94, 88))

    // Accent — the seal green. Deep emerald on paper (≈5.4:1 contrast),
    // mint on ink. Safe to use as text in both modes.
    static let accent = adaptive(light: rgb(18, 122, 68), dark: rgb(52, 208, 124))

    static var accentSubtle: Color { accent.opacity(0.13) }

    /// Fill color for solid accent buttons; label on top should be `onAccent`.
    static let accentFill = adaptive(light: rgb(18, 122, 68), dark: rgb(52, 208, 124))
    static let onAccent = adaptive(light: .white, dark: rgb(10, 10, 12))

    // Hairlines

    static let hairline = adaptive(light: rgb(231, 228, 222), dark: rgb(35, 35, 38))

    // Semantic

    static let error = Color.red
    static let liked = adaptive(light: rgb(214, 31, 105), dark: rgb(236, 72, 137))
    static let reposted = adaptive(light: rgb(18, 122, 68), dark: rgb(52, 208, 124))
    /// Warning (character limit, violations).
    static let warning = adaptive(light: rgb(178, 108, 0), dark: rgb(255, 179, 64))

    // MARK: - Legacy scheme-parameter API
    //
    // Older views pass ColorScheme explicitly. These now delegate to the
    // adaptive palette (which resolves against the environment), so both
    // call styles stay consistent during the migration.

    static func background(_ scheme: ColorScheme) -> Color { bg }
    static func surface(_ scheme: ColorScheme) -> Color { surfaceColor }
    static func surfaceElevated(_ scheme: ColorScheme) -> Color { surfaceElevatedColor }
    static func textPrimary(_ scheme: ColorScheme) -> Color { ink }
    static func textSecondary(_ scheme: ColorScheme) -> Color { inkSecondary }
    static func textTertiary(_ scheme: ColorScheme) -> Color { inkTertiary }
    static func separator(_ scheme: ColorScheme) -> Color { hairline }
    static func avatarBorder(_ scheme: ColorScheme) -> Color { bg }

    // Legacy radius aliases
    static let cornerRadiusSm: CGFloat = 8
    static let cornerRadiusMd: CGFloat = 12
    static let cornerRadiusLg: CGFloat = 16
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
