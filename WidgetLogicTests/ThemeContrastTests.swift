import XCTest
@testable import LauncherBoardWidget

/// Replaces the contrast-ratio checks from Tools/verify-layout.py (its
/// docstring items 5-6), now run against the real `Theme.spec` values in
/// Shared/Theme.swift via the WCAG contrast helper in TestSupport.swift,
/// instead of a copy of the palette re-typed into Python.
final class ThemeContrastTests: XCTestCase {
    /// Every accent must clear 4.5:1 against its theme's label color - the
    /// legibility floor for text drawn over a tile's own surface color.
    /// Monochrome themes (Ink, Paper) have no accents and are skipped, same
    /// as the old script scoped this check to chromatic themes only (see
    /// `ThemeSpec.surface(at:accented:)`'s comment on why).
    func testAccentsClearContrastAgainstLabel() {
        for theme in Theme.allCases {
            let spec = theme.spec
            guard !spec.accents.isEmpty else { continue }
            let label = spec.labels.first ?? RGB(0xFFFFFF)
            for (index, accent) in spec.accents.enumerated() {
                let ratio = ContrastRatio.between(accent, label)
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5,
                    "\(theme.displayName) accent[\(index)] only clears \(ratio):1 against its label (need 4.5:1)"
                )
            }
        }
    }

    /// Every accent must clear 1.5:1 against both background stops, so a
    /// tile's own surface color stays visually distinct from what's behind
    /// it even at Flush density, where there's no margin/spacing gap to
    /// carry that boundary instead.
    func testAccentsClearContrastAgainstBackground() {
        for theme in Theme.allCases {
            let spec = theme.spec
            guard !spec.accents.isEmpty else { continue }
            for (index, accent) in spec.accents.enumerated() {
                for (stopIndex, backgroundStop) in spec.background.enumerated() {
                    let ratio = ContrastRatio.between(accent, backgroundStop)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 1.5,
                        "\(theme.displayName) accent[\(index)] only clears \(ratio):1 against background stop \(stopIndex) (need 1.5:1)"
                    )
                }
            }
        }
    }

    /// Sanity check on the helper itself: identical colors must report
    /// exactly 1:1, and pure black vs. pure white must report the
    /// well-known WCAG maximum of 21:1.
    func testContrastRatioHelperMatchesKnownValues() {
        let black = RGB(red: 0, green: 0, blue: 0)
        let white = RGB(red: 1, green: 1, blue: 1)
        XCTAssertEqual(ContrastRatio.between(black, black), 1.0, accuracy: 1e-9)
        XCTAssertEqual(ContrastRatio.between(black, white), 21.0, accuracy: 1e-3)
        XCTAssertEqual(ContrastRatio.between(white, black), 21.0, accuracy: 1e-3, "must be symmetric")
    }
}
