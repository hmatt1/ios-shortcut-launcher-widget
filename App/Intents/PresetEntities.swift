import Foundation
import AppIntents

// App Intents for the Shortcuts app. These live in the app target only: the
// widget's own intents (LauncherIntent, BoardPresetEntity) must stay out of the
// app binary, and nothing intent-related may live in Shared/ (see the
// "App Intents guard" step in build.yml). Hence the separate PresetAppEntity.

struct PresetAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Preset")
    }

    static var defaultQuery = PresetAppQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ preset: BoardPreset) {
        self.id = preset.id
        self.name = preset.name
    }
}

struct PresetAppQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [PresetAppEntity] {
        BoardPresetStore.loadRaw().filter { identifiers.contains($0.id) }.map(PresetAppEntity.init)
    }

    func entities(matching string: String) async throws -> [PresetAppEntity] {
        BoardPresetStore.loadRaw()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(PresetAppEntity.init)
    }

    func suggestedEntities() async throws -> [PresetAppEntity] {
        BoardPresetStore.loadRaw().map(PresetAppEntity.init)
    }
}

// Literal dictionaries, because the App Intents build step reads these
// statically.

extension BoardFontFamily: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Font")
    }

    public static var caseDisplayRepresentations: [BoardFontFamily: DisplayRepresentation] {
        [
            .system: DisplayRepresentation(title: "System"),
            .rounded: DisplayRepresentation(title: "Rounded"),
            .serif: DisplayRepresentation(title: "Serif"),
            .monospaced: DisplayRepresentation(title: "Monospaced"),
            .avenirNext: DisplayRepresentation(title: "Avenir Next"),
            .georgia: DisplayRepresentation(title: "Georgia"),
            .menlo: DisplayRepresentation(title: "Menlo")
        ]
    }
}

extension BoardFontWeight: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Font Weight")
    }

    public static var caseDisplayRepresentations: [BoardFontWeight: DisplayRepresentation] {
        [
            .regular: DisplayRepresentation(title: "Regular"),
            .medium: DisplayRepresentation(title: "Medium"),
            .semibold: DisplayRepresentation(title: "Semibold"),
            .bold: DisplayRepresentation(title: "Bold")
        ]
    }
}

extension BackgroundStyle: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Background Style")
    }

    public static var caseDisplayRepresentations: [BackgroundStyle: DisplayRepresentation] {
        [
            .theme: DisplayRepresentation(title: "Solid Color"),
            .liquidGlass: DisplayRepresentation(title: "System Default"),
            .transparent: DisplayRepresentation(title: "Transparent")
        ]
    }
}
