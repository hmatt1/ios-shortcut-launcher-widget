import Foundation
import AppIntents

/// Standalone list actions. Every other preset or theme action takes one chosen
/// item; these return the whole list (optionally narrowed by name) so a shortcut
/// can loop over it, pick from it, or count it. They read the same store
/// singletons the editor and the other actions use, so results match the app.

struct FindPresetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Presets"
    static var description: IntentDescription {
        IntentDescription("Returns your presets, in the order shown in the app. Fill in a name to narrow the list.")
    }

    @Parameter(title: "Name Contains")
    var nameContains: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PresetAppEntity]> {
        let matches = NameFilter.matching(BoardPresetStore.shared.presets, name: \.name, containing: nameContains)
        return .result(value: matches.map(PresetAppEntity.init))
    }
}

struct FindThemesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Themes"
    static var description: IntentDescription {
        IntentDescription("Returns your themes, in the order shown in the app. Fill in a name to narrow the list.")
    }

    @Parameter(title: "Name Contains")
    var nameContains: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ThemeAppEntity]> {
        let matches = NameFilter.matching(BoardThemeStore.shared.themes, name: \.name, containing: nameContains)
        return .result(value: matches.map(ThemeAppEntity.init))
    }
}
