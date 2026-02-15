import SwiftUI

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

    static var title: Font { .system(size: 20, weight: .bold) }
    static var headline: Font { .system(size: 17, weight: .semibold) }
    static var body: Font { .system(size: 15) }
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

// MARK: - Semantic Colors

extension Theme {

    // Backgrounds
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.04, green: 0.04, blue: 0.04) : Color(red: 0.98, green: 0.98, blue: 0.98)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.10) : Color(red: 0.96, green: 0.96, blue: 0.96)
    }

    static func surfaceElevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.13) : .white
    }

    // Text
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.07, green: 0.07, blue: 0.07)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.6) : Color(white: 0.4)
    }

    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.35) : Color(white: 0.65)
    }

    // Accent
    static let accent = Color(red: 0.0, green: 0.85, blue: 0.30)

    static var accentSubtle: Color {
        accent.opacity(0.15)
    }

    // Separator
    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.13) : Color(white: 0.88)
    }

    // Semantic
    static let error = Color.red
    static let liked = Color.pink
    static let reposted = Color.green

    // Border for avatar on profile (matches background)
    static func avatarBorder(_ scheme: ColorScheme) -> Color {
        background(scheme)
    }

    // Corner radii
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
