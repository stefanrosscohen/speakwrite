import XCTest
@testable import Speakwrite

@MainActor
final class SpeakwriteTests: XCTestCase {

    // MARK: - Theme

    func testThemeSpacingValues() {
        XCTAssertEqual(Theme.xs, 4)
        XCTAssertEqual(Theme.sm, 8)
        XCTAssertEqual(Theme.md, 12)
        XCTAssertEqual(Theme.lg, 16)
        XCTAssertEqual(Theme.xl, 20)
    }

    // MARK: - Relative Time

    func testRelativeTimeString() {
        let now = ISO8601DateFormatter().string(from: Date())
        let result = relativeTimeString(from: now)
        XCTAssertEqual(result, "0s")
    }

    func testRelativeTimeStringMinutes() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let iso = ISO8601DateFormatter().string(from: fiveMinutesAgo)
        let result = relativeTimeString(from: iso)
        XCTAssertEqual(result, "5m")
    }

    func testRelativeTimeStringHours() {
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        let iso = ISO8601DateFormatter().string(from: twoHoursAgo)
        let result = relativeTimeString(from: iso)
        XCTAssertEqual(result, "2h")
    }

    // MARK: - Footer Stripping

    func testStripSpeakwriteFooter() {
        let text = "Hello world\n\n✓ Verify a human wrote this · Try Speakwrite"
        let stripped = ATProtoService.stripSpeakwriteFooter(text)
        XCTAssertEqual(stripped, "Hello world")
    }

    func testStripSpeakwriteFooterMediaVariant() {
        let text = "Check this out\n\n✓ Verify authentic content · Try Speakwrite"
        let stripped = ATProtoService.stripSpeakwriteFooter(text)
        XCTAssertEqual(stripped, "Check this out")
    }

    func testStripSpeakwriteFooterNoFooter() {
        let text = "Just a normal post"
        let stripped = ATProtoService.stripSpeakwriteFooter(text)
        XCTAssertEqual(stripped, "Just a normal post")
    }

    func testStripSpeakwriteFooterLegacy() {
        let text = "Old post\n\n✓ speakwrite"
        let stripped = ATProtoService.stripSpeakwriteFooter(text)
        XCTAssertEqual(stripped, "Old post")
    }

    // MARK: - Character Count

    func testCharacterCountGraphemeClusters() {
        // Emoji should count as 1 character (grapheme cluster)
        let text = "Hello 👋🏽"
        XCTAssertEqual(text.count, 7) // "Hello " (6) + skin-tone emoji (1) = 7 grapheme clusters
    }

    // MARK: - Data Extensions

    func testBase64URLEncoded() {
        let data = Data("test".utf8)
        let encoded = data.base64URLEncoded
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }
}
