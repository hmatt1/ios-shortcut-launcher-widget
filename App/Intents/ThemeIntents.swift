import Foundation
import AppIntents
import WidgetKit

struct ThemeAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Theme")
    }

    static var defaultQuery = ThemeAppQuery()

    let id: UUID

    /// A property so a shortcut can read "Name" from each item Find Themes returns.
    @Property(title: "Name")
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ theme: BoardTheme) {
        self.id = theme.id
        self.name = theme.name
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
        IntentDescription("Adds a new theme, starting from the Midnight colors.")
    }

    @Parameter(title: "Name", default: "New Theme")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let created = BoardThemeStore.shared.create(name: trimmed.isEmpty ? "New Theme" : trimmed)
        return .result(value: ThemeAppEntity(created))
    }
}

struct DuplicateThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Duplicate Theme"
    static var description: IntentDescription {
        IntentDescription("Copies a theme and its colors.")
    }

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let original = try existingTheme(theme)
        let store = BoardThemeStore.shared
        store.duplicate(id: original.id)
        guard let index = store.themes.firstIndex(where: { $0.id == original.id }),
              store.themes.indices.contains(index + 1) else {
            throw ThemeIntentError.themeNotFound
        }
        return .result(value: ThemeAppEntity(store.themes[index + 1]))
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
/// are `#RRGGBB` text.
struct UpdateThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Theme"
    static var description: IntentDescription {
        IntentDescription("Changes a theme's name or colors. Colors are six hex digits, like #1A2B3C. Only the fields you fill in change.")
    }

    @Parameter(title: "Theme")
    var theme: ThemeAppEntity

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Button Colors (empty list = monochrome)")
    var accents: [String]?

    @Parameter(title: "Background (1 flat, 2 gradient)")
    var background: [String]?

    @Parameter(title: "Label Color")
    var label: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ThemeAppEntity> {
        let existing = try existingTheme(theme)
        let edit = ThemeEdit(name: name, accents: accents, background: background, label: label)
        let updated = try edit.applying(to: existing)
        BoardThemeStore.shared.update(updated)
        return .result(value: ThemeAppEntity(updated))
    }
}
