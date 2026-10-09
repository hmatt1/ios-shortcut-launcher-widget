import SwiftUI

@main
struct LauncherBoardApp: App {
    @AppStorage("lastEditedPresetId", store: AppGroup.defaults)
    private var lastEditedPresetId: String = ""

    var body: some Scene {
        WindowGroup {
            PresetEditorWrapper(lastEditedId: $lastEditedPresetId)
        }
    }
}

struct PresetEditorWrapper: View {
    @Binding var lastEditedId: String
    @State private var showingPresets = false
    @ObservedObject private var store = BoardPresetStore.shared
    @Environment(\.scenePhase) private var scenePhase

    /// The preset the editor shows. Follows the store, so a preset deleted by
    /// a Shortcuts action moves the editor to a real one instead of a ghost.
    /// Falls back to a random UUID rather than force-unwrapping - the editor
    /// resolves any id it can't find the same safe way loadPreset(id:) does.
    private var presetId: UUID {
        PresetSelection.effectiveId(requested: UUID(uuidString: lastEditedId), in: store.presets) ?? UUID()
    }

    var body: some View {
        let currentId = presetId
        PresetEditorView(presetId: currentId) {
            showingPresets = true
        }
        .id(currentId.uuidString) // Force recreate when switching presets
        .sidePanel(edge: .leading, isPresented: $showingPresets) {
            PresetListView(selectedId: $lastEditedId, isPresented: $showingPresets)
        }
        .onChange(of: currentId) { _, newId in
            if lastEditedId != newId.uuidString { lastEditedId = newId.uuidString }
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app: adopt anything saved while it was away.
            guard phase == .active else { return }
            BoardPresetStore.shared.reloadFromDisk()
            BoardThemeStore.shared.reloadFromDisk()
            WallpaperStore.shared.refreshFromDisk()
        }
    }
}
