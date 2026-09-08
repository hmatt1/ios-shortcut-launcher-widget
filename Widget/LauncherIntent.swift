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

/// Fourteen rows: twelve shortcuts and two looks. The number of assigned
/// shortcuts is the slot count, so no control can contradict another.
struct LauncherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Shortcut Launcher"

    static var description: IntentDescription {
        IntentDescription("Run your shortcuts from the Home Screen.")
    }

    @Parameter(title: "1")
    var shortcut1: SystemShortcut?

    @Parameter(title: "2")
    var shortcut2: SystemShortcut?

    @Parameter(title: "3")
    var shortcut3: SystemShortcut?

    @Parameter(title: "4")
    var shortcut4: SystemShortcut?

    @Parameter(title: "5")
    var shortcut5: SystemShortcut?

    @Parameter(title: "6")
    var shortcut6: SystemShortcut?

    @Parameter(title: "7")
    var shortcut7: SystemShortcut?

    @Parameter(title: "8")
    var shortcut8: SystemShortcut?

    @Parameter(title: "9")
    var shortcut9: SystemShortcut?

    @Parameter(title: "10")
    var shortcut10: SystemShortcut?

    @Parameter(title: "11")
    var shortcut11: SystemShortcut?

    @Parameter(title: "12")
    var shortcut12: SystemShortcut?

    @Parameter(title: "Preset")
    var preset: BoardPresetEntity?

    @Parameter(title: "Position (If Transparent)", default: .topLeft)
    var widgetPosition: WidgetPosition

    /// Assigned shortcuts in slot order, holes closed.
    var slots: [SystemShortcut] {
        let all: [SystemShortcut?] = [
            shortcut1,
            shortcut2,
            shortcut3,
            shortcut4,
            shortcut5,
            shortcut6,
            shortcut7,
            shortcut8,
            shortcut9,
            shortcut10,
            shortcut11,
            shortcut12
        ]
        return all.compactMap { $0 }
    }
}
