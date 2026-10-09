import Foundation
import CoreGraphics
import AppIntents

/// The optional fields of the "Update Preset" and "Update Preset Layout"
/// Shortcuts actions. Only the fields that are set change; everything else
/// keeps its value. A density is applied first, so explicit layout fields given
/// alongside it win. Free of App Intents behavior so it can be unit-tested (an
/// `AppIntent` can't be constructed outside the system, see
/// `LauncherIntentTests`).
///
/// Ranges mirror the steppers in `PresetEditorView`, so a shortcut can never
/// produce a value the editor can't.
struct PresetEdit: Equatable {
    static let columnsRange = 0...12
    static let spacingRange = 0...40
    static let cornerRange = 0...32

    var name: String?
    var columns: Int?
    var marginX: Int?
    var marginY: Int?
    var spacingX: Int?
    var spacingY: Int?
    var paddingX: Int?
    var paddingY: Int?
    var cornerRadius: Int?
    var outerCornerRadius: Int?
    var fontFamily: BoardFontFamily?
    var fontWeight: BoardFontWeight?
    var background: BackgroundStyle?
    var themeId: UUID?
    var density: PresetDensity?

    func applying(to preset: BoardPreset) -> BoardPreset {
        var result = preset
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            result.name = trimmed
        }
        if let density { density.template.apply(to: &result) }
        if let columns { result.columns = Self.clamp(columns, Self.columnsRange) }
        if let marginX { result.marginX = CGFloat(Self.clamp(marginX, Self.spacingRange)) }
        if let marginY { result.marginY = CGFloat(Self.clamp(marginY, Self.spacingRange)) }
        if let spacingX { result.spacingX = CGFloat(Self.clamp(spacingX, Self.spacingRange)) }
        if let spacingY { result.spacingY = CGFloat(Self.clamp(spacingY, Self.spacingRange)) }
        if let paddingX { result.paddingX = CGFloat(Self.clamp(paddingX, Self.spacingRange)) }
        if let paddingY { result.paddingY = CGFloat(Self.clamp(paddingY, Self.spacingRange)) }
        if let cornerRadius { result.cornerRadius = CGFloat(Self.clamp(cornerRadius, Self.cornerRange)) }
        if let outerCornerRadius { result.outerCornerRadius = CGFloat(Self.clamp(outerCornerRadius, Self.cornerRange)) }
        if let fontFamily { result.fontFamily = fontFamily }
        if let fontWeight { result.fontWeight = fontWeight }
        if let background { result.background = background }
        if let themeId { result.themeId = themeId }
        return result
    }

    static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// The five density templates as a Shortcuts choice, mapped onto the shared
/// `DensityTemplate` the editor uses.
enum PresetDensity: String, AppEnum, CaseIterable {
    case flush, hairline, standard, relaxed, open

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Density")
    }

    static var caseDisplayRepresentations: [PresetDensity: DisplayRepresentation] {
        [
            .flush: DisplayRepresentation(title: "Flush"),
            .hairline: DisplayRepresentation(title: "Hairline"),
            .standard: DisplayRepresentation(title: "Standard"),
            .relaxed: DisplayRepresentation(title: "Relaxed"),
            .open: DisplayRepresentation(title: "Open")
        ]
    }

    var template: DensityTemplate {
        DensityTemplate.all.first { $0.id == rawValue } ?? DensityTemplate.all[0]
    }
}

/// The values a preset exposes to Shortcuts as readable properties
/// ("Get Details of Preset"). Pure, so the mapping can be unit-tested.
struct PresetSummary: Equatable {
    var name: String
    var themeName: String
    var density: String
    var fontFamily: BoardFontFamily
    var fontWeight: BoardFontWeight
    var background: BackgroundStyle
    var columns: Int
    var marginX: Int
    var marginY: Int
    var spacingX: Int
    var spacingY: Int
    var paddingX: Int
    var paddingY: Int
    var cornerRadius: Int
    var outerCornerRadius: Int
    /// Button numbers that have a picture, ascending.
    var imageButtons: [Int]

    init(_ preset: BoardPreset, themeName: String, imageButtons: [Int] = []) {
        name = preset.name
        self.themeName = themeName
        density = DensityTemplate.matching(preset)?.name ?? "Custom"
        fontFamily = preset.fontFamily
        fontWeight = preset.fontWeight
        background = preset.background
        columns = preset.columns
        marginX = Int(preset.marginX.rounded())
        marginY = Int(preset.marginY.rounded())
        spacingX = Int(preset.spacingX.rounded())
        spacingY = Int(preset.spacingY.rounded())
        paddingX = Int(preset.paddingX.rounded())
        paddingY = Int(preset.paddingY.rounded())
        cornerRadius = Int(preset.cornerRadius.rounded())
        outerCornerRadius = Int(preset.outerCornerRadius.rounded())
        self.imageButtons = imageButtons.sorted()
    }
}

/// Errors a Shortcuts action can show to the person running it.
enum PresetIntentError: Error, CustomLocalizedStringResourceConvertible {
    case presetNotFound
    case lastPreset
    case buttonOutOfRange(Int)
    case unreadableImage

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .presetNotFound:
            return "That preset no longer exists."
        case .lastPreset:
            return "The last preset can't be deleted."
        case .buttonOutOfRange(let number):
            return "Button \(number) is out of range. Use a number from 1 to \(BoardGrid.maxSlots)."
        case .unreadableImage:
            return "That file isn't an image Shortcut Launcher can read."
        }
    }

    /// Validates a button number the same way for every action.
    static func validatedButton(_ number: Int) throws -> Int {
        guard ButtonImageStore.buttonRange.contains(number) else {
            throw PresetIntentError.buttonOutOfRange(number)
        }
        return number
    }
}
