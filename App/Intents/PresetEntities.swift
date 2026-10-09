import Foundation
import AppIntents

// App Intents for the Shortcuts app. These live in the app target only: the
// widget's own intents (LauncherIntent, BoardPresetEntity) must stay out of the
// app binary, and nothing intent-related may live in Shared/ (see the
// "App Intents guard" step in build.yml). Hence the separate PresetAppEntity.

/// A preset as Shortcuts sees it. The properties are what "Get Details of
/// Preset" offers, so a shortcut can read any setting, not just the name.
struct PresetAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Preset")
    }

    static var defaultQuery = PresetAppQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Theme")
    var themeName: String

    @Property(title: "Density")
    var density: String

    @Property(title: "Font")
    var fontFamily: BoardFontFamily

    @Property(title: "Font Weight")
    var fontWeight: BoardFontWeight

    @Property(title: "Background")
    var background: BackgroundStyle

    @Property(title: "Columns")
    var columns: Int

    @Property(title: "Margin X")
    var marginX: Int

    @Property(title: "Margin Y")
    var marginY: Int

    @Property(title: "Spacing X")
    var spacingX: Int

    @Property(title: "Spacing Y")
    var spacingY: Int

    @Property(title: "Padding X")
    var paddingX: Int

    @Property(title: "Padding Y")
    var paddingY: Int

    @Property(title: "Inner Corners")
    var cornerRadius: Int

    @Property(title: "Outer Corners")
    var outerCornerRadius: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ preset: BoardPreset) {
        let summary = PresetSummary(preset, themeName: BoardThemeStore.loadTheme(id: preset.themeId).name)
        self.id = preset.id
        self.name = summary.name
        self.themeName = summary.themeName
        self.density = summary.density
        self.fontFamily = summary.fontFamily
        self.fontWeight = summary.fontWeight
        self.background = summary.background
        self.columns = summary.columns
        self.marginX = summary.marginX
        self.marginY = summary.marginY
        self.spacingX = summary.spacingX
        self.spacingY = summary.spacingY
        self.paddingX = summary.paddingX
        self.paddingY = summary.paddingY
        self.cornerRadius = summary.cornerRadius
        self.outerCornerRadius = summary.outerCornerRadius
    }
}

struct PresetAppQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [PresetAppEntity] {
        BoardPresetStore.loadRaw().filter { identifiers.contains($0.id) }.map(PresetAppEntity.init)
    }

    func entities(matching string: String) async throws -> [PresetAppEntity] {
        NameFilter.matching(BoardPresetStore.loadRaw(), name: \.name, containing: string)
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
