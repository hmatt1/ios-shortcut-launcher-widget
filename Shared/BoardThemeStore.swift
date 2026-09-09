import Foundation
import SwiftUI
import WidgetKit

@MainActor
public class BoardThemeStore: ObservableObject {
    public static let shared = BoardThemeStore()
    
    private let defaults = AppGroup.defaults
    private let key = "board_themes"
    
    @Published public private(set) var themes: [BoardTheme] = []
    
    private init() {
        themes = BoardThemeStore.loadRaw()
    }
    
    public static nonisolated func loadRaw() -> [BoardTheme] {
        guard let defaults = AppGroup.defaults,
              let data = defaults.data(forKey: "board_themes"),
              let loaded = try? JSONDecoder().decode([BoardTheme].self, from: data),
              !loaded.isEmpty else {
            return createDefaultThemes()
        }
        return loaded
    }
    
    public static nonisolated func loadTheme(id: UUID) -> BoardTheme {
        let all = loadRaw()
        return all.first { $0.id == id } ?? all.first ?? createDefaultThemes().first!
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(themes) {
            defaults?.set(encoded, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    public static nonisolated func createDefaultThemes() -> [BoardTheme] {
        return Theme.allCases.enumerated().map { index, theme in
            let stableId = UUID(uuidString: "11111111-1111-1111-1111-\(String(format: "%012x", index))")!
            return BoardTheme(
                id: stableId,
                name: theme.displayName,
                spec: theme.spec
            )
        }
    }
    
    public func create(name: String) -> BoardTheme {
        let newTheme = BoardTheme(
            id: UUID(),
            name: name,
            spec: Theme.midnight.spec
        )
        themes.append(newTheme)
        save()
        return newTheme
    }
    
    public func duplicate(id: UUID) {
        guard let existing = themes.first(where: { $0.id == id }) else { return }
        let newTheme = BoardTheme(
            id: UUID(),
            name: existing.name + " Copy",
            spec: existing.spec
        )
        if let index = themes.firstIndex(where: { $0.id == id }) {
            themes.insert(newTheme, at: index + 1)
        } else {
            themes.append(newTheme)
        }
        save()
    }
    
    public func update(_ theme: BoardTheme) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index] = theme
        save()
    }

    /// Adds any built-in theme whose exact colors aren't already in the list.
    /// Never overwrites or deletes: an edited built-in is left as-is and the
    /// original is appended as a new theme, named "<Name> (Original)" when the
    /// plain name is already taken.
    public func restoreDefaultThemes() {
        for defaultTheme in BoardThemeStore.createDefaultThemes() {
            if themes.contains(where: { $0.spec == defaultTheme.spec }) { continue }
            // Reuse the built-in's stable id only when nothing holds it (it was
            // deleted, not edited), so presets pointing at it reconnect.
            let idTaken = themes.contains(where: { $0.id == defaultTheme.id })
            let id = idTaken ? UUID() : defaultTheme.id
            themes.append(BoardTheme(id: id, name: availableName(for: defaultTheme.name), spec: defaultTheme.spec))
        }
        save()
    }

    /// Whether any built-in theme's colors are missing from the list — i.e.
    /// whether `restoreDefaultThemes()` would add anything.
    public var canRestoreDefaultThemes: Bool {
        BoardThemeStore.createDefaultThemes().contains { defaultTheme in
            !themes.contains { $0.spec == defaultTheme.spec }
        }
    }

    /// `base` if unused, otherwise `base (Original)`, then `base (Original 2)`, and so on.
    private func availableName(for base: String) -> String {
        let taken = Set(themes.map(\.name))
        if !taken.contains(base) { return base }
        let tagged = "\(base) (Original)"
        if !taken.contains(tagged) { return tagged }
        var n = 2
        while taken.contains("\(base) (Original \(n))") { n += 1 }
        return "\(base) (Original \(n))"
    }
    
    public func delete(id: UUID) {
        guard themes.count > 1 else { return }
        themes.removeAll { $0.id == id }
        save()
    }
    
    public func reorder(from source: IndexSet, to destination: Int) {
        themes.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
