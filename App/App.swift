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
        let presetId = UUID(uuidString: lastEditedId) ?? BoardPresetStore.loadRaw().first!.id
        PresetEditorView(presetId: presetId) {
            showingPresets = true
        }
        .id(presetId.uuidString) // Force recreate when switching presets
        .sidePanel(edge: .leading, isPresented: $showingPresets) {
            PresetListView(selectedId: $lastEditedId, isPresented: $showingPresets)
        }
    }
}
