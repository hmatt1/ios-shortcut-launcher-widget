import Foundation
import AppIntents
import UniformTypeIdentifiers
import WidgetKit

/// Shortcuts actions for presets and their button images. They go through the
/// same `BoardPresetStore.shared` the editor uses, so the app stays consistent
/// when one runs while it is open, and each reloads the widgets afterwards.
///
/// Every action with more than one field declares a `parameterSummary`, so the
/// card in Shortcuts shows the main input and tucks the optional fields under
/// "Show More".

@MainActor
func existingPreset(_ entity: PresetAppEntity) throws -> BoardPreset {
    guard let preset = BoardPresetStore.shared.presets.first(where: { $0.id == entity.id }) else {
        throw PresetIntentError.presetNotFound
    }
    return preset
}

struct CreatePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Preset"
    static var description: IntentDescription {
        IntentDescription("Adds a new preset with the standard layout. Turn on Reuse Existing to get the preset with that name instead of adding another.")
    }

    @Parameter(title: "Name", default: "New Preset")
    var name: String

    @Parameter(title: "Reuse Existing", description: "If a preset with this name already exists, return it instead of creating another.", default: false)
    var reuseExisting: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Create preset \(\.$name)") {
            \.$reuseExisting
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let store = BoardPresetStore.shared
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New Preset" : trimmed
        if reuseExisting, let existing = NameFilter.first(store.presets, name: \.name, named: finalName) {
            return .result(value: PresetAppEntity(existing))
        }
        return .result(value: PresetAppEntity(store.create(name: finalName)))
    }
}

struct DuplicatePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Duplicate Preset"
    static var description: IntentDescription {
        IntentDescription("Copies a preset, including its font and button images.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Name", description: "Name for the copy. Leave empty for \"<name> Copy\".")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Duplicate \(\.$preset)") {
            \.$name
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let original = try existingPreset(preset)
        let store = BoardPresetStore.shared
        store.duplicate(id: original.id)
        guard let index = store.presets.firstIndex(where: { $0.id == original.id }),
              store.presets.indices.contains(index + 1) else {
            throw PresetIntentError.presetNotFound
        }
        var copy = store.presets[index + 1]
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            copy.name = trimmed
            store.update(copy)
        }
        return .result(value: PresetAppEntity(copy))
    }
}

struct DeletePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Preset"
    static var description: IntentDescription {
        IntentDescription("Deletes a preset and its button images. The last preset can't be deleted.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let existing = try existingPreset(preset)
        let store = BoardPresetStore.shared
        guard store.presets.count > 1 else { throw PresetIntentError.lastPreset }
        store.delete(id: existing.id)
        return .result()
    }
}

/// The look of a preset. Every field is optional: only the ones a shortcut
/// provides change. Density is applied before any layout fields.
struct UpdatePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Preset"
    static var description: IntentDescription {
        IntentDescription("Changes a preset's name, theme, density, font or background. Only the fields you fill in change. Use Update Preset Layout for exact spacing.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity?

    @Parameter(title: "Density", description: "Sets margin, spacing, padding and corners together.")
    var density: PresetDensity?

    @Parameter(title: "Font")
    var fontFamily: BoardFontFamily?

    @Parameter(title: "Font Weight")
    var fontWeight: BoardFontWeight?

    @Parameter(title: "Background")
    var background: BackgroundStyle?

    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$preset)") {
            \.$name
            \.$theme
            \.$density
            \.$fontFamily
            \.$fontWeight
            \.$background
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let existing = try existingPreset(preset)
        let themeId = try theme.map { try existingTheme($0).id }
        let edit = PresetEdit(
            name: name,
            fontFamily: fontFamily,
            fontWeight: fontWeight,
            background: background,
            themeId: themeId,
            density: density
        )
        let updated = edit.applying(to: existing)
        BoardPresetStore.shared.update(updated)
        return .result(value: PresetAppEntity(updated))
    }
}

/// Exact numbers, for fine tuning after a density. Values outside the range
/// are set to the nearest allowed value, the same limits as the editor.
struct UpdatePresetLayoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Preset Layout"
    static var description: IntentDescription {
        IntentDescription("Changes a preset's columns, margins, spacing, padding and corners. Only the fields you fill in change.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Columns", description: "0 for Auto, up to 12. Larger values are set to 12.")
    var columns: Int?

    @Parameter(title: "Margin X", description: "0 to 40.")
    var marginX: Int?

    @Parameter(title: "Margin Y", description: "0 to 40.")
    var marginY: Int?

    @Parameter(title: "Spacing X", description: "0 to 40.")
    var spacingX: Int?

    @Parameter(title: "Spacing Y", description: "0 to 40.")
    var spacingY: Int?

    @Parameter(title: "Padding X", description: "0 to 40.")
    var paddingX: Int?

    @Parameter(title: "Padding Y", description: "0 to 40.")
    var paddingY: Int?

    @Parameter(title: "Inner Corners", description: "0 to 32.")
    var cornerRadius: Int?

    @Parameter(title: "Outer Corners", description: "0 to 32.")
    var outerCornerRadius: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Update layout of \(\.$preset)") {
            \.$columns
            \.$marginX
            \.$marginY
            \.$spacingX
            \.$spacingY
            \.$paddingX
            \.$paddingY
            \.$cornerRadius
            \.$outerCornerRadius
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let existing = try existingPreset(preset)
        let edit = PresetEdit(
            columns: columns,
            marginX: marginX,
            marginY: marginY,
            spacingX: spacingX,
            spacingY: spacingY,
            paddingX: paddingX,
            paddingY: paddingY,
            cornerRadius: cornerRadius,
            outerCornerRadius: outerCornerRadius
        )
        let updated = edit.applying(to: existing)
        BoardPresetStore.shared.update(updated)
        return .result(value: PresetAppEntity(updated))
    }
}

struct SetButtonImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Button Image"
    static var description: IntentDescription {
        IntentDescription("Shows a picture on a button. Buttons are numbered from 1 in the order the shortcuts are picked in the widget.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Button Number", description: "1 to 64.", default: 1)
    var button: Int

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$image) on button \(\.$button) of \(\.$preset)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let existing = try existingPreset(preset)
        let number = try PresetIntentError.validatedButton(button)
        guard ButtonImageStore.save(data: image.data, presetId: existing.id, button: number) else {
            throw PresetIntentError.unreadableImage
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct RemoveButtonImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Button Image"
    static var description: IntentDescription {
        IntentDescription("Takes the picture off a button so it shows its name again.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Button Number", description: "1 to 64.", default: 1)
    var button: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Remove the image from button \(\.$button) of \(\.$preset)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let existing = try existingPreset(preset)
        let number = try PresetIntentError.validatedButton(button)
        ButtonImageStore.remove(presetId: existing.id, button: number)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct RemoveAllButtonImagesIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove All Button Images"
    static var description: IntentDescription {
        IntentDescription("Takes every picture off a preset's buttons.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let existing = try existingPreset(preset)
        ButtonImageStore.removeAll(presetId: existing.id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
