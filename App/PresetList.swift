import SwiftUI

struct PresetListView: View {
    @ObservedObject var store = BoardPresetStore.shared
    @Binding var selectedId: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.presets) { preset in
                    Button {
                        selectedId = preset.id.uuidString
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(BoardThemeStore.loadTheme(id: preset.themeId).name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedId == preset.id.uuidString {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deletePreset(preset)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            store.duplicate(id: preset.id)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            store.duplicate(id: preset.id)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        
                        Button(role: .destructive) {
                            deletePreset(preset)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: store.reorder)

                if store.canRestoreDefaultPresets {
                    Section {
                        Button {
                            store.restoreDefaultPresets()
                        } label: {
                            Label("Restore Default Presets", systemImage: "arrow.counterclockwise")
                        }
                    } footer: {
                        Text("Adds the built-in presets back to the list. A preset you've edited is kept as-is and the original is re-added as a new preset, e.g. \"Default (Original)\".")
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let newPreset = store.create(name: "New Preset")
                        selectedId = newPreset.id.uuidString
                        isPresented = false
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func deletePreset(_ preset: BoardPreset) {
        store.delete(id: preset.id)
        if selectedId == preset.id.uuidString {
            selectedId = store.presets.first?.id.uuidString ?? ""
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let preset = store.presets[index]
                deletePreset(preset)
        }
    }
}
