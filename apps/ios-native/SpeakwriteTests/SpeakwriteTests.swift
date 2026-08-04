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

    // MARK: - Count Formatting

    func testFormatCountSmall() {
        XCTAssertEqual(formatCount(0), "0")
        XCTAssertEqual(formatCount(42), "42")
        XCTAssertEqual(formatCount(999), "999")
    }

    func testFormatCountThousands() {
        XCTAssertEqual(formatCount(1000), "1K")
        XCTAssertEqual(formatCount(1234), "1.2K")
        XCTAssertEqual(formatCount(9999), "10K")
        XCTAssertEqual(formatCount(43_210), "43K")
    }

    func testFormatCountMillions() {
        XCTAssertEqual(formatCount(1_000_000), "1M")
        XCTAssertEqual(formatCount(1_150_000), "1.2M")
    }

    // MARK: - PostNavigation Identity

    func testPostNavigationEqualityIgnoresCounts() {
        // Identity is the URI alone — engagement counts changing must not
        // change the navigation value's identity while it's on a path
        let base = PostNavigation(
            uri: "at://did:plc:x/app.bsky.feed.post/1", cid: "cid1",
            authorHandle: "a.bsky.social", authorDID: "did:plc:x",
            authorAvatar: nil, authorDisplayName: nil,
            text: "hi", createdAt: "2026-01-01T00:00:00Z",
            likeCount: 0, repostCount: 0, replyCount: 0,
            viewerLike: nil, viewerRepost: nil,
            isVerified: false, images: nil, videoURL: nil, videoThumbnail: nil
        )
        let liked = PostNavigation(
            uri: "at://did:plc:x/app.bsky.feed.post/1", cid: "cid1",
            authorHandle: "a.bsky.social", authorDID: "did:plc:x",
            authorAvatar: nil, authorDisplayName: nil,
            text: "hi", createdAt: "2026-01-01T00:00:00Z",
            likeCount: 5, repostCount: 2, replyCount: 1,
            viewerLike: "at://like", viewerRepost: nil,
            isVerified: true, images: nil, videoURL: nil, videoThumbnail: nil
        )
        XCTAssertEqual(base, liked)
        XCTAssertEqual(base.hashValue, liked.hashValue)
    }
}
