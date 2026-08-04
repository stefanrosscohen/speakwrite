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
// Design language: "Signal"
// - Near-monochrome ink/paper surfaces; true black in dark mode, warm paper in light.
// - One accent: proof green. Brighter in dark mode, deeper in light mode for contrast.
// - Monospace is reserved for evidence — the wordmark, handles, hashes, counters.
//   Everything else reads in the system face.

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

    static var title: Font { .system(size: 20, weight: .bold) }
    static var headline: Font { .system(size: 17, weight: .semibold) }
    static var body: Font { .system(size: 16) }
    static var subhead: Font { .system(size: 13) }
    static var caption: Font { .system(size: 12) }
    static var mono: Font { .system(size: 13, design: .monospaced) }
    static var monoSmall: Font { .system(size: 11, design: .monospaced) }
    static var monoTitle: Font { .system(size: 18, weight: .bold, design: .monospaced) }
    static var monoBody: Font { .system(size: 15, design: .monospaced) }
    static var monoCaption: Font { .system(size: 12, weight: .medium, design: .monospaced) }
    static var monoHeadline: Font { .system(size: 16, weight: .semibold, design: .monospaced) }
    static var monoBold: Font { .system(size: 13, weight: .bold, design: .monospaced) }
    static var monoStat: Font { .system(size: 16, weight: .bold, design: .monospaced) }
}

// MARK: - Dynamic Colors
//
// All colors adapt to the active trait collection, so views don't need to
// thread `colorScheme` through. The `(scheme)`-parameterized functions below
// are compatibility wrappers that return the same dynamic colors.

extension Theme {

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Backgrounds — true black (OLED) in dark, warm paper in light
    static let backgroundColor = dynamic(
        light: UIColor(red: 0.985, green: 0.982, blue: 0.975, alpha: 1),
        dark: UIColor(red: 0.015, green: 0.015, blue: 0.02, alpha: 1)
    )

    static let surfaceColor = dynamic(
        light: UIColor(red: 0.945, green: 0.942, blue: 0.935, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
    )

    static let elevatedColor = dynamic(
        light: .white,
        dark: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    )

    // Text
    static let primaryText = dynamic(
        light: UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.94, blue: 0.93, alpha: 1)
    )

    static let secondaryText = dynamic(
        light: UIColor(white: 0.40, alpha: 1),
        dark: UIColor(white: 0.62, alpha: 1)
    )

    static let tertiaryText = dynamic(
        light: UIColor(white: 0.62, alpha: 1),
        dark: UIColor(white: 0.38, alpha: 1)
    )

    // Accent — proof green. Deep in light mode (readable on paper),
    // bright in dark mode (glows on black).
    static let accent = dynamic(
        light: UIColor(red: 0.0, green: 0.52, blue: 0.26, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.87, blue: 0.42, alpha: 1)
    )

    /// Text/icon color for content sitting on an accent-filled background.
    static let onAccent = dynamic(
        light: .white,
        dark: UIColor(red: 0.015, green: 0.015, blue: 0.02, alpha: 1)
    )

    static var accentSubtle: Color { accent.opacity(0.14) }

    /// The verification color — same hue as accent, named for intent at call sites.
    static var verified: Color { accent }
    static var verifiedSubtle: Color { accentSubtle }

    // Separator
    static let divider = dynamic(
        light: UIColor(white: 0.89, alpha: 1),
        dark: UIColor(white: 0.14, alpha: 1)
    )

    // Semantic
    static let error = Color.red
    static let warning = Color.orange
    static let liked = Color.pink
    static let reposted = Color.green

    // Corner radii (legacy aliases)
    static let cornerRadiusSm: CGFloat = 8
    static let cornerRadiusMd: CGFloat = 12
    static let cornerRadiusLg: CGFloat = 16
}

// MARK: - Compatibility Wrappers (scheme parameter ignored — colors are dynamic)

extension Theme {

    static func background(_ scheme: ColorScheme) -> Color { backgroundColor }
    static func surface(_ scheme: ColorScheme) -> Color { surfaceColor }
    static func surfaceElevated(_ scheme: ColorScheme) -> Color { elevatedColor }
    static func textPrimary(_ scheme: ColorScheme) -> Color { primaryText }
    static func textSecondary(_ scheme: ColorScheme) -> Color { secondaryText }
    static func textTertiary(_ scheme: ColorScheme) -> Color { tertiaryText }
    static func separator(_ scheme: ColorScheme) -> Color { divider }
    static func avatarBorder(_ scheme: ColorScheme) -> Color { backgroundColor }
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
