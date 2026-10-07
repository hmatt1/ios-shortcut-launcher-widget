import XCTest
import SwiftUI
import UIKit

/// Per-preset font support: face resolution, the sizing metrics `BoardGrid`
/// relies on, and a real render per family. The metrics test measures actual
/// glyph advances with UIFont, so a constant in `BoardFontFamily` that drifts
/// from the real font fails here rather than as overflowing tiles on a device.
@MainActor
final class BoardFontTests: XCTestCase {

    private let allWeights = BoardFontWeight.allCases
    private let allFamilies = BoardFontFamily.allCases

    // MARK: - Faces

    func testEveryNamedFaceExists() {
        for family in allFamilies {
            for weight in allWeights {
                guard let face = family.faceName(weight: weight) else { continue }
                XCTAssertNotNil(
                    UIFont(name: face, size: 17),
                    "\(family.rawValue)/\(weight.rawValue) maps to '\(face)', which isn't installed"
                )
            }
        }
    }

    func testSystemDesignsHaveNoNamedFace() {
        for family in [BoardFontFamily.system, .rounded, .serif, .monospaced] {
            for weight in allWeights {
                XCTAssertNil(family.faceName(weight: weight))
            }
        }
    }

    func testGeorgiaAndMenloSnapToRegularOrBold() {
        XCTAssertEqual(BoardFontFamily.georgia.faceName(weight: .regular), "Georgia")
        XCTAssertEqual(BoardFontFamily.georgia.faceName(weight: .medium), "Georgia")
        XCTAssertEqual(BoardFontFamily.georgia.faceName(weight: .semibold), "Georgia-Bold")
        XCTAssertEqual(BoardFontFamily.georgia.faceName(weight: .bold), "Georgia-Bold")
        XCTAssertEqual(BoardFontFamily.menlo.faceName(weight: .regular), "Menlo-Regular")
        XCTAssertEqual(BoardFontFamily.menlo.faceName(weight: .medium), "Menlo-Regular")
        XCTAssertEqual(BoardFontFamily.menlo.faceName(weight: .semibold), "Menlo-Bold")
        XCTAssertEqual(BoardFontFamily.menlo.faceName(weight: .bold), "Menlo-Bold")
        XCTAssertTrue(BoardFontFamily.georgia.weightsAreSnapped)
        XCTAssertTrue(BoardFontFamily.menlo.weightsAreSnapped)
        XCTAssertFalse(BoardFontFamily.avenirNext.weightsAreSnapped)
        XCTAssertFalse(BoardFontFamily.system.weightsAreSnapped)
    }

    func testAvenirNextHasAFacePerWeight() {
        let faces = allWeights.compactMap { BoardFontFamily.avenirNext.faceName(weight: $0) }
        XCTAssertEqual(Set(faces).count, allWeights.count)
    }

    // MARK: - Original look is untouched

    func testSystemSemiboldKeepsTheOriginalMetrics() {
        XCTAssertEqual(BoardFontFamily.system.averageAdvance(weight: .semibold), 0.55)
        XCTAssertEqual(BoardFontFamily.system.lineHeightFactor, 1.25)
    }

    func testDefaultsResolveLikeExplicitSystemSemibold() {
        for size in TestMatrix.allSizes {
            for layout in TestMatrix.allLayouts {
                let implicit = BoardGrid.resolve(count: 6, size: size, longestName: 12, layout: layout)
                let explicit = BoardGrid.resolve(
                    count: 6, size: size, longestName: 12, layout: layout,
                    fontFamily: .system, fontWeight: .semibold
                )
                XCTAssertEqual(implicit.grid.fontPoints, explicit.grid.fontPoints)
                XCTAssertEqual(implicit.grid.columns, explicit.grid.columns)
            }
        }
    }

    // MARK: - Metrics honesty

    /// Real font for a family/weight at `size`, built the same way the app
    /// builds it (named face, or the system font with the matching design).
    private func uiFont(_ family: BoardFontFamily, _ weight: BoardFontWeight, size: CGFloat) -> UIFont? {
        if let face = family.faceName(weight: weight) {
            return UIFont(name: face, size: size)
        }
        let uiWeight: UIFont.Weight
        switch weight {
        case .regular: uiWeight = .regular
        case .medium: uiWeight = .medium
        case .semibold: uiWeight = .semibold
        case .bold: uiWeight = .bold
        }
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight)
        let design: UIFontDescriptor.SystemDesign
        switch family {
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .monospaced: design = .monospaced
        default: design = .default
        }
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// The table must not under-report width (names would overflow their
    /// tile) nor over-report it by much (text would be smaller than needed).
    func testAverageAdvanceMatchesRealMeasurements() {
        let sample = BoardSample.names.joined()
        let size: CGFloat = 100
        for family in allFamilies {
            for weight in allWeights {
                guard let font = uiFont(family, weight, size: size) else {
                    XCTFail("no UIFont for \(family.rawValue)/\(weight.rawValue)")
                    continue
                }
                let width = (sample as NSString).size(withAttributes: [.font: font]).width
                let measured = width / size / CGFloat(sample.count)
                let table = family.averageAdvance(weight: weight)
                XCTAssertGreaterThanOrEqual(
                    table, measured * 0.98,
                    "\(family.rawValue)/\(weight.rawValue): table \(table) em under-reports measured \(measured) em"
                )
                XCTAssertLessThanOrEqual(
                    table, measured * 1.30,
                    "\(family.rawValue)/\(weight.rawValue): table \(table) em is far above measured \(measured) em"
                )
            }
        }
    }

    func testLineHeightFactorCoversRealLineHeight() {
        let size: CGFloat = 100
        for family in allFamilies {
            for weight in allWeights {
                guard let font = uiFont(family, weight, size: size) else {
                    XCTFail("no UIFont for \(family.rawValue)/\(weight.rawValue)")
                    continue
                }
                let measured = font.lineHeight / size
                XCTAssertGreaterThanOrEqual(
                    family.lineHeightFactor, measured * 0.98,
                    "\(family.rawValue)/\(weight.rawValue): factor \(family.lineHeightFactor) under-reports line height \(measured)"
                )
            }
        }
    }

    // MARK: - Sizing

    /// A wider font can only ever pick the same rung or a smaller one, never a
    /// bigger one, for the same names and the same cell.
    func testWiderFontNeverGetsALargerRungThanNarrowerFont() {
        for size in TestMatrix.allSizes {
            for count in [1, 4, 9, 24] {
                for layout in TestMatrix.allLayouts {
                    for nameLength in TestMatrix.nameLengths {
                        for weight in allWeights {
                            let narrow = BoardGrid.resolve(
                                count: count, size: size, longestName: nameLength, layout: layout,
                                fontFamily: .system, fontWeight: weight
                            ).grid
                            let wide = BoardGrid.resolve(
                                count: count, size: size, longestName: nameLength, layout: layout,
                                fontFamily: .monospaced, fontWeight: weight
                            ).grid
                            XCTAssertLessThanOrEqual(wide.fontPoints, narrow.fontPoints)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rendering

    /// A real SwiftUI render for every family x weight x widget size, so a
    /// font that fails to resolve or crashes in layout shows up here.
    func testEveryFamilyAndWeightRenders() {
        let layout = DensityTemplate.all[2].layout
        for size in TestMatrix.allSizes {
            for family in allFamilies {
                for weight in allWeights {
                    let names = BoardSample.names
                    let resolved = BoardGrid.resolve(
                        count: names.count, size: size,
                        longestName: names.map(\.count).max() ?? 0,
                        layout: layout, fontFamily: family, fontWeight: weight
                    )
                    let grid = resolved.grid
                    let view = BoardView(grid: grid, count: resolved.visibleSlots) { index, col, row in
                        SlotFace(
                            name: names[index],
                            surface: .gray,
                            label: .white,
                            mode: grid.mode,
                            font: grid.font,
                            paddingX: grid.layout.paddingX,
                            paddingY: grid.layout.paddingY,
                            topLeadingRadius: grid.topLeadingRadius(col: col, row: row),
                            bottomLeadingRadius: grid.bottomLeadingRadius(col: col, row: row),
                            bottomTrailingRadius: grid.bottomTrailingRadius(col: col, row: row),
                            topTrailingRadius: grid.topTrailingRadius(col: col, row: row)
                        )
                    }
                    .frame(width: size.canvas.width, height: size.canvas.height)

                    XCTAssertNotNil(
                        ImageRenderer(content: view).uiImage,
                        "render failed: \(size)/\(family.rawValue)/\(weight.rawValue)"
                    )
                }
            }
        }
    }
}
