import Foundation
import AppIntents
import WidgetKit

/// A theme as Shortcuts sees it. The properties are what "Get Details of
/// Theme" offers; colors are `#RRGGBB` text.
struct ThemeAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Theme")
    }

    static var defaultQuery = ThemeAppQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Button Colors", description: "Empty for a monochrome theme.")
    var buttonColors: [String]

    @Property(title: "Background Colors", description: "One color is flat, two is a gradient.")
    var backgroundColors: [String]

    @Property(title: "Label Color")
    var labelColor: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ theme: BoardTheme) {
        let summary = ThemeSummary(theme)
        self.id = theme.id
        self.name = summary.name
        self.buttonColors = summary.buttonColors
        self.backgroundColors = summary.backgroundColors
        self.labelColor = summary.labelColor
    }
}

struct ThemeAppQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ThemeAppEntity] {
        BoardThemeStore.loadRaw().filter { identifiers.contains($0.id) }.map(ThemeAppEntity.init)
    }

    func entities(matching string: String) async throws -> [ThemeAppEntity] {
        NameFilter.matching(BoardThemeStore.loadRaw(), name: \.name, containing: string)
            .map(ThemeAppEntity.init)
    }

    func suggestedEntities() async throws -> [ThemeAppEntity] {
        BoardThemeStore.loadRaw().map(ThemeAppEntity.init)
    }
}

@MainActor
func existingTheme(_ entity: ThemeAppEntity) throws -> BoardTheme {
    guard let theme = BoardThemeStore.shared.themes.first(where: { $0.id == entity.id }) else {
        throw ThemeIntentError.themeNotFound
    }
    return theme
}

struct CreateThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Theme"
    static var description: IntentDescription {
        IntentDescription("Adds a new theme, starting from the Midnight colors. Turn on Reuse Existing to get the theme with that name instead of adding another.")
    }

    @Parameter(title: "Name", default: "New Theme")
    var name: String

    @Parameter(title: "Reuse Existing", description: "If a theme with this name already exists, return it instead of creating another.", default: false)
    var reuseExisting: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Create theme \(\.$name)") {
            \.$reuseExisting
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let store = BoardThemeStore.shared
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New Theme" : trimmed
        if reuseExisting, let existing = NameFilter.first(store.themes, name: \.name, named: finalName) {
            return .result(value: ThemeAppEntity(existing))
        }
        return .result(value: ThemeAppEntity(store.create(name: finalName)))
    }
}

struct DuplicateThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Duplicate Theme"
    static var description: IntentDescription {
        IntentDescription("Copies a theme and its colors.")
    }

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity

    @Parameter(title: "Name", description: "Name for the copy. Leave empty for \"<name> Copy\".")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Duplicate \(\.$theme)") {
            \.$name
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let original = try existingTheme(theme)
        let store = BoardThemeStore.shared
        store.duplicate(id: original.id)
        guard let index = store.themes.firstIndex(where: { $0.id == original.id }),
              store.themes.indices.contains(index + 1) else {
            throw ThemeIntentError.themeNotFound
        }
        var copy = store.themes[index + 1]
        if let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            copy.name = trimmed
            store.update(copy)
        }
        return .result(value: ThemeAppEntity(copy))
    }
}

struct DeleteThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Theme"
    static var description: IntentDescription {
        IntentDescription("Deletes a theme. Presets using it fall back to the first theme. The last theme can't be deleted.")
    }

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let existing = try existingTheme(theme)
        let store = BoardThemeStore.shared
        guard store.themes.count > 1 else { throw ThemeIntentError.lastTheme }
        store.delete(id: existing.id)
        return .result()
    }
}

/// Every field is optional: only the ones a shortcut provides change. Colors
/// are `#RRGGBB` (or `#RGB`) text; a bad color changes nothing.
struct UpdateThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Theme"
    static var description: IntentDescription {
        IntentDescription("Changes a theme's name or colors. Colors are hex text like #1A2B3C. Only the fields you fill in change.")
    }

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Background Color", description: "Hex color. On its own, the background becomes flat.")
    var backgroundColor: String?

    @Parameter(title: "Background Color 2", description: "Hex color for the gradient end. On its own, it keeps the current first color.")
    var backgroundColor2: String?

    @Parameter(title: "Label Color", description: "Hex color for every button's text.")
    var labelColor: String?

    @Parameter(title: "Button Colors", description: "Hex colors for the buttons, up to 12, repeating in order.")
    var buttonColors: [String]?

    @Parameter(title: "Monochrome Tiles", description: "Clears the button colors so tiles use a faint tint of the label color. If you also give Button Colors, those are used.")
    var monochrome: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$theme)") {
            \.$name
            \.$backgroundColor
            \.$backgroundColor2
            \.$labelColor
            \.$buttonColors
            \.$monochrome
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let existing = try existingTheme(theme)
        let edit = ThemeEdit(
            name: name,
            backgroundColor: backgroundColor,
            backgroundColor2: backgroundColor2,
            labelColor: labelColor,
            buttonColors: buttonColors,
            monochrome: monochrome
        )
        let updated = try edit.applying(to: existing)
        BoardThemeStore.shared.update(updated)
        return .result(value: ThemeAppEntity(updated))
    }
}
