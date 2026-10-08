import Foundation
import AppIntents
import UniformTypeIdentifiers
import WidgetKit

/// Shortcuts actions for presets and their button images. They go through the
/// same `BoardPresetStore.shared` the editor uses, so the app stays consistent
/// when one runs while it is open, and each reloads the widgets afterwards.

@MainActor
private func existingPreset(_ entity: PresetAppEntity) throws -> BoardPreset {
    guard let preset = BoardPresetStore.shared.presets.first(where: { $0.id == entity.id }) else {
        throw PresetIntentError.presetNotFound
    }
    return preset
}

struct CreatePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Preset"
    static var description: IntentDescription {
        IntentDescription("Adds a new preset with the standard layout.")
    }

    @Parameter(title: "Name", default: "New Preset")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let created = BoardPresetStore.shared.create(name: trimmed.isEmpty ? "New Preset" : trimmed)
        return .result(value: PresetAppEntity(created))
    }
}

struct DuplicatePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Duplicate Preset"
    static var description: IntentDescription {
        IntentDescription("Copies a preset, including its font and button images.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let original = try existingPreset(preset)
        let store = BoardPresetStore.shared
        store.duplicate(id: original.id)
        guard let index = store.presets.firstIndex(where: { $0.id == original.id }),
              store.presets.indices.contains(index + 1) else {
            throw PresetIntentError.presetNotFound
        }
        return .result(value: PresetAppEntity(store.presets[index + 1]))
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

/// Every field is optional: only the ones a shortcut provides change.
struct UpdatePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Preset"
    static var description: IntentDescription {
        IntentDescription("Changes a preset's name, layout, font or background. Only the fields you fill in change.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Columns (0 = Auto)")
    var columns: Int?

    @Parameter(title: "Margin X")
    var marginX: Int?

    @Parameter(title: "Margin Y")
    var marginY: Int?

    @Parameter(title: "Spacing X")
    var spacingX: Int?

    @Parameter(title: "Spacing Y")
    var spacingY: Int?

    @Parameter(title: "Padding X")
    var paddingX: Int?

    @Parameter(title: "Padding Y")
    var paddingY: Int?

    @Parameter(title: "Inner Corners")
    var cornerRadius: Int?

    @Parameter(title: "Outer Corners")
    var outerCornerRadius: Int?

    @Parameter(title: "Font")
    var fontFamily: BoardFontFamily?

    @Parameter(title: "Font Weight")
    var fontWeight: BoardFontWeight?

    @Parameter(title: "Background")
    var background: BackgroundStyle?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let existing = try existingPreset(preset)
        let edit = PresetEdit(
            name: name,
            columns: columns,
            marginX: marginX,
            marginY: marginY,
            spacingX: spacingX,
            spacingY: spacingY,
            paddingX: paddingX,
            paddingY: paddingY,
            cornerRadius: cornerRadius,
            outerCornerRadius: outerCornerRadius,
            fontFamily: fontFamily,
            fontWeight: fontWeight,
            background: background
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

    @Parameter(title: "Button Number", default: 1)
    var button: Int

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile

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

    @Parameter(title: "Button Number", default: 1)
    var button: Int

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
