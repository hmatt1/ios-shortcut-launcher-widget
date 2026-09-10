import Foundation
import CoreGraphics

/// Where a Home Screen widget sits on the wallpaper.
///
/// iOS gives a widget no way to know its own position, so the person tells us
/// which slot they put it in and we reconstruct the rectangle of wallpaper that
/// falls behind it. The numbers are per device, in points, measured against the
/// published iPhone widget canvases. `frame(...)` always returns a rectangle
/// fully inside the screen, so a crop can never sample past the wallpaper edge
/// and show black.
enum WidgetGeometry {

    /// A distinct crop we pre-render. `small` keeps its left/right column;
    /// `medium`, `large` and `extraLarge` are full width, so only the row band
    /// matters and the position is stored as `.top` / `.middle` / `.bottom`.
    struct Slot: Equatable, Sendable {
        var family: BoardSize
        var position: WidgetPosition
    }

    /// Every crop generated on upload. Six small (2 columns x 3 rows) plus three
    /// rows each for medium, large and extra large.
    static let canonicalSlots: [Slot] = {
        var slots: [Slot] = []
        for p in [WidgetPosition.topLeft, .middleLeft, .bottomLeft,
                  .topRight, .middleRight, .bottomRight] {
            slots.append(Slot(family: .small, position: p))
        }
        for family in [BoardSize.medium, .large, .extraLarge] {
            for p in [WidgetPosition.top, .middle, .bottom] {
                slots.append(Slot(family: family, position: p))
            }
        }
        return slots
    }()

    /// The pre-rendered slot that serves a given family and position.
    static func canonicalSlot(family: BoardSize, position: WidgetPosition) -> Slot {
        let band = rowBand(position)
        guard family == .small else {
            return Slot(family: family, position: band)
        }
        let pos: WidgetPosition
        switch (isRight(position), band) {
        case (false, .middle): pos = .middleLeft
        case (false, .bottom): pos = .bottomLeft
        case (false, _):       pos = .topLeft
        case (true, .middle):  pos = .middleRight
        case (true, .bottom):  pos = .bottomRight
        case (true, _):        pos = .topRight
        }
        return Slot(family: .small, position: pos)
    }

    /// The widget's frame on the wallpaper, in screen points, clamped to stay
    /// fully on screen.
    static func frame(family: BoardSize, position: WidgetPosition, screenPoints: CGSize) -> CGRect {
        let m = metrics(width: screenPoints.width, height: screenPoints.height)
        let size = m.size(for: family)
        let band = rowBand(position)

        var y: CGFloat
        switch band {
        case .middle: y = m.middle
        case .bottom: y = m.bottom
        default:      y = m.top
        }

        var x: CGFloat
        if family == .small {
            x = isRight(position) ? m.right : m.left
        } else {
            x = m.left
            // Large and extra large span more rows than the grid has slots for,
            // so a "middle" or "bottom" request just anchors as high as it can
            // and the clamp below keeps it on screen.
            if family == .large, band == .middle { y = (m.top + m.bottom) / 2 }
            if family == .extraLarge { y = m.top }
        }

        var rect = CGRect(x: x, y: y, width: size.width, height: size.height)

        rect.size.width = min(rect.size.width, screenPoints.width)
        rect.size.height = min(rect.size.height, screenPoints.height)
        if rect.maxX > screenPoints.width { rect.origin.x = screenPoints.width - rect.width }
        if rect.maxY > screenPoints.height { rect.origin.y = screenPoints.height - rect.height }
        rect.origin.x = max(0, rect.origin.x)
        rect.origin.y = max(0, rect.origin.y)
        return rect
    }

    // MARK: - Row / column helpers

    private static func rowBand(_ p: WidgetPosition) -> WidgetPosition {
        switch p {
        case .topLeft, .topRight, .top:             return .top
        case .middleLeft, .middleRight, .middle:    return .middle
        case .bottomLeft, .bottomRight, .bottom:    return .bottom
        }
    }

    private static func isRight(_ p: WidgetPosition) -> Bool {
        switch p {
        case .topRight, .middleRight, .bottomRight: return true
        default:                                   return false
        }
    }

    // MARK: - Device table

    private struct Metrics {
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var middle: CGFloat
        var bottom: CGFloat
        var small: CGSize
        var medium: CGSize
        var large: CGSize
        var extraLarge: CGSize

        func size(for family: BoardSize) -> CGSize {
            switch family {
            case .small:      return small
            case .medium:     return medium
            case .large:      return large
            case .extraLarge: return extraLarge
            }
        }
    }

    private static func metrics(width: CGFloat, height: CGFloat) -> Metrics {
        func sizes(_ s: CGFloat, _ w: CGFloat, _ mH: CGFloat, _ lH: CGFloat, _ xH: CGFloat) ->
            (CGSize, CGSize, CGSize, CGSize) {
            (CGSize(width: s, height: s),
             CGSize(width: w, height: mH),
             CGSize(width: w, height: lH),
             CGSize(width: w, height: xH))
        }

        switch Int(height.rounded()) {
        case 956: // iPhone 16 Pro Max
            let (s, m, l, x) = sizes(170, 364, 170, 382, 594)
            return Metrics(left: 38, right: 232, top: 92, middle: 304, bottom: 516,
                           small: s, medium: m, large: l, extraLarge: x)
        case 932: // 14/15 Pro Max, 14/15/16 Plus
            let (s, m, l, x) = sizes(170, 364, 170, 382, 594)
            return Metrics(left: 32.66, right: 227, top: 84, middle: 296, bottom: 508,
                           small: s, medium: m, large: l, extraLarge: x)
        case 926: // 12/13 Pro Max, 14 Plus
            let (s, m, l, x) = sizes(170, 364, 170, 382, 594)
            return Metrics(left: 32, right: 226, top: 82, middle: 294, bottom: 506,
                           small: s, medium: m, large: l, extraLarge: x)
        case 896: // 11 Pro Max, XS Max, XR, 11
            let (s, m, l, x) = sizes(169, 360, 169, 379, 589)
            return Metrics(left: 27, right: 218, top: 76, middle: 286, bottom: 496,
                           small: s, medium: m, large: l, extraLarge: x)
        case 874: // iPhone 16 Pro
            let (s, m, l, x) = sizes(162, 344, 162, 366, 570)
            return Metrics(left: 29, right: 211, top: 87, middle: 290.66, bottom: 495,
                           small: s, medium: m, large: l, extraLarge: x)
        case 852: // 14 Pro, 15, 16
            let (s, m, l, x) = sizes(158, 338, 158, 354, 550)
            return Metrics(left: 27, right: 208, top: 80, middle: 276, bottom: 472,
                           small: s, medium: m, large: l, extraLarge: x)
        case 844: // 12, 13, 14, 12/13 Pro
            let (s, m, l, x) = sizes(155, 329, 155, 345, 535)
            return Metrics(left: 26, right: 206, top: 77, middle: 273, bottom: 469,
                           small: s, medium: m, large: l, extraLarge: x)
        case 812: // X, XS, 11 Pro, 12/13 mini
            let (s, m, l, x) = sizes(155, 329, 155, 345, 535)
            return Metrics(left: 23, right: 197, top: 71, middle: 261, bottom: 451,
                           small: s, medium: m, large: l, extraLarge: x)
        case 667: // SE (2nd/3rd gen), 6, 7, 8
            let (s, m, l, x) = sizes(148, 321, 148, 324, 500)
            return Metrics(left: 27, right: 200, top: 30, middle: 206, bottom: 382,
                           small: s, medium: m, large: l, extraLarge: x)
        default:
            // Unknown device: estimate from the screen. The clamp in frame(...)
            // keeps every result on screen even when the estimate is rough.
            let side = max(120, (width - 66) / 2)
            let full = max(240, width - 44)
            let gap: CGFloat = 26
            let top: CGFloat = height >= 850 ? 84 : (height >= 800 ? 72 : 40)
            return Metrics(
                left: 22,
                right: max(22, width - 22 - side),
                top: top,
                middle: top + side + gap,
                bottom: top + (side + gap) * 2,
                small: CGSize(width: side, height: side),
                medium: CGSize(width: full, height: side),
                large: CGSize(width: full, height: side * 2 + gap),
                extraLarge: CGSize(width: full, height: side * 3 + gap * 2)
            )
        }
    }
}

extension BoardSize {
    /// Stable token used in pre-rendered crop file names.
    var fileTag: String {
        switch self {
        case .small:      return "small"
        case .medium:     return "medium"
        case .large:      return "large"
        case .extraLarge: return "xl"
        }
    }
}
