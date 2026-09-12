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
    
    var body: some View {
        // Falls back to a random UUID rather than force-unwrapping the first
        // loaded preset - PresetEditorView's own init resolves any id it
        // can't find the same safe way loadPreset(id:) does.
        let presetId = UUID(uuidString: lastEditedId) ?? UUID()
        PresetEditorView(presetId: presetId) {
            showingPresets = true
        }
        .id(presetId.uuidString) // Force recreate when switching presets
        .sidePanel(edge: .leading, isPresented: $showingPresets) {
            PresetListView(selectedId: $lastEditedId, isPresented: $showingPresets)
        }
    }
}
