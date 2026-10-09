import Foundation
import AppIntents

/// List management actions: the order of presets and themes, and bringing the
/// built-in ones back. These mirror the drag-to-reorder and "Restore Default"
/// buttons in the app's lists.

/// Pure position arithmetic, so it can be unit-tested.
enum ListOrder {
    /// Which index an item ends up at for a 1-based `position`, clamped into the list.
    static func finalIndex(forPosition position: Int, count: Int) -> Int {
        min(max(position, 1), max(count, 1)) - 1
    }

    /// The `toOffset` that `Array.move(fromOffsets:toOffset:)` (and the stores'
    /// `reorder`) expect so the item at `index` lands at `finalIndex`. That API
    /// takes the insertion point *before* the move, so moving down needs one more.
    static func moveDestination(from index: Int, toFinalIndex finalIndex: Int) -> Int {
        finalIndex > index ? finalIndex + 1 : finalIndex
    }
}

struct MovePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Preset"
    static var description: IntentDescription {
        IntentDescription("Moves a preset to a position in the app's list. 1 is the top; a number past the end moves it to the bottom.")
    }

    @Parameter(title: "Preset")
    var preset: PresetAppEntity

    @Parameter(title: "Position", description: "1 is the top of the list.", default: 1)
    var position: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$preset) to position \(\.$position)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PresetAppEntity> {
        let existing = try existingPreset(preset)
        let store = BoardPresetStore.shared
        guard let index = store.presets.firstIndex(where: { $0.id == existing.id }) else {
            throw PresetIntentError.presetNotFound
        }
        let final = ListOrder.finalIndex(forPosition: position, count: store.presets.count)
        store.reorder(from: IndexSet(integer: index), to: ListOrder.moveDestination(from: index, toFinalIndex: final))
        return .result(value: PresetAppEntity(existing))
    }
}

struct MoveThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Theme"
    static var description: IntentDescription {
        IntentDescription("Moves a theme to a position in the app's list. 1 is the top; a number past the end moves it to the bottom.")
    }

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity

    @Parameter(title: "Position", description: "1 is the top of the list.", default: 1)
    var position: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$theme) to position \(\.$position)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let existing = try existingTheme(theme)
        let store = BoardThemeStore.shared
        guard let index = store.themes.firstIndex(where: { $0.id == existing.id }) else {
            throw ThemeIntentError.themeNotFound
        }
        let final = ListOrder.finalIndex(forPosition: position, count: store.themes.count)
        store.reorder(from: IndexSet(integer: index), to: ListOrder.moveDestination(from: index, toFinalIndex: final))
        return .result(value: ThemeAppEntity(existing))
    }
}

struct RestoreDefaultPresetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Restore Default Presets"
    static var description: IntentDescription {
        IntentDescription("Brings back any built-in preset whose look is missing, without changing or removing your presets. Returns the presets it added.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PresetAppEntity]> {
        let store = BoardPresetStore.shared
        let before = Set(store.presets.map(\.id))
        store.restoreDefaultPresets()
        let added = store.presets.filter { !before.contains($0.id) }
        return .result(value: added.map(PresetAppEntity.init))
    }
}

struct RestoreDefaultThemesIntent: AppIntent {
    static let title: LocalizedStringResource = "Restore Default Themes"
    static var description: IntentDescription {
        IntentDescription("Brings back any built-in theme whose colors are missing, without changing or removing your themes. Returns the themes it added.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ThemeAppEntity]> {
        let store = BoardThemeStore.shared
        let before = Set(store.themes.map(\.id))
        store.restoreDefaultThemes()
        let added = store.themes.filter { !before.contains($0.id) }
        return .result(value: added.map(ThemeAppEntity.init))
    }
}
