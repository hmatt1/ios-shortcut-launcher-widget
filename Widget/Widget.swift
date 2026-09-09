import Foundation
import AppIntents
import SwiftUI
import WidgetKit

struct LauncherEntry: TimelineEntry {
    let date: Date
    let configuration: LauncherIntent
    /// Names to draw instead of shortcuts. The gallery card and the redacted
    /// placeholder use it, because neither has a configuration to read.
    let sample: [String]
}

struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: Date(), configuration: LauncherIntent(), sample: BoardSample.names)
    }

    func snapshot(for configuration: LauncherIntent, in context: Context) async -> LauncherEntry {
        // The widget gallery asks for a snapshot before anything is configured.
        // Showing the empty state there would sell the widget as a blank card.
        let sample = context.isPreview && configuration.slots.isEmpty ? BoardSample.names : []
        return LauncherEntry(date: Date(), configuration: configuration, sample: sample)
    }

    func timeline(for configuration: LauncherIntent, in context: Context) async -> Timeline<LauncherEntry> {
        // The board only changes when the widget is edited, which reloads the
        // timeline anyway. One entry, never refreshed, spends no budget.
        let entry = LauncherEntry(date: Date(), configuration: configuration, sample: [])
        return Timeline(entries: [entry], policy: .never)
    }
}

extension BoardSize {
    init(family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        default: self = .large
        }
    }
}

struct DynamicWidgetBackground<Content: View>: View {
    let style: BackgroundStyle
    let spec: ThemeSpec
    let position: WidgetPosition
    let family: BoardSize
    let widgetContent: Content
    
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        let accented = renderingMode != .fullColor
        
        if accented {
            widgetContent
                .containerBackground(.background, for: .widget)
        } else {
            applySelectedTheme()
        }
    }

    @ViewBuilder
    func applySelectedTheme() -> some View {
        switch style {
        case .liquidGlass: // System Default
            widgetContent
                .containerBackground(.background, for: .widget)
        case .theme, .transparent, .glassTiles:
            widgetContent
                .background {
                    BoardBackground(
                        spec: spec,
                        accented: false,
                        style: style,
                        position: position,
                        family: family
                    )
                }
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
    }
}

struct LauncherWidgetView: View {
    let entry: LauncherEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let size = BoardSize(family: family)
        // Anything that is not full colour gets the same stripped-back
        // treatment, so a future or Lock Screen mode never falls through.
        let accented = renderingMode != .fullColor
        let slots = entry.configuration.slots
        let sample = entry.sample
        let rawNames = sample.isEmpty
            ? slots.map { String(localized: $0.displayRepresentation.title) }
            : sample
        
        let presetId = entry.configuration.preset?.id ?? BoardPresetStore.loadRaw().first!.id
        let preset = BoardPresetStore.loadPreset(id: presetId)
        let layout = preset.layoutValues
        
        let resolved = BoardGrid.resolve(
            count: rawNames.count,
            size: size,
            longestName: rawNames.map(\.count).max() ?? 0,
            layout: layout
        )
        
        let grid = resolved.grid
        let names = Array(rawNames.prefix(resolved.visibleSlots))

        DynamicWidgetBackground(
            style: preset.background,
            spec: preset.activeSpec,
            position: entry.configuration.widgetPosition,
            family: size,
            widgetContent: Group {
                if names.isEmpty {
                    BoardEmptyState(spec: preset.activeSpec, accented: accented)
                } else {
                    BoardView(grid: grid, count: names.count) { index, col, row in
                        if sample.isEmpty {
                            Button(intent: RunSystemShortcutIntent(shortcut: slots[index])) {
                                face(name: names[index], index: index, col: col, row: row, grid: grid, accented: accented, spec: preset.activeSpec, style: preset.background)
                            }
                            .buttonStyle(.plain)
                        } else {
                            face(name: names[index], index: index, col: col, row: row, grid: grid, accented: accented, spec: preset.activeSpec, style: preset.background)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }

    private func face(name: String, index: Int, col: Int, row: Int, grid: BoardGrid, accented: Bool, spec: ThemeSpec, style: BackgroundStyle) -> SlotFace {
        return SlotFace(
            name: name,
            surface: spec.surface(at: index, accented: accented),
            label: spec.labelColor(at: index, accented: accented),
            mode: grid.mode,
            font: grid.font,
            paddingX: grid.layout.paddingX,
            paddingY: grid.layout.paddingY,
            topLeadingRadius: grid.topLeadingRadius(col: col, row: row),
            bottomLeadingRadius: grid.bottomLeadingRadius(col: col, row: row),
            bottomTrailingRadius: grid.bottomTrailingRadius(col: col, row: row),
            topTrailingRadius: grid.topTrailingRadius(col: col, row: row),
            style: style,
            accented: accented
        )
    }
}

@main
struct LauncherBoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LauncherBoard",
            intent: LauncherIntent.self,
            provider: LauncherProvider()
        ) { entry in
            LauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Shortcut Launcher")
        .description("Run your shortcuts from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
