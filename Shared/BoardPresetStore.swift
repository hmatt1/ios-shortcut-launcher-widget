import Foundation
import SwiftUI
import WidgetKit

public struct DensityTemplate: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let layout: BoardLayoutValues
}

extension DensityTemplate {
    public static let all: [DensityTemplate] = [
        DensityTemplate(id: "edge", name: "Edge", layout: BoardLayoutValues(columns: 0, marginX: 0, marginY: 0, spacingX: 0, spacingY: 0, paddingX: 12, paddingY: 12, cornerRadius: 8)),
        DensityTemplate(id: "tight", name: "Tight", layout: BoardLayoutValues(columns: 0, marginX: 2, marginY: 2, spacingX: 2, spacingY: 2, paddingX: 12, paddingY: 12, cornerRadius: 10)),
        DensityTemplate(id: "snug", name: "Snug", layout: BoardLayoutValues(columns: 0, marginX: 4, marginY: 4, spacingX: 4, spacingY: 4, paddingX: 12, paddingY: 12, cornerRadius: 12)),
        DensityTemplate(id: "compact", name: "Compact", layout: BoardLayoutValues(columns: 0, marginX: 4, marginY: 4, spacingX: 8, spacingY: 8, paddingX: 12, paddingY: 12, cornerRadius: 14)),
        DensityTemplate(id: "balanced", name: "Balanced", layout: BoardLayoutValues(columns: 0, marginX: 8, marginY: 8, spacingX: 8, spacingY: 8, paddingX: 12, paddingY: 12, cornerRadius: 16)),
        DensityTemplate(id: "airy", name: "Airy", layout: BoardLayoutValues(columns: 0, marginX: 8, marginY: 8, spacingX: 12, spacingY: 12, paddingX: 12, paddingY: 12, cornerRadius: 16)),
        DensityTemplate(id: "roomy", name: "Roomy", layout: BoardLayoutValues(columns: 0, marginX: 12, marginY: 12, spacingX: 12, spacingY: 12, paddingX: 12, paddingY: 12, cornerRadius: 18)),
        DensityTemplate(id: "spacious", name: "Spacious", layout: BoardLayoutValues(columns: 0, marginX: 16, marginY: 16, spacingX: 12, spacingY: 12, paddingX: 12, paddingY: 12, cornerRadius: 20)),
        DensityTemplate(id: "open", name: "Open", layout: BoardLayoutValues(columns: 0, marginX: 16, marginY: 16, spacingX: 16, spacingY: 16, paddingX: 12, paddingY: 12, cornerRadius: 22)),
        DensityTemplate(id: "floating", name: "Floating", layout: BoardLayoutValues(columns: 0, marginX: 20, marginY: 20, spacingX: 16, spacingY: 16, paddingX: 12, paddingY: 12, cornerRadius: 24))
    ]
}

@MainActor
public class BoardPresetStore: ObservableObject {
    public static let shared = BoardPresetStore()
    
    private let defaults = AppGroup.defaults
    private let key = "board_presets"
    
    @Published public private(set) var presets: [BoardPreset] = []
    
    private init() {
        presets = BoardPresetStore.loadRaw()
    }
    
    public static nonisolated func loadRaw() -> [BoardPreset] {
        guard let defaults = AppGroup.defaults,
              let data = defaults.data(forKey: "board_presets"),
              let loaded = try? JSONDecoder().decode([BoardPreset].self, from: data),
              !loaded.isEmpty else {
            return createDefaultPresets()
        }
        
        return loaded
    }
    
    public static nonisolated func loadPreset(id: UUID) -> BoardPreset {
        let all = loadRaw()
        return all.first { $0.id == id } ?? all.first ?? createDefaultPresets().first!
    }
    
    private func load() {
        presets = BoardPresetStore.loadRaw()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(presets) {
            defaults?.set(encoded, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    public static nonisolated func createDefaultPresets() -> [BoardPreset] {
        let template = DensityTemplate.all.first { $0.id == "compact" } ?? DensityTemplate.all[0]
        let stableId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        return [
            BoardPreset(
                id: stableId,
                name: "Default Preset",
                columns: template.layout.columns,
                marginX: template.layout.marginX,
                marginY: template.layout.marginY,
                spacingX: template.layout.spacingX,
                spacingY: template.layout.spacingY,
                paddingX: template.layout.paddingX,
                paddingY: template.layout.paddingY,
                cornerRadius: template.layout.cornerRadius,
                themeId: BoardThemeStore.createDefaultThemes().first(where: { t in t.name == "Midnight" })!.id,
                background: .theme
            )
        ]
    }
    
    public func create(name: String) -> BoardPreset {
        let template = DensityTemplate.all.first { $0.id == "compact" }!.layout
        let newPreset = BoardPreset(
            id: UUID(),
            name: name,
            columns: template.columns,
            marginX: template.marginX,
            marginY: template.marginY,
            spacingX: template.spacingX,
            spacingY: template.spacingY,
            paddingX: template.paddingX,
            paddingY: template.paddingY,
            cornerRadius: template.cornerRadius,
            themeId: BoardThemeStore.createDefaultThemes().first(where: { t in t.name == "Midnight" })!.id,
            background: .theme
        )
        presets.append(newPreset)
        save()
        return newPreset
    }
    
    public func duplicate(id: UUID) {
        guard let existing = presets.first(where: { $0.id == id }) else { return }
        let newPreset = BoardPreset(
            id: UUID(),
            name: existing.name + " Copy",
            columns: existing.columns,
            marginX: existing.marginX,
            marginY: existing.marginY,
            spacingX: existing.spacingX,
            spacingY: existing.spacingY,
            paddingX: existing.paddingX,
            paddingY: existing.paddingY,
            cornerRadius: existing.cornerRadius,
            outerCornerRadius: existing.outerCornerRadius,
            themeId: existing.themeId,
            background: existing.background,
            frostedGlass: existing.frostedGlass
        )
        if let index = presets.firstIndex(where: { $0.id == id }) {
            presets.insert(newPreset, at: index + 1)
        } else {
            presets.append(newPreset)
        }
        save()
    }
    
    public func update(_ preset: BoardPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        save()
    }
    
    public func delete(id: UUID) {
        guard presets.count > 1 else { return }
        presets.removeAll { $0.id == id }
        save()
    }
    
    public func reorder(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
