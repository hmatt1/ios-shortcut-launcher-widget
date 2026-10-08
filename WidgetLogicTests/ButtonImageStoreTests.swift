import XCTest
import SwiftUI
import UIKit

/// Per-button images: the write/read path, its limits, and a render with an
/// image tile. File tests skip when no App Group container is available, the
/// same way the wallpaper tests do.
@MainActor
final class ButtonImageStoreTests: XCTestCase {

    private var presetId = UUID()

    override func setUpWithError() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container is unavailable in this environment.")
        presetId = UUID()
    }

    override func tearDown() {
        ButtonImageStore.removeAll(presetId: presetId)
    }

    private func pngData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    func testSaveThenReadReturnsAnImageNoLargerThanRequested() {
        XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 1200, height: 800), presetId: presetId, button: 3))
        let image = ButtonImageStore.image(presetId: presetId, button: 3, maxPixel: 100)
        XCTAssertNotNil(image)
        let longest = max(image?.cgImage?.width ?? 0, image?.cgImage?.height ?? 0)
        XCTAssertLessThanOrEqual(longest, 100)
        XCTAssertGreaterThan(longest, 0)
    }

    func testStoredImageIsCappedAtMaxStoredPixels() {
        XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 3000, height: 1500), presetId: presetId, button: 1))
        let image = ButtonImageStore.image(presetId: presetId, button: 1, maxPixel: 10_000)
        let longest = max(image?.cgImage?.width ?? 0, image?.cgImage?.height ?? 0)
        XCTAssertLessThanOrEqual(longest, ButtonImageStore.maxStoredPixels)
    }

    func testRewritingReplacesTheOldFile() {
        XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 64, height: 64), presetId: presetId, button: 2))
        XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 32, height: 32), presetId: presetId, button: 2))
        XCTAssertEqual(ButtonImageStore.buttons(presetId: presetId), [2])
        let image = ButtonImageStore.image(presetId: presetId, button: 2, maxPixel: 512)
        XCTAssertEqual(image?.cgImage?.width, 32)
    }

    func testMissingAndCorruptDataReadAsNoImage() {
        XCTAssertNil(ButtonImageStore.image(presetId: presetId, button: 1, maxPixel: 100))
        XCTAssertFalse(ButtonImageStore.save(data: Data("not an image".utf8), presetId: presetId, button: 1))
        XCTAssertTrue(ButtonImageStore.buttons(presetId: presetId).isEmpty)
    }

    func testOutOfRangeButtonsAreRejected() {
        XCTAssertFalse(ButtonImageStore.save(data: pngData(width: 8, height: 8), presetId: presetId, button: 0))
        XCTAssertFalse(ButtonImageStore.save(data: pngData(width: 8, height: 8), presetId: presetId, button: BoardGrid.maxSlots + 1))
        XCTAssertNil(ButtonImageStore.image(presetId: presetId, button: 0, maxPixel: 100))
    }

    func testRemoveAndRemoveAll() {
        for button in [1, 2, 3] {
            XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 8, height: 8), presetId: presetId, button: button))
        }
        ButtonImageStore.remove(presetId: presetId, button: 2)
        XCTAssertEqual(ButtonImageStore.buttons(presetId: presetId), [1, 3])
        ButtonImageStore.removeAll(presetId: presetId)
        XCTAssertTrue(ButtonImageStore.buttons(presetId: presetId).isEmpty)
    }

    func testCopyAllDuplicatesImagesToAnotherPreset() {
        let other = UUID()
        defer { ButtonImageStore.removeAll(presetId: other) }
        XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 16, height: 16), presetId: presetId, button: 4))
        ButtonImageStore.copyAll(from: presetId, to: other)
        XCTAssertEqual(ButtonImageStore.buttons(presetId: other), [4])
        XCTAssertNotNil(ButtonImageStore.image(presetId: other, button: 4, maxPixel: 100))
        XCTAssertEqual(ButtonImageStore.buttons(presetId: presetId), [4], "the original keeps its images")
    }

    func testDuplicatingAPresetCopiesItsButtonImages() {
        let store = BoardPresetStore.shared
        let created = store.create(name: "ButtonImageStoreTests-duplicate")
        defer { ButtonImageStore.removeAll(presetId: created.id) }
        XCTAssertTrue(ButtonImageStore.save(data: pngData(width: 16, height: 16), presetId: created.id, button: 1))
        store.duplicate(id: created.id)
        guard let index = store.presets.firstIndex(where: { $0.id == created.id }) else {
            return XCTFail("the original preset should still be present")
        }
        let copy = store.presets[index + 1]
        defer { ButtonImageStore.removeAll(presetId: copy.id) }
        XCTAssertEqual(ButtonImageStore.buttons(presetId: copy.id), [1])
    }

    func testPixelSizeUsesTheLongestSideAndScale() {
        XCTAssertEqual(ButtonImageStore.pixelSize(forCell: CGSize(width: 70, height: 50), scale: 3), 210)
    }

    func testImageTileRendersInFullColorAndAccented() {
        let image = UIImage(data: pngData(width: 64, height: 64))
        XCTAssertNotNil(image)
        let tile = SlotFace(
            name: "Poster", surface: .gray, label: .white, mode: .tile, font: .body,
            paddingX: 4, paddingY: 4,
            topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 8,
            image: image
        )
        .frame(width: 100, height: 100)
        XCTAssertNotNil(ImageRenderer(content: tile).uiImage)
    }
}
