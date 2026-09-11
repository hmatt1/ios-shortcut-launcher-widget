import Foundation
import SwiftUI

/// The three widget families the board supports.
enum BoardSize: CaseIterable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// The smallest canvas iOS gives this family, from the 320 x 568 pt
    /// layout a 4.7 inch iPhone reaches with Display Zoom on. Layout is
    /// clamped against this rather than against the largest phone, so the
    /// touch-target floor holds on every device and tiles only ever grow.
    var canvas: CGSize {
        switch self {
        case .small: return CGSize(width: 141, height: 141)
        case .medium: return CGSize(width: 291, height: 141)
        case .large: return CGSize(width: 291, height: 299)
        case .extraLarge: return CGSize(width: 291, height: 457)
        }
    }
}

/// How one tile arranges itself.
enum TileMode: Equatable, Sendable {
    /// Full width, name on the left.
    case row
    /// Equal share of a grid, name centred.
    case tile

    /// A wide short bar has room for two lines; a square tile has room for
    /// three, which is what lets a long name stay large.
    var lineLimit: Int {
        switch self {
        case .row: return 2
        case .tile: return 3
        }
    }
}

/// A resolved board. Everything the view layer needs, with no measurement.
struct BoardGrid: Sendable {
    /// The most tiles a board will lay out. Past this the widget simply drops
    /// the overflow; a tile that small is unreadable anyway.
    static let maxSlots = 64

    let columns: Int
    let rows: Int
    let mode: TileMode
    let layout: BoardLayoutValues
    let font: Font

    static func resolve(
        count: Int,
        size: BoardSize,
        longestName: Int,
        layout requestedLayout: BoardLayoutValues
    ) -> (grid: BoardGrid, visibleSlots: Int) {

        let requestedSlots = max(1, count)
        let slots = min(requestedSlots, maxSlots)
        
        let cols = requestedLayout.columns == 0 ? columnCount(for: slots, size: size) : requestedLayout.columns
        let rows = Int(ceil(Double(slots) / Double(cols)))
        
        let visibleSlots = min(requestedSlots, cols * rows)
        let mode: TileMode = cols == 1 && visibleSlots > 1 ? .row : .tile

        var layout = requestedLayout
        
        func currentCell() -> CGSize {
            let width = size.canvas.width - layout.marginX * 2 - layout.spacingX * CGFloat(max(0, cols - 1))
            let height = size.canvas.height - layout.marginY * 2 - layout.spacingY * CGFloat(max(0, rows - 1))
            return CGSize(
                width: width / CGFloat(cols),
                height: height / CGFloat(rows)
            )
        }

        var cell = currentCell()

        // Degradation order: spacing -> margin -> padding -> floor at 1pt
        // 1. Reduce spacing toward 0
        if cell.width < 1 && cols > 1 {
            let neededTotal = (1 - cell.width) * CGFloat(cols)
            let cut = min(layout.spacingX, neededTotal / CGFloat(cols - 1))
            layout.spacingX -= cut
        }
        if cell.height < 1 && rows > 1 {
            let neededTotal = (1 - cell.height) * CGFloat(rows)
            let cut = min(layout.spacingY, neededTotal / CGFloat(rows - 1))
            layout.spacingY -= cut
        }
        cell = currentCell()

        // 2. Reduce margin toward 0
        if cell.width < 1 {
            let neededTotal = (1 - cell.width) * CGFloat(cols)
            let cut = min(layout.marginX, neededTotal / 2)
            layout.marginX -= cut
        }
        if cell.height < 1 {
            let neededTotal = (1 - cell.height) * CGFloat(rows)
            let cut = min(layout.marginY, neededTotal / 2)
            layout.marginY -= cut
        }
        cell = currentCell()

        // 3. Reduce padding toward 0. Padding sits inside the cell rather than
        // between cells, so it never shows up in `currentCell()` above — a
        // cell can already clear the 1pt floor below while its own padding
        // still consumes the whole thing, hiding the one thing (the name)
        // that tells tiles apart. This mainly bites in row mode: its row
        // count grows with the shortcut count with no column dimension to
        // share the pressure, so padding — never degraded before, on the
        // assumption spacing and margin would always absorb it first — could
        // exceed the whole row. This step only fires once those two are
        // already exhausted, so every board that resolved fine before still
        // resolves exactly the same.
        if cell.width - layout.paddingX * 2 < 1 {
            let neededTotal = 1 - (cell.width - layout.paddingX * 2)
            let cut = min(layout.paddingX, neededTotal / 2)
            layout.paddingX -= cut
        }
        if cell.height - layout.paddingY * 2 < 1 {
            let neededTotal = 1 - (cell.height - layout.paddingY * 2)
            let cut = min(layout.paddingY, neededTotal / 2)
            layout.paddingY -= cut
        }

        // 4. Floor at 1pt
        cell.width = max(1, cell.width)
        cell.height = max(1, cell.height)

        let font = textStyle(cell: cell, mode: mode, longestName: longestName, layout: layout)

        let grid = BoardGrid(
            columns: cols,
            rows: rows,
            mode: mode,
            layout: layout,
            font: font
        )
        return (grid, visibleSlots)
    }

    private static func columnCount(for slots: Int, size: BoardSize) -> Int {
        guard slots > 1 else { return 1 }
        // Past the hand-tuned range, fit the column count to the canvas aspect
        // ratio so cells stay as square as the family allows.
        if slots > 12 {
            let aspect = Double(size.canvas.width / size.canvas.height)
            let cols = (Double(slots) * aspect).squareRoot().rounded()
            return min(max(Int(cols), 1), slots)
        }
        switch size {
        case .small:
            return slots <= 3 ? 1 : 2
        case .medium:
            return slots <= 3 ? slots : (slots == 4 ? 2 : 3)
        case .large, .extraLarge:
            return slots <= 3 ? 1 : balanced(slots)
        }
    }

    /// Column counts chosen so rows stay even.
    private static func balanced(_ slots: Int) -> Int {
        switch slots {
        case 4: return 2
        case 5, 6: return 3
        case 7, 8: return 4
        case 9: return 3
        default: return 4
        }
    }

    /// The ladder of text styles, largest first, with the point size each one
    /// resolves to at the default Dynamic Type setting.
    private static let ladder: [(font: Font, points: CGFloat)] = [
        (.largeTitle, 34),
        (.title, 28),
        (.title2, 22),
        (.title3, 20),
        (.headline, 17),
        (.subheadline, 15),
        (.footnote, 13),
        (.caption, 12)
    ]

    /// The largest style whose longest name still fits the tile in both
    /// directions. Sizing to the names rather than to the geometry alone is
    /// what keeps a board at one size: without it, a single long name shrinks
    /// only its own tile and the grid loses its only ordering principle.
    /// `minimumScaleFactor` in the view is then a safety net, not the
    /// mechanism.
    private static func textStyle(cell: CGSize, mode: TileMode, longestName: Int, layout: BoardLayoutValues) -> Font {
        let width = max(1, cell.width - layout.paddingX * 2)
        let characters = CGFloat(max(4, longestName))
        let lines = CGFloat(mode.lineLimit)

        for step in ladder {
            // 0.55 em is a reasonable average advance for a semibold sans face.
            let needed = step.points * 0.55 * characters
            let used = min(lines, max(1, (needed / width).rounded(.up)))
            let fitsWidth = used <= lines
            let fitsHeight = (cell.height - layout.paddingY * 2) >= step.points * 1.25 * used + 6
            if fitsWidth && needed <= width * lines && fitsHeight {
                return step.font
            }
        }
        return .caption
    }
}

/// Placeholder names, shared by the widget's gallery card and the in-app
/// preview so both show the same thing.
enum BoardSample {
    static let names = ["Focus", "Coffee", "Drive", "Gym", "Lights", "Notes", "Music", "Timer", "Read"]
}

extension BoardGrid {
    func topLeadingRadius(col: Int, row: Int) -> CGFloat {
        (col == 0 && row == 0) ? layout.outerCornerRadius : layout.cornerRadius
    }
    func bottomLeadingRadius(col: Int, row: Int) -> CGFloat {
        (col == 0 && row == rows - 1) ? layout.outerCornerRadius : layout.cornerRadius
    }
    func bottomTrailingRadius(col: Int, row: Int) -> CGFloat {
        (col == columns - 1 && row == rows - 1) ? layout.outerCornerRadius : layout.cornerRadius
    }
    func topTrailingRadius(col: Int, row: Int) -> CGFloat {
        (col == columns - 1 && row == 0) ? layout.outerCornerRadius : layout.cornerRadius
    }
}
