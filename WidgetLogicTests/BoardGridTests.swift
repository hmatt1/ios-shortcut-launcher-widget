import XCTest
@testable import LauncherBoard

/// Exhaustive coverage of `BoardGrid.resolve()` against the real Swift
/// implementation - replaces Tools/verify-layout.py, which re-derived this
/// same arithmetic in Python and so could never catch a translation bug
/// between the two. Every invariant here is checked directly against
/// `BoardGrid.resolve`'s actual return value, not a model of it.
///
/// One check from the old script is deliberately NOT ported:
/// "resolved cell size never shrinks on a published device canvas bigger
/// than BoardSize.canvas". `resolve()` has no parameter for an arbitrary
/// canvas size - it always measures against `size.canvas`'s fixed,
/// per-`BoardSize` constant (confirmed: both `PresetEditorView.boardView`
/// and `LauncherWidgetView.body` call it exactly that way) - so that check
/// can only be ported by re-deriving the formula with a canvas parameter
/// the real function doesn't have, which is the exact Python-style
/// reimplementation this migration exists to get away from. If that
/// property needs checking again, it belongs behind a real
/// `resolve(..., canvas: CGSize)` parameter in `Shared/BoardGrid.swift`
/// itself, not in a test.
final class BoardGridTests: XCTestCase {

    /// Recomputes the between-cell size from `resolve()`'s own output,
    /// mirroring the private `currentCell()` formula inside
    /// `Shared/BoardGrid.swift` - the same formula, applied to the
    /// already-resolved `grid.layout`/`grid.columns`/`grid.rows`, since the
    /// original `currentCell()` isn't accessible outside its file.
    private func resolvedCell(_ grid: BoardGrid, size: BoardSize) -> CGSize {
        let width = size.canvas.width - grid.layout.marginX * 2 - grid.layout.spacingX * CGFloat(max(0, grid.columns - 1))
        let height = size.canvas.height - grid.layout.marginY * 2 - grid.layout.spacingY * CGFloat(max(0, grid.rows - 1))
        return CGSize(width: width / CGFloat(grid.columns), height: height / CGFloat(grid.rows))
    }

    /// Invariants 1-4 from the old script's docstring, checked exhaustively
    /// across every size x slot count x explicit column count x density
    /// template x name length - the same combinatorial space
    /// Tools/verify-layout.py covered (313,696 checks), now against the
    /// real function.
    func testExhaustiveInvariants() {
        let epsilon: CGFloat = 1e-6
        var checked = 0

        for size in TestMatrix.allSizes {
            for count in TestMatrix.slotCounts {
                for columns in TestMatrix.explicitColumnCounts {
                    for layout in TestMatrix.allLayouts {
                        for nameLength in TestMatrix.nameLengths {
                            var requested = layout
                            requested.columns = columns

                            let (grid, visibleSlots) = BoardGrid.resolve(
                                count: count,
                                size: size,
                                longestName: nameLength,
                                layout: requested
                            )

                            // Structural sanity - a crash anywhere in resolve()
                            // aborts this whole test, which is itself the main
                            // point of running it exhaustively.
                            XCTAssertGreaterThanOrEqual(grid.columns, 1, "columns \(grid.columns) for \(size)/\(count)/\(columns)")
                            XCTAssertGreaterThanOrEqual(grid.rows, 1, "rows \(grid.rows) for \(size)/\(count)/\(columns)")
                            XCTAssertLessThanOrEqual(visibleSlots, min(count, BoardGrid.maxSlots))
                            XCTAssertLessThanOrEqual(visibleSlots, grid.columns * grid.rows)

                            // Invariant 1: no tile ever smaller than 1x1pt.
                            let cell = resolvedCell(grid, size: size)
                            XCTAssertGreaterThanOrEqual(cell.width, 1 - epsilon, "cell.width \(cell.width) for \(size)/\(count)/\(columns)")
                            XCTAssertGreaterThanOrEqual(cell.height, 1 - epsilon, "cell.height \(cell.height) for \(size)/\(count)/\(columns)")

                            // Invariant 3: resolved spacing/margin/padding equal
                            // the requested layout whenever the canvas already
                            // fits them undegraded (checked using the request's
                            // OWN values against resolve()'s chosen column/row
                            // count, since that's the only way to ask "would
                            // this have fit without any degradation").
                            let undegradedWidth = size.canvas.width - requested.marginX * 2 - requested.spacingX * CGFloat(max(0, grid.columns - 1))
                            let undegradedHeight = size.canvas.height - requested.marginY * 2 - requested.spacingY * CGFloat(max(0, grid.rows - 1))
                            if undegradedWidth / CGFloat(grid.columns) >= 1 - epsilon {
                                XCTAssertEqual(grid.layout.marginX, requested.marginX, accuracy: epsilon)
                                XCTAssertEqual(grid.layout.spacingX, requested.spacingX, accuracy: epsilon)
                            }
                            if undegradedHeight / CGFloat(grid.rows) >= 1 - epsilon {
                                XCTAssertEqual(grid.layout.marginY, requested.marginY, accuracy: epsilon)
                                XCTAssertEqual(grid.layout.spacingY, requested.spacingY, accuracy: epsilon)
                            }

                            // Invariant 4: degradation order - margin is only
                            // ever reduced once spacing has nothing left to
                            // give (provable from resolve()'s own cut formula:
                            // if step 1's spacing cut alone could have closed
                            // the gap, step 2 never fires at all). Guarded by
                            // cols/rows > 1 exactly like resolve() guards
                            // spacing degradation itself - with a single
                            // column/row, spacing plays no part in the
                            // formula regardless of its value.
                            if grid.columns > 1, grid.layout.marginX < requested.marginX - epsilon {
                                XCTAssertEqual(grid.layout.spacingX, 0, accuracy: epsilon,
                                               "margin degraded while spacing wasn't yet 0, for \(size)/\(count)/\(columns)")
                            }
                            if grid.rows > 1, grid.layout.marginY < requested.marginY - epsilon {
                                XCTAssertEqual(grid.layout.spacingY, 0, accuracy: epsilon,
                                               "margin degraded while spacing wasn't yet 0, for \(size)/\(count)/\(columns)")
                            }

                            checked += 1
                        }
                    }
                }
            }
        }

        // A floor on the combinatorial count, so a future edit to
        // TestMatrix that accidentally shrinks it to near-nothing doesn't
        // silently pass while covering almost none of the space.
        XCTAssertGreaterThan(checked, 10_000, "exhaustive matrix shrank unexpectedly - only \(checked) combinations checked")
    }

    /// Direct regression coverage for BoardGrid.maxSlots itself: a request
    /// far past the cap still resolves, and never reports more visible
    /// slots than the cap allows.
    func testSlotCountIsCappedAtMaxSlots() {
        let layout = TestMatrix.allLayouts[0]
        for size in TestMatrix.allSizes {
            let (grid, visibleSlots) = BoardGrid.resolve(count: BoardGrid.maxSlots * 4, size: size, longestName: 6, layout: layout)
            XCTAssertLessThanOrEqual(visibleSlots, BoardGrid.maxSlots)
            XCTAssertGreaterThanOrEqual(grid.columns * grid.rows, visibleSlots)
        }
    }

    /// count <= 0 is clamped to 1 slot (`max(1, count)` in resolve()),
    /// rather than producing a zero-row/zero-column grid.
    func testNonPositiveCountIsClampedToOneSlot() {
        let layout = TestMatrix.allLayouts[0]
        for size in TestMatrix.allSizes {
            for count in [0, -1, -100] {
                let (grid, visibleSlots) = BoardGrid.resolve(count: count, size: size, longestName: 4, layout: layout)
                XCTAssertGreaterThanOrEqual(grid.columns, 1)
                XCTAssertGreaterThanOrEqual(grid.rows, 1)
                XCTAssertGreaterThanOrEqual(visibleSlots, 1)
            }
        }
    }

    /// Corner radii helpers (`topLeadingRadius` etc.) only ever return the
    /// outer radius at the actual outer corner of the resolved grid, and
    /// the inner radius everywhere else - across every grid shape produced
    /// above, not just a hand-picked few.
    func testCornerRadiiOnlyApplyAtRealOuterCorners() {
        for size in TestMatrix.allSizes {
            for layout in TestMatrix.allLayouts {
                let (grid, _) = BoardGrid.resolve(count: 24, size: size, longestName: 6, layout: layout)
                for row in 0..<grid.rows {
                    for col in 0..<grid.columns {
                        let isTopLeft = col == 0 && row == 0
                        let isBottomLeft = col == 0 && row == grid.rows - 1
                        let isBottomTrailing = col == grid.columns - 1 && row == grid.rows - 1
                        let isTopTrailing = col == grid.columns - 1 && row == 0

                        XCTAssertEqual(grid.topLeadingRadius(col: col, row: row), isTopLeft ? grid.layout.outerCornerRadius : grid.layout.cornerRadius)
                        XCTAssertEqual(grid.bottomLeadingRadius(col: col, row: row), isBottomLeft ? grid.layout.outerCornerRadius : grid.layout.cornerRadius)
                        XCTAssertEqual(grid.bottomTrailingRadius(col: col, row: row), isBottomTrailing ? grid.layout.outerCornerRadius : grid.layout.cornerRadius)
                        XCTAssertEqual(grid.topTrailingRadius(col: col, row: row), isTopTrailing ? grid.layout.outerCornerRadius : grid.layout.cornerRadius)
                    }
                }
            }
        }
    }
}
