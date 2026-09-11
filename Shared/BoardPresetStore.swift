import Foundation
import CoreGraphics
import SwiftUI
import WidgetKit

public struct DensityTemplate: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let layout: BoardLayoutValues
}

extension DensityTemplate {
    /// Five steps on one "breathing room" axis: margin, spacing, padding and
    /// corner radius all move together, so one tap gives a complete, coherent
    /// look rather than a grab-bag of independent sliders.
    ///
    /// `BoardGrid.resolve` degrades spacing, then margin, but can never claw
    /// back padding — so padding is kept the smallest gap-like value and only
    /// climbs (8 -> 12) once the tighter steps' 8pt legibility floor is behind
    /// it, instead of sitting at a flat 12 that starved every tight board.
    /// Inner radius is capped at 15 so no step turns a small widget's tiles
    /// into pills (the old ladder ran to 24); outer radius is a constant 22 —
    /// the iOS widget's own container corner — so a board's outer tiles fuse
    /// into the system mask at every step. Margin never falls below spacing,
    /// on an even ladder (margin +4, spacing +3 per step), so "breathing room"
    /// grows in one legible direction. Columns are left at 0 (auto) in every
    /// step; only individual presets pin a column count.
    public static let all: [DensityTemplate] = [
        DensityTemplate(id: "flush", name: "Flush", layout: BoardLayoutValues(columns: 0, marginX: 0, marginY: 0, spacingX: 0, spacingY: 0, paddingX: 8, paddingY: 8, cornerRadius: 4, outerCornerRadius: 22)),
        DensityTemplate(id: "hairline", name: "Hairline", layout: BoardLayoutValues(columns: 0, marginX: 4, marginY: 4, spacingX: 3, spacingY: 3, paddingX: 8, paddingY: 8, cornerRadius: 7, outerCornerRadius: 22)),
        DensityTemplate(id: "standard", name: "Standard", layout: BoardLayoutValues(columns: 0, marginX: 8, marginY: 8, spacingX: 6, spacingY: 6, paddingX: 10, paddingY: 10, cornerRadius: 10, outerCornerRadius: 22)),
        DensityTemplate(id: "relaxed", name: "Relaxed", layout: BoardLayoutValues(columns: 0, marginX: 12, marginY: 12, spacingX: 9, spacingY: 9, paddingX: 12, paddingY: 12, cornerRadius: 13, outerCornerRadius: 22)),
        DensityTemplate(id: "open", name: "Open", layout: BoardLayoutValues(columns: 0, marginX: 16, marginY: 16, spacingX: 12, spacingY: 12, paddingX: 12, paddingY: 12, cornerRadius: 15, outerCornerRadius: 22))
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
    
    /// Ten showcase presets, named by look rather than by theme, but chosen so
    /// every one of the 10 default themes, all 5 density steps, both the Solid
    /// and System Default backgrounds, an edge-to-edge board and a single-
    /// column list all appear at least once — the set doubles as a tour of the
    /// app. Order is load-bearing: ids are derived from index, so entries must
    /// only ever be appended.
    public static nonisolated func createDefaultPresets() -> [BoardPreset] {
        let steps = Dictionary(uniqueKeysWithValues: DensityTemplate.all.map { ($0.id, $0.layout) })
        let themeIds = Dictionary(uniqueKeysWithValues: BoardThemeStore.createDefaultThemes().map { ($0.name, $0.id) })

        struct Showcase {
            let name: String
            let theme: String
            let step: String
            let columns: Int
            let background: BackgroundStyle
            /// Overrides the step's inner corner radius; nil keeps the step's value.
            let cornerOverride: CGFloat?
        }

        let showcases: [Showcase] = [
            Showcase(name: "Default", theme: "Midnight", step: "standard", columns: 0, background: .theme, cornerOverride: nil),
            Showcase(name: "Slate", theme: "Ink", step: "flush", columns: 0, background: .theme, cornerOverride: 0),
            Showcase(name: "Grid", theme: "Frost", step: "hairline", columns: 0, background: .liquidGlass, cornerOverride: nil),
            Showcase(name: "Panel", theme: "Aurora", step: "relaxed", columns: 0, background: .theme, cornerOverride: nil),
            Showcase(name: "Keypad", theme: "Sunset", step: "standard", columns: 0, background: .theme, cornerOverride: nil),
            Showcase(name: "Console", theme: "Ember", step: "hairline", columns: 0, background: .theme, cornerOverride: nil),
            Showcase(name: "Notes", theme: "Paper", step: "open", columns: 1, background: .theme, cornerOverride: 4),
            Showcase(name: "Directory", theme: "Sandstone", step: "relaxed", columns: 0, background: .liquidGlass, cornerOverride: nil),
            Showcase(name: "Field", theme: "Meadow", step: "open", columns: 0, background: .liquidGlass, cornerOverride: nil),
            Showcase(name: "Quiet", theme: "Nocturne", step: "standard", columns: 0, background: .theme, cornerOverride: nil)
        ]

        return showcases.enumerated().map { index, showcase in
            let layout = steps[showcase.step]!
            return BoardPreset(
                id: UUID(uuidString: "22222222-2222-2222-2222-\(String(format: "%012x", index))")!,
                name: showcase.name,
                columns: showcase.columns,
                marginX: layout.marginX,
                marginY: layout.marginY,
                spacingX: layout.spacingX,
                spacingY: layout.spacingY,
                paddingX: layout.paddingX,
                paddingY: layout.paddingY,
                cornerRadius: showcase.cornerOverride ?? layout.cornerRadius,
                outerCornerRadius: layout.outerCornerRadius,
                themeId: themeIds[showcase.theme]!,
                background: showcase.background
            )
        }
    }

    public func create(name: String) -> BoardPreset {
        let template = DensityTemplate.all.first { $0.id == "standard" }!.layout
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
            outerCornerRadius: template.outerCornerRadius,
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
            background: existing.background
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

    /// Adds any built-in preset whose exact look isn't already in the list.
    /// Never overwrites or deletes: an edited built-in is left as-is and the
    /// original is appended as a new preset, named "<Name> (Original)" when the
    /// plain name is already taken. Mirrors `BoardThemeStore.restoreDefaultThemes()`.
    public func restoreDefaultPresets() {
        for defaultPreset in BoardPresetStore.createDefaultPresets() {
            if presets.contains(where: { samePreset($0, defaultPreset) }) { continue }
            // Reuse the built-in's stable id only when nothing holds it (it was
            // deleted, not edited), so widgets/config pointing at it reconnect.
            let idTaken = presets.contains(where: { $0.id == defaultPreset.id })
            let id = idTaken ? UUID() : defaultPreset.id
            presets.append(BoardPreset(
                id: id,
                name: availableName(for: defaultPreset.name),
                columns: defaultPreset.columns,
                marginX: defaultPreset.marginX,
                marginY: defaultPreset.marginY,
                spacingX: defaultPreset.spacingX,
                spacingY: defaultPreset.spacingY,
                paddingX: defaultPreset.paddingX,
                paddingY: defaultPreset.paddingY,
                cornerRadius: defaultPreset.cornerRadius,
                outerCornerRadius: defaultPreset.outerCornerRadius,
                themeId: defaultPreset.themeId,
                background: defaultPreset.background
            ))
        }
        save()
    }

    /// Whether any built-in preset's exact look is missing from the list — i.e.
    /// whether `restoreDefaultPresets()` would add anything.
    public var canRestoreDefaultPresets: Bool {
        BoardPresetStore.createDefaultPresets().contains { defaultPreset in
            !presets.contains { samePreset($0, defaultPreset) }
        }
    }

    /// Two presets are the "same" for restore purposes when every value that
    /// determines how the board looks matches — id and name don't count.
    private func samePreset(_ a: BoardPreset, _ b: BoardPreset) -> Bool {
        a.columns == b.columns
            && a.marginX == b.marginX && a.marginY == b.marginY
            && a.spacingX == b.spacingX && a.spacingY == b.spacingY
            && a.paddingX == b.paddingX && a.paddingY == b.paddingY
            && a.cornerRadius == b.cornerRadius && a.outerCornerRadius == b.outerCornerRadius
            && a.themeId == b.themeId && a.background == b.background
    }

    /// `base` if unused, otherwise `base (Original)`, then `base (Original 2)`, and so on.
    private func availableName(for base: String) -> String {
        let taken = Set(presets.map(\.name))
        if !taken.contains(base) { return base }
        let tagged = "\(base) (Original)"
        if !taken.contains(tagged) { return tagged }
        var n = 2
        while taken.contains("\(base) (Original \(n))") { n += 1 }
        return "\(base) (Original \(n))"
    }
}
