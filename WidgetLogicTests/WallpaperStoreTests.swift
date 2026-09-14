import XCTest
import UIKit
@testable import LauncherBoard

/// `WallpaperStore`'s actual image pipeline (Shared/WallpaperStore.swift) -
/// only its geometry math is covered elsewhere (WidgetGeometryTests, which
/// tests `WidgetGeometry.frame` directly).
@MainActor
final class WallpaperStoreTests: XCTestCase {
    /// A small synthetic solid-color image - no bundled fixture needed,
    /// since none of these tests care about its exact content.
    private func makeTestImage(width: Int, height: Int, color: UIColor = .systemBlue) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { _ in
            color.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    // MARK: - save() - behavior depends on whether this host-less test
    // target actually has a usable App Group container at runtime (see
    // project.yml's WidgetLogicTests comment on why it might not). Both
    // branches are asserted explicitly rather than assuming one.

    func testSaveDoesNotCrashRegardlessOfContainerAvailability() {
        let image = makeTestImage(width: 400, height: 800)
        WallpaperStore.shared.save(image: image, screenPoints: CGSize(width: 390, height: 844), scale: 3)

        if AppGroup.containerURL == nil {
            XCTAssertFalse(WallpaperStore.shared.hasWallpaper, "save() should fail gracefully with no App Group container available")
        } else {
            XCTAssertTrue(WallpaperStore.shared.hasWallpaper, "save() should succeed when a real container is available")
            XCTAssertNotNil(
                WallpaperStore.croppedWallpaper(family: .medium, position: .top),
                "a crop should be readable back after a successful save"
            )
        }
    }

    func testSaveFailsGracefullyWithZeroSizedScreenPoints() {
        let before = WallpaperStore.shared.hasWallpaper
        let image = makeTestImage(width: 10, height: 10)
        WallpaperStore.shared.save(image: image, screenPoints: .zero, scale: 3)
        // A degenerate screenPoints must never crash, and must never flip
        // hasWallpaper to true off a save that wrote nothing.
        XCTAssertEqual(WallpaperStore.shared.hasWallpaper, before)
    }

    func testSaveFailsGracefullyWithZeroScale() {
        let before = WallpaperStore.shared.hasWallpaper
        let image = makeTestImage(width: 10, height: 10)
        WallpaperStore.shared.save(image: image, screenPoints: CGSize(width: 390, height: 844), scale: 0)
        XCTAssertEqual(WallpaperStore.shared.hasWallpaper, before)
    }

    /// The fill-and-center-crop math (private `normalizedCGImage`, exercised
    /// only through the one public entry point, `save()`) should always
    /// produce a small slice, never the full normalized canvas - a sanity
    /// check that cropping actually happened, using a source image with a
    /// deliberately different aspect ratio than the target so a bug in that
    /// math would show up as a stretched or wrongly-sized crop.
    func testCroppedOutputIsASliceNotTheWholeCanvas() throws {
        guard AppGroup.containerURL != nil else {
            throw XCTSkip("App Group container is unavailable in this environment - the write-and-read-back path isn't exercised here.")
        }
        let wideImage = makeTestImage(width: 2000, height: 200)
        let screenPoints = CGSize(width: 390, height: 844)
        let scale: CGFloat = 3
        WallpaperStore.shared.save(image: wideImage, screenPoints: screenPoints, scale: scale)

        guard let crop = WallpaperStore.croppedWallpaper(family: .small, position: .topLeft) else {
            return XCTFail("expected a readable crop after a successful save")
        }
        XCTAssertLessThan(crop.size.width, screenPoints.width * scale)
        XCTAssertLessThan(crop.size.height, screenPoints.height * scale)
    }

    func testRemoveWallpaperClearsHasWallpaper() {
        let image = makeTestImage(width: 100, height: 100)
        WallpaperStore.shared.save(image: image, screenPoints: CGSize(width: 390, height: 844), scale: 3)
        WallpaperStore.shared.removeWallpaper()
        XCTAssertFalse(WallpaperStore.shared.hasWallpaper)
        XCTAssertNil(WallpaperStore.croppedWallpaper(family: .small, position: .topLeft))
    }
}
