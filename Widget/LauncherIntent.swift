import Foundation
import AppIntents



extension WidgetPosition: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Widget Position")
    }

    static var caseDisplayRepresentations: [WidgetPosition: DisplayRepresentation] {
        [
            .topLeft: DisplayRepresentation(title: "Top Left"),
            .topRight: DisplayRepresentation(title: "Top Right"),
            .middleLeft: DisplayRepresentation(title: "Middle Left"),
            .middleRight: DisplayRepresentation(title: "Middle Right"),
            .bottomLeft: DisplayRepresentation(title: "Bottom Left"),
            .bottomRight: DisplayRepresentation(title: "Bottom Right"),
            .top: DisplayRepresentation(title: "Top"),
            .middle: DisplayRepresentation(title: "Middle"),
            .bottom: DisplayRepresentation(title: "Bottom")
        ]
    }
}

struct BoardPresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Preset")
    }

    static var defaultQuery = BoardPresetQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct BoardPresetQuery: EntityQuery {
    func entities(for identifiers: [BoardPresetEntity.ID]) async throws -> [BoardPresetEntity] {
        let presets = BoardPresetStore.loadRaw()
        return presets.filter { identifiers.contains($0.id) }.map { BoardPresetEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [BoardPresetEntity] {
        BoardPresetStore.loadRaw().map { BoardPresetEntity(id: $0.id, name: $0.name) }
    }
    
    func defaultResult() async -> BoardPresetEntity? {
        let presets = BoardPresetStore.loadRaw()
        
        let defaults = AppGroup.defaults
        let lastId = defaults?.string(forKey: "lastEditedPresetId")
        
        if let lastId = lastId, let uuid = UUID(uuidString: lastId),
           let preset = presets.first(where: { $0.id == uuid }) {
            return BoardPresetEntity(id: preset.id, name: preset.name)
        }
        
        if let first = presets.first {
            return BoardPresetEntity(id: first.id, name: first.name)
        }
        return nil
    }
}

/// Three rows: a preset, a transparent-blend position, and one multi-select
/// list of shortcuts. The list is a single parameter, so it is not bound by the
/// old one-row-per-shortcut ceiling; a widget shows as many as its family can
/// fit, up to `BoardGrid.maxSlots`. The number of chosen shortcuts is the slot
/// count, so no control can contradict another.
struct LauncherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Shortcut Launcher"

    static var description: IntentDescription {
        IntentDescription("Run your shortcuts from the Home Screen.")
    }

    @Parameter(title: "Preset")
    var preset: BoardPresetEntity?

    @Parameter(title: "Position (If Transparent)", default: .topLeft)
    var widgetPosition: WidgetPosition

    @Parameter(title: "Shortcuts")
    var shortcuts: [SystemShortcut] = []

    /// Chosen shortcuts in order, capped at what any board can show.
    var slots: [SystemShortcut] {
        Array(shortcuts.prefix(BoardGrid.maxSlots))
    }
}
