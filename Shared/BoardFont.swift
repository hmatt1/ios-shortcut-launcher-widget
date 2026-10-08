import SwiftUI
import UIKit

/// Weight choices offered for a preset's tile text. Semibold is the original
/// look, so it is the default everywhere.
public enum BoardFontWeight: String, Codable, CaseIterable, Sendable {
    case regular
    case medium
    case semibold
    case bold

    public var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    /// Extra advance, in em, on top of a family's base width. Heavier weights
    /// run wider, and sizing has to assume the wider case or names overflow.
    fileprivate var advanceAdjustment: CGFloat {
        switch self {
        case .regular: return -0.02
        case .medium: return -0.01
        case .semibold: return 0
        case .bold: return 0.02
        }
    }
}

/// Built-in font families a preset can pick. Raw values are stored in the
/// preset JSON, so they are stable IDs and never font names: a font can be
/// renamed or swapped here without touching saved presets.
///
/// Only fonts that ship with iOS are offered. Nothing is bundled, so there is
/// no extra memory in the widget extension and no registration to maintain.
public enum BoardFontFamily: String, Codable, CaseIterable, Sendable {
    case system
    case rounded
    case serif
    case monospaced
    case avenirNext
    case georgia
    case menlo

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Monospaced"
        case .avenirNext: return "Avenir Next"
        case .georgia: return "Georgia"
        case .menlo: return "Menlo"
        }
    }

    /// The system designs support every weight natively.
    private var design: Font.Design? {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .avenirNext, .georgia, .menlo: return nil
        }
    }

    /// Georgia and Menlo ship a regular and a bold face only, so Regular and
    /// Medium share the regular face and Semibold and Bold share the bold one.
    public var weightsAreSnapped: Bool {
        self == .georgia || self == .menlo
    }

    /// The weight that is actually drawn once snapping is applied.
    func effectiveWeight(_ weight: BoardFontWeight) -> BoardFontWeight {
        guard weightsAreSnapped else { return weight }
        switch weight {
        case .regular, .medium: return .regular
        case .semibold, .bold: return .bold
        }
    }

    /// PostScript name of the face for a named (non-system) family, nil for
    /// the system designs.
    func faceName(weight: BoardFontWeight) -> String? {
        let effective = effectiveWeight(weight)
        switch self {
        case .system, .rounded, .serif, .monospaced:
            return nil
        case .avenirNext:
            switch effective {
            case .regular: return "AvenirNext-Regular"
            case .medium: return "AvenirNext-Medium"
            case .semibold: return "AvenirNext-DemiBold"
            case .bold: return "AvenirNext-Bold"
            }
        case .georgia:
            return effective == .bold ? "Georgia-Bold" : "Georgia"
        case .menlo:
            return effective == .bold ? "Menlo-Bold" : "Menlo-Regular"
        }
    }

    /// Average glyph advance as a fraction of the point size, for mixed-case
    /// shortcut names. The sizing ladder in `BoardGrid` uses it to decide how
    /// large a board's text can be before its longest name stops fitting.
    /// `BoardFontTests` checks these against real font measurements, so a
    /// value that under-reports (names overflow) or over-reports (text smaller
    /// than it needs to be) fails CI. System at Semibold is the original
    /// 0.55 and must stay that way so existing boards resolve identically.
    func averageAdvance(weight: BoardFontWeight) -> CGFloat {
        let base: CGFloat
        switch self {
        case .system: base = 0.55
        case .rounded: base = 0.57
        case .serif: base = 0.55
        // Fixed-pitch faces keep one advance at every weight.
        case .monospaced, .menlo: return 0.62
        case .avenirNext: base = 0.56
        case .georgia: base = 0.58
        }
        return base + effectiveWeight(weight).advanceAdjustment
    }

    /// Line height as a multiple of the point size, used for the height half
    /// of the same fit test. System is the original 1.25.
    var lineHeightFactor: CGFloat {
        switch self {
        case .system, .rounded, .monospaced, .georgia, .menlo: return 1.25
        case .serif: return 1.3
        case .avenirNext: return 1.4
        }
    }

    /// A Dynamic Type-aware font for one rung of the sizing ladder. Named
    /// faces are sized relative to the rung's text style so Larger Text still
    /// scales them, and fall back to the system font if the face is missing
    /// so a tile can never render blank.
    func font(style: Font.TextStyle, points: CGFloat, weight: BoardFontWeight) -> Font {
        if let design {
            return Font.system(style, design: design).weight(weight.fontWeight)
        }
        if let face = faceName(weight: weight), UIFont(name: face, size: points) != nil {
            return Font.custom(face, size: points, relativeTo: style)
        }
        return Font.system(style, design: .default).weight(weight.fontWeight)
    }
}
