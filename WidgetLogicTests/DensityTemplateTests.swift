import XCTest
@testable import LauncherBoard

/// `DensityTemplate.all`'s documented design intent (see its doc comment in
/// Shared/BoardPresetStore.swift), encoded as explicit assertions - the
/// layout math tests exercise these values, but nothing previously asserted
/// the actual product decisions per step.
final class DensityTemplateTests: XCTestCase {
    func testExactlyFiveStepsInDocumentedOrder() {
        XCTAssertEqual(DensityTemplate.all.map(\.id), ["flush", "hairline", "standard", "relaxed", "open"])
    }

    func testColumnsAreAlwaysAuto() {
        for template in DensityTemplate.all {
            XCTAssertEqual(template.layout.columns, 0, "\(template.name) should leave columns on auto")
        }
    }

    func testMarginSpacingPaddingCornerRadiusAreNonDecreasingStepOverStep() {
        let all = DensityTemplate.all
        for i in 1..<all.count {
            let prev = all[i - 1].layout
            let cur = all[i].layout
            XCTAssertGreaterThanOrEqual(cur.marginX, prev.marginX, "\(all[i].name) margin regressed from \(all[i - 1].name)")
            XCTAssertGreaterThanOrEqual(cur.marginY, prev.marginY, "\(all[i].name) margin regressed from \(all[i - 1].name)")
            XCTAssertGreaterThanOrEqual(cur.spacingX, prev.spacingX, "\(all[i].name) spacing regressed from \(all[i - 1].name)")
            XCTAssertGreaterThanOrEqual(cur.spacingY, prev.spacingY, "\(all[i].name) spacing regressed from \(all[i - 1].name)")
            XCTAssertGreaterThanOrEqual(cur.paddingX, prev.paddingX, "\(all[i].name) padding regressed from \(all[i - 1].name)")
            XCTAssertGreaterThanOrEqual(cur.paddingY, prev.paddingY, "\(all[i].name) padding regressed from \(all[i - 1].name)")
            XCTAssertGreaterThanOrEqual(cur.cornerRadius, prev.cornerRadius, "\(all[i].name) corner radius regressed from \(all[i - 1].name)")
        }
    }

    func testMarginNeverFallsBelowSpacing() {
        for template in DensityTemplate.all {
            XCTAssertGreaterThanOrEqual(template.layout.marginX, template.layout.spacingX, "\(template.name): margin below spacing")
            XCTAssertGreaterThanOrEqual(template.layout.marginY, template.layout.spacingY, "\(template.name): margin below spacing")
        }
    }

    func testInnerCornerRadiusNeverExceedsFifteen() {
        for template in DensityTemplate.all {
            XCTAssertLessThanOrEqual(template.layout.cornerRadius, 15, "\(template.name) inner corner radius exceeds the documented cap")
        }
    }

    /// Outer radius only fuses to the widget's own ~22pt container corner at
    /// Flush and Hairline, where margin sits close enough to the true edge
    /// for that curve to reach the tile; every roomier step's margin
    /// already clears that zone, so its outer radius just matches inner.
    func testOuterCornerFusesOnlyAtFlushAndHairline() {
        let fused: Set<String> = ["flush", "hairline"]
        for template in DensityTemplate.all {
            if fused.contains(template.id) {
                XCTAssertEqual(template.layout.outerCornerRadius, 22, "\(template.name) should fuse its outer corner to 22")
            } else {
                XCTAssertEqual(
                    template.layout.outerCornerRadius, template.layout.cornerRadius,
                    "\(template.name)'s outer corner should match its inner corner"
                )
            }
        }
    }
}
