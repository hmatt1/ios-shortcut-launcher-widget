import XCTest
@testable import LauncherBoard

/// Replaces Tools/verify-widget-geometry.py: checks the real
/// `WidgetGeometry.frame(family:position:screenPoints:)` directly, across
/// every family x position x the same device-height table the Python
/// script hardcoded, plus one screen size absent from that table to
/// exercise the `default:` (unknown-device) estimate branch in
/// `WidgetGeometry.metrics(width:height:)`.
///
/// The one invariant that matters, per that script's own docstring: a crop
/// rectangle can never sample past the wallpaper edge, so it must always
/// land fully inside the screen.
final class WidgetGeometryTests: XCTestCase {
    func testFrameAlwaysStaysOnScreen() {
        let epsilon: CGFloat = 1e-6
        var checked = 0

        for screenSize in TestMatrix.screenSizes {
            for family in TestMatrix.allSizes {
                for position in TestMatrix.allPositions {
                    let rect = WidgetGeometry.frame(family: family, position: position, screenPoints: screenSize)

                    XCTAssertGreaterThanOrEqual(rect.origin.x, -epsilon, "\(family)/\(position) on \(screenSize): x \(rect.origin.x)")
                    XCTAssertGreaterThanOrEqual(rect.origin.y, -epsilon, "\(family)/\(position) on \(screenSize): y \(rect.origin.y)")
                    XCTAssertLessThanOrEqual(rect.maxX, screenSize.width + epsilon, "\(family)/\(position) on \(screenSize): maxX \(rect.maxX)")
                    XCTAssertLessThanOrEqual(rect.maxY, screenSize.height + epsilon, "\(family)/\(position) on \(screenSize): maxY \(rect.maxY)")

                    // A crop with zero or negative extent isn't "on screen" in
                    // any useful sense either, even though it'd technically
                    // pass the bounds checks above.
                    XCTAssertGreaterThan(rect.width, 0)
                    XCTAssertGreaterThan(rect.height, 0)

                    checked += 1
                }
            }
        }

        XCTAssertEqual(checked, TestMatrix.screenSizes.count * TestMatrix.allSizes.count * TestMatrix.allPositions.count)
    }

    /// `canonicalSlot(family:position:)` always returns a slot whose stored
    /// position is a real member of the canonical set for that family - the
    /// lookup used to pick a pre-rendered wallpaper crop, so a mismatch here
    /// means the wrong crop image gets served, not just a wrong number.
    func testCanonicalSlotIsAlwaysAMemberOfCanonicalSlots() {
        for family in TestMatrix.allSizes {
            for position in TestMatrix.allPositions {
                let slot = WidgetGeometry.canonicalSlot(family: family, position: position)
                XCTAssertTrue(
                    WidgetGeometry.canonicalSlots.contains(slot),
                    "canonicalSlot(\(family), \(position)) = \(slot) isn't in canonicalSlots"
                )
            }
        }
    }
}
