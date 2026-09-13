import XCTest
@testable import LauncherBoard

/// Shared helpers for WidgetLogicTests. This target has no host application
/// (see project.yml's WidgetLogicTests comment) and reaches everything in
/// Shared/ - including the widget-specific code that lives there now
/// (Shared/LauncherIntent.swift, Shared/LauncherWidgetView.swift) - through
/// one `@testable import` of LauncherBoard, the app target.

extension XCTestCase {
    /// The standard weak-reference-after-teardown leak check: registers a
    /// teardown block that asserts `instance` has already been deallocated
    /// by the time the test scope ends. A failure here means something kept
    /// a strong reference alive past where it should have (a retain cycle
    /// through a closure, an `@ObservedObject` subscription, etc.) - exactly
    /// the kind of bug that piles up memory in a long-lived widget extension
    /// process one timeline reload at a time.
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(
                instance,
                "Instance should have been deallocated - potential memory leak.",
                file: file,
                line: line
            )
        }
    }
}

/// WCAG 2.x relative luminance and contrast ratio, ported to Swift so
/// ThemeContrastTests checks the real `Theme.spec` values directly instead
/// of a value copied into a Python re-implementation (as
/// Tools/verify-layout.py used to). Formulas: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
enum ContrastRatio {
    private static func linearize(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private static func relativeLuminance(_ rgb: RGB) -> Double {
        0.2126 * linearize(rgb.red) + 0.7152 * linearize(rgb.green) + 0.0722 * linearize(rgb.blue)
    }

    /// Always >= 1.0, regardless of which color is lighter.
    static func between(_ a: RGB, _ b: RGB) -> Double {
        let l1 = relativeLuminance(a)
        let l2 = relativeLuminance(b)
        let (lighter, darker) = l1 >= l2 ? (l1, l2) : (l2, l1)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// Shared combinatorial matrices, reused across the exhaustive test files so
/// each one states its own assertions without re-deriving "every size" /
/// "every density step" / "every published device canvas" locally.
enum TestMatrix {
    static let allSizes: [BoardSize] = BoardSize.allCases

    /// Slot counts worth checking: the edges (1, BoardGrid.maxSlots), a
    /// couple of interior values, and one just past the cap to confirm it's
    /// clamped rather than crashing.
    static let slotCounts = [1, 2, 3, 4, 6, 9, 12, 24, 48, BoardGrid.maxSlots, BoardGrid.maxSlots + 16]

    /// 0 = auto; the rest exercise an explicit pin, including values larger
    /// than any realistic slot count.
    static let explicitColumnCounts = [0, 1, 2, 3, 4, 6, 12]

    static let nameLengths = [0, 1, 4, 8, 16, 40]

    static let allLayouts: [BoardLayoutValues] = DensityTemplate.all.map(\.layout)

    /// Every iPhone widget canvas Apple publishes for each family, smallest
    /// first - the same table Tools/verify-layout.py used to hardcode,
    /// ported here so BoardGridTests checks the real function against it.
    static let publishedCanvases: [BoardSize: [CGSize]] = [
        .small: [CGSize(width: 141, height: 141), CGSize(width: 148, height: 148), CGSize(width: 155, height: 155),
                  CGSize(width: 158, height: 158), CGSize(width: 162, height: 162), CGSize(width: 169, height: 169),
                  CGSize(width: 170, height: 170)],
        .medium: [CGSize(width: 291, height: 141), CGSize(width: 321, height: 148), CGSize(width: 329, height: 155),
                  CGSize(width: 338, height: 158), CGSize(width: 344, height: 162), CGSize(width: 360, height: 169),
                  CGSize(width: 364, height: 170)],
        .large: [CGSize(width: 291, height: 299), CGSize(width: 321, height: 324), CGSize(width: 329, height: 345),
                 CGSize(width: 338, height: 354), CGSize(width: 344, height: 366), CGSize(width: 360, height: 379),
                 CGSize(width: 364, height: 382)],
        .extraLarge: [CGSize(width: 291, height: 457), CGSize(width: 321, height: 500), CGSize(width: 329, height: 535),
                      CGSize(width: 338, height: 550), CGSize(width: 344, height: 570), CGSize(width: 360, height: 589),
                      CGSize(width: 364, height: 594)],
    ]

    /// The same screen-height table Tools/verify-widget-geometry.py used to
    /// hardcode, as (height, width) screen point pairs - covers the full
    /// iPhone widget-geometry device table plus an "unknown device" pair to
    /// exercise WidgetGeometry.frame's default estimate path.
    static let screenSizes: [CGSize] = [
        CGSize(width: 440, height: 956), CGSize(width: 430, height: 932), CGSize(width: 428, height: 926),
        CGSize(width: 414, height: 896), CGSize(width: 402, height: 874), CGSize(width: 393, height: 852),
        CGSize(width: 390, height: 844), CGSize(width: 375, height: 812), CGSize(width: 375, height: 667),
        // Not in the published table - exercises WidgetGeometry.metrics'
        // `default:` estimate branch.
        CGSize(width: 420, height: 900),
    ]

    static let allPositions: [WidgetPosition] = WidgetPosition.allCases

    static func name(length: Int) -> String {
        String(repeating: "M", count: length)
    }
}
