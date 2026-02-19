// Snapshot tests using swift-snapshot-testing
// These tests capture rendered SwiftUI views and compare against reference images.
//
// To regenerate all snapshots after intentional UI changes:
//    Set `isRecording = true` in setUp(), run tests, then set back to false.

import XCTest
@testable import Speakwrite
import SnapshotTesting
import SwiftUI

@MainActor
final class SnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set to true to regenerate reference snapshots
        isRecording = false
    }

    // MARK: - Component Snapshots

    func testAvatarViewSizes() {
        let view = HStack(spacing: 20) {
            AvatarView(url: nil, handle: "alice.bsky.social", size: .small)
            AvatarView(url: nil, handle: "bob.bsky.social", size: .medium)
            AvatarView(url: nil, handle: nil, size: .large)
        }
        .padding()
        .frame(width: 300)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13))
    }

    func testStatView() {
        let view = HStack(spacing: 24) {
            StatView(count: 89, label: "Posts")
            StatView(count: 1234, label: "Followers")
            StatView(count: 567, label: "Following")
        }
        .padding()
        .frame(width: 350)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13))
    }

    func testCharacterCountRing() {
        let view = VStack(spacing: 20) {
            CharacterCountRing(count: 0, limit: 300)
            CharacterCountRing(count: 150, limit: 300)
            CharacterCountRing(count: 285, limit: 300)
            CharacterCountRing(count: 310, limit: 300)
        }
        .padding()
        .frame(width: 100)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13))
    }

    // MARK: - Screen Snapshots

    func testLoginView() {
        let view = LoginView()
            .environment(AppViewModel.previewLoggedOut)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13))
    }

    func testSettingsView() {
        let view = SettingsView()
            .environment(AppViewModel.preview)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13))
    }

    func testPostDetailView() {
        // PostDetailView contains relative timestamps that change between runs.
        // Use precision + perceptualPrecision to tolerate timestamp text differences.
        let view = NavigationStack {
            PostDetailView(nav: .preview)
        }
        .environment(AppViewModel.preview)

        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.95, perceptualPrecision: 0.90)
        )
    }

    // MARK: - Multi-Device Snapshots

    func testLoginViewiPhoneSE() {
        let view = LoginView()
            .environment(AppViewModel.previewLoggedOut)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhoneSe))
    }

    func testLoginViewiPhone13ProMax() {
        let view = LoginView()
            .environment(AppViewModel.previewLoggedOut)

        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13ProMax))
    }
}
