import SwiftUI
import WidgetKit
import PhotosUI

struct CustomStepper<V: Strideable & Comparable>: View where V.Stride: SignedNumeric {
    let title: String
    @Binding var value: V
    let range: ClosedRange<V>
    let step: V.Stride
    let stringValue: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                let newValue = value.advanced(by: -step)
                if newValue >= range.lowerBound {
                    value = newValue
                } else {
                    value = range.lowerBound
                }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.borderless)
            
            Text(stringValue)
                .font(.body.monospacedDigit())
                .frame(minWidth: 36, alignment: .center)
            
            Button {
                let newValue = value.advanced(by: step)
                if newValue <= range.upperBound {
                    value = newValue
                } else {
                    value = range.upperBound
                }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct PresetEditorView: View {
    let presetId: UUID
    @ObservedObject var store = BoardPresetStore.shared
    
    @State private var size: BoardSize = .medium
    @State private var slots: Int = 4
    
    @State private var preset: BoardPreset
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var widgetPosition: WidgetPosition = .topLeft
    
    @ObservedObject private var wallpaperStore = WallpaperStore.shared
    @ObservedObject private var themeStore = BoardThemeStore.shared
    @State private var showingThemeList = false
    
    var onShowPresets: () -> Void
    
    init(presetId: UUID, onShowPresets: @escaping () -> Void = {}) {
        self.presetId = presetId
        self.onShowPresets = onShowPresets
        let p = BoardPresetStore.shared.presets.first(where: { $0.id == presetId }) ?? BoardPresetStore.loadRaw().first!
        _preset = State(initialValue: p)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                boardView
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.canvas.height + 60)
            .animation(.spring(), value: size)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .overlay(alignment: .bottomLeading) {
                Button(action: onShowPresets) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showingThemeList = true }) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 8)
            }
                Form {
                    Section("Preset") {
                        TextField("Preset Name", text: $preset.name)
                            .submitLabel(.done)
                    }
                    
                    Section("Preview") {
                        Picker("Size", selection: $size) {
                            Text("S").tag(BoardSize.small)
                            Text("M").tag(BoardSize.medium)
                            Text("L").tag(BoardSize.large)
                            Text("XL").tag(BoardSize.extraLarge)
                        }
                        .pickerStyle(.segmented)
                        
                        CustomStepper(title: "Preview Slots", value: $slots, range: 1...12, step: 1, stringValue: "\(slots)")
                    }
                    
                    Section("Layout") {
                        Menu {
                            ForEach(DensityTemplate.all) { template in
                                Button(template.name) {
                                    applyTemplate(template)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Density Template")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(currentTemplateName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .imageScale(.small)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        CustomStepper(title: "Columns", value: $preset.columns, range: 0...12, step: 1, stringValue: preset.columns == 0 ? "Auto" : "\(preset.columns)")
                        
                        CustomStepper(title: "Margin X", value: $preset.marginX, range: 0...40, step: 1, stringValue: "\(Int(preset.marginX))")
                        CustomStepper(title: "Margin Y", value: $preset.marginY, range: 0...40, step: 1, stringValue: "\(Int(preset.marginY))")
                        CustomStepper(title: "Spacing X", value: $preset.spacingX, range: 0...40, step: 1, stringValue: "\(Int(preset.spacingX))")
                        CustomStepper(title: "Spacing Y", value: $preset.spacingY, range: 0...40, step: 1, stringValue: "\(Int(preset.spacingY))")
                        CustomStepper(title: "Padding X", value: $preset.paddingX, range: 0...40, step: 1, stringValue: "\(Int(preset.paddingX))")
                        CustomStepper(title: "Padding Y", value: $preset.paddingY, range: 0...40, step: 1, stringValue: "\(Int(preset.paddingY))")
                        CustomStepper(title: "Inner Corners", value: $preset.cornerRadius, range: 0...32, step: 1, stringValue: "\(Int(preset.cornerRadius))")
                        CustomStepper(title: "Outer Corners", value: $preset.outerCornerRadius, range: 0...32, step: 1, stringValue: "\(Int(preset.outerCornerRadius))")
                    }
                    
                    Section("Background") {
                        Picker("Style", selection: $preset.background) {
                            ForEach(BackgroundStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if preset.background == .transparent || preset.background == .glassTiles {
                            PhotosPicker(selection: $wallpaperItem, matching: .images) {
                                HStack {
                                    Text("Upload Wallpaper")
                                    Spacer()
                                    if wallpaperStore.image != nil {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    }
                                }
                            }
                            .onChange(of: wallpaperItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        await MainActor.run {
                                            wallpaperStore.save(image: uiImage, screenBounds: UIScreen.main.bounds.size)
                                            WidgetCenter.shared.reloadAllTimelines()
                                        }
                                    }
                                }
                            }
                            
                            Picker("Widget Position", selection: $widgetPosition) {
                                ForEach(WidgetPosition.allCases, id: \.self) { pos in
                                    Text(pos.displayName).tag(pos)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Section("Colors (Editing \(themeStore.themes.first(where: { $0.id == preset.themeId })?.name ?? "Theme"))") {
                        let spec = preset.activeSpec
                        
                        TextField("Theme Name", text: Binding(
                            get: { themeStore.themes.first(where: { $0.id == preset.themeId })?.name ?? "Theme" },
                            set: { newName in
                                if var theme = themeStore.themes.first(where: { $0.id == preset.themeId }) {
                                    theme.name = newName
                                    themeStore.update(theme)
                                }
                            }
                        ))
                        .submitLabel(.done)

                        ColorPicker("Background 1", selection: Binding(
                            get: { spec.background.first?.color ?? .black },
                            set: { updateActiveTheme { $0.background[0].color = $1 }($0) }
                        ))
                        
                        ColorPicker("Background 2", selection: Binding(
                            get: { spec.background.count > 1 ? spec.background[1].color : spec.background.first?.color ?? .black },
                            set: { newValue in
                                updateActiveTheme { spec, color in
                                    if spec.background.count < 2 {
                                        spec.background.append(RGB(red: 0, green: 0, blue: 0))
                                    }
                                    spec.background[1].color = color
                                }(newValue)
                            }
                        ))
                        
                        ColorPicker("All Labels", selection: Binding(
                            get: { spec.labels.first?.color ?? .white },
                            set: { newValue in
                                updateActiveTheme { spec, color in
                                    if spec.labels.isEmpty {
                                        spec.labels = Array(repeating: RGB(0xFFFFFF), count: 12)
                                    } else {
                                        while spec.labels.count < 12 {
                                            spec.labels.append(spec.labels[0])
                                        }
                                    }
                                    for i in 0..<12 {
                                        spec.labels[i].color = color
                                    }
                                }(newValue)
                            }
                        ))
                        
                        ColorPicker("All Shortcuts", selection: Binding(
                            get: { spec.accents.first?.color ?? spec.labels.first?.color ?? .white },
                            set: { newValue in
                                updateActiveTheme { spec, color in
                                    if spec.accents.isEmpty {
                                        let fallback = spec.labels.first ?? RGB(0xFFFFFF)
                                        spec.accents = Array(repeating: fallback, count: 12)
                                    } else {
                                        while spec.accents.count < 12 {
                                            spec.accents.append(spec.accents[0])
                                        }
                                    }
                                    for i in 0..<12 {
                                        spec.accents[i].color = color
                                    }
                                }(newValue)
                            }
                        ))
                        
                        ForEach(0..<12, id: \.self) { index in
                            ColorPicker("Label \(index + 1)", selection: Binding(
                                get: {
                                    if spec.labels.isEmpty { return .white }
                                    return spec.labels[index % spec.labels.count].color
                                },
                                set: { newValue in
                                    updateActiveTheme { spec, color in
                                        if spec.labels.isEmpty {
                                            spec.labels = Array(repeating: RGB(0xFFFFFF), count: 12)
                                        } else {
                                            while spec.labels.count < 12 {
                                                spec.labels.append(spec.labels[spec.labels.count % spec.labels.count])
                                            }
                                        }
                                        spec.labels[index].color = color
                                    }(newValue)
                                }
                            ))
                            
                            ColorPicker("Shortcut \(index + 1)", selection: Binding(
                                get: {
                                    if spec.accents.isEmpty { return spec.labels.first?.color ?? .white }
                                    return spec.accents[index % spec.accents.count].color
                                },
                                set: { newValue in
                                    updateActiveTheme { spec, color in
                                        if spec.accents.isEmpty {
                                            let fallback = spec.labels.first ?? RGB(0xFFFFFF)
                                            spec.accents = Array(repeating: fallback, count: 12)
                                        } else {
                                            while spec.accents.count < 12 {
                                                spec.accents.append(spec.accents[spec.accents.count % spec.accents.count])
                                            }
                                        }
                                        spec.accents[index].color = color
                                    }(newValue)
                                }
                            ))
                        }
                    }
                    
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)
                .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
                .scrollDismissesKeyboard(.interactively)
        }
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingThemeList) {
            ThemeListView(selectedId: Binding(
                get: { preset.themeId.uuidString },
                set: { if let uuid = UUID(uuidString: $0) { preset.themeId = uuid } }
            ), isPresented: $showingThemeList)
        }
        .onChange(of: preset) { _, newPreset in
            store.update(newPreset)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func updateActiveTheme(_ mutator: @escaping (inout ThemeSpec, Color) -> Void) -> (Color) -> Void {
        return { color in
            guard var theme = themeStore.themes.first(where: { $0.id == preset.themeId }) else { return }
            mutator(&theme.spec, color)
            themeStore.update(theme)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private var currentTemplateName: String {
        for template in DensityTemplate.all {
            if preset.marginX == template.layout.marginX &&
               preset.marginY == template.layout.marginY &&
               preset.spacingX == template.layout.spacingX &&
               preset.spacingY == template.layout.spacingY &&
               preset.paddingX == template.layout.paddingX &&
               preset.paddingY == template.layout.paddingY &&
               preset.cornerRadius == template.layout.cornerRadius {
                return template.name
            }
        }
        return "Custom"
    }
    
    private func applyTemplate(_ template: DensityTemplate) {
        preset.marginX = template.layout.marginX
        preset.marginY = template.layout.marginY
        preset.spacingX = template.layout.spacingX
        preset.spacingY = template.layout.spacingY
        preset.paddingX = template.layout.paddingX
        preset.paddingY = template.layout.paddingY
        preset.cornerRadius = template.layout.cornerRadius
    }
    
    private var boardView: some View {
        let rawNames = (0..<slots).map { BoardSample.names[$0 % BoardSample.names.count] }
        let layout = preset.layoutValues
        
        let resolved = BoardGrid.resolve(
            count: slots,
            size: size,
            longestName: rawNames.map(\.count).max() ?? 0,
            layout: layout
        )
        let grid = resolved.grid
        let names = Array(rawNames.prefix(resolved.visibleSlots))
        
        return BoardView(grid: grid, count: names.count) { index, col, row in
            SlotFace(
                name: names[index],
                surface: preset.activeSpec.surface(at: index, accented: false),
                label: preset.activeSpec.labelColor(at: index, accented: false),
                mode: grid.mode,
                font: grid.font,
                paddingX: grid.layout.paddingX,
                paddingY: grid.layout.paddingY,
                topLeadingRadius: grid.topLeadingRadius(col: col, row: row),
                bottomLeadingRadius: grid.bottomLeadingRadius(col: col, row: row),
                bottomTrailingRadius: grid.bottomTrailingRadius(col: col, row: row),
                topTrailingRadius: grid.topTrailingRadius(col: col, row: row),
                style: preset.background,
                accented: false
            )
        }
        .frame(width: size.canvas.width, height: size.canvas.height)
        .background { 
            PreviewBackground(
                style: preset.background,
                spec: preset.activeSpec,
                position: widgetPosition,
                family: size,
                wallpaper: WallpaperStore.getWallpaper()
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }
    
    private func themeIcon(_ theme: Theme) -> some View {
        let colors = theme.spec.background
        return Group {
            if colors.count >= 2 {
                LinearGradient(colors: colors.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if let first = colors.first {
                first.color
            } else {
                Color.clear
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}
