import SwiftUI

extension ThemeSpec {
    /// Tile fill. In accented mode the system keeps the opacity of translucent
    /// content and tints it, so a faint chip is what preserves the board's
    /// structure once the color is taken away.
    ///
    /// Monochrome themes (Ink, Paper — `accents` empty) reuse that same faint
    /// chip in full color too: a deliberate ~1.2-1.3:1 tint against the
    /// background, not a legibility target like the chromatic themes' accents.
    /// At `Flush` density the corner notch between tiles carries the boundary
    /// (see the README's "Rendering" section); at roomier densities the
    /// margin/spacing gap does. `Tools/verify-layout.py`'s contrast checks are
    /// scoped to chromatic themes for this reason, not because monochrome was
    /// overlooked.
    func surface(at index: Int, accented: Bool) -> Color {
        if accented {
            return .white.opacity(0.18)
        }
        guard !accents.isEmpty else {
            return labels.first?.color.opacity(0.12) ?? .white.opacity(0.12)
        }
        return accents[index % accents.count].color
    }

    /// iOS tints primary content white in accented mode, so naming white
    /// directly matches the device and keeps the in-app preview honest.
    /// `.primary` would follow the app's light or dark appearance instead.
    func labelColor(at index: Int, accented: Bool) -> Color {
        if accented { return .white }
        if labels.isEmpty { return .white }
        return labels[index % labels.count].color
    }
}

/// One tile. The name is the shortcut's own name, so it is always the truth.
struct SlotFace: View {
    let name: String
    let surface: Color
    let label: Color
    let mode: TileMode
    let font: Font
    let paddingX: CGFloat
    let paddingY: CGFloat
    let topLeadingRadius: CGFloat
    let bottomLeadingRadius: CGFloat
    let bottomTrailingRadius: CGFloat
    let topTrailingRadius: CGFloat

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: topLeadingRadius,
            bottomLeadingRadius: bottomLeadingRadius,
            bottomTrailingRadius: bottomTrailingRadius,
            topTrailingRadius: topTrailingRadius,
            style: .continuous
        )
        
        Text(name)
            .font(font)
            .fontWeight(.semibold)
            .foregroundStyle(label)
            .lineLimit(mode.lineLimit)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(mode == .row ? .leading : .center)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .padding(.horizontal, paddingX)
            .padding(.vertical, paddingY)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: mode == .row ? .leading : .center
            )
            .background {
                shape
                    .fill(surface)
                    .padding(0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
    }
}

/// Rows of equal tiles. No measurement, no geometry reader.
struct BoardView<Tile: View>: View {
    let grid: BoardGrid
    let count: Int
    let tile: (Int, Int, Int) -> Tile

    init(grid: BoardGrid, count: Int, @ViewBuilder tile: @escaping (Int, Int, Int) -> Tile) {
        self.grid = grid
        self.count = count
        self.tile = tile
    }

    var body: some View {
        VStack(spacing: grid.layout.spacingY) {
            ForEach(0..<grid.rows, id: \.self) { row in
                HStack(spacing: grid.layout.spacingX) {
                    ForEach(0..<grid.columns, id: \.self) { column in
                        let index = row * grid.columns + column
                        if index < count {
                            tile(index, column, row)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, grid.layout.marginX)
        .padding(.vertical, grid.layout.marginY)
    }
}

/// Shown when no shortcut is assigned. Two words is the whole instruction,
/// so it gets the same type discipline as a tile: this is the only thing the
/// product ever tells anyone, and it has to survive Larger Text and Bold Text.
struct BoardEmptyState: View {
    let spec: ThemeSpec
    let accented: Bool

    var body: some View {
        Text("Edit Widget")
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(spec.labelColor(at: 0, accented: accented).opacity(0.75))
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

/// Renders a full board for a given theme, density step and canvas — the same
/// pipeline `PresetEditorView` and the widget use, but with no store
/// dependency, so it's safe to preview without an App Group container.
private func previewBoard(theme: Theme, densityId: String, size: BoardSize, slotCount: Int) -> some View {
    let layout = DensityTemplate.all.first { $0.id == densityId }!.layout
    let names = Array(BoardSample.names.prefix(slotCount))
    let spec = theme.spec
    let resolved = BoardGrid.resolve(
        count: names.count,
        size: size,
        longestName: names.map(\.count).max() ?? 0,
        layout: layout
    )
    let grid = resolved.grid

    return BoardView(grid: grid, count: names.count) { index, col, row in
        SlotFace(
            name: names[index],
            surface: spec.surface(at: index, accented: false),
            label: spec.labelColor(at: index, accented: false),
            mode: grid.mode,
            font: grid.font,
            paddingX: grid.layout.paddingX,
            paddingY: grid.layout.paddingY,
            topLeadingRadius: grid.topLeadingRadius(col: col, row: row),
            bottomLeadingRadius: grid.bottomLeadingRadius(col: col, row: row),
            bottomTrailingRadius: grid.bottomTrailingRadius(col: col, row: row),
            topTrailingRadius: grid.topTrailingRadius(col: col, row: row)
        )
    }
    .frame(width: size.canvas.width, height: size.canvas.height)
    .background { ThemeBackground(spec: spec) }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .padding()
}

#Preview("Default — Midnight / Standard") {
    previewBoard(theme: .midnight, densityId: "standard", size: .medium, slotCount: 6)
}

#Preview("Slate — Ink / Flush") {
    previewBoard(theme: .ink, densityId: "flush", size: .medium, slotCount: 6)
}

#Preview("Panel — Aurora / Relaxed") {
    previewBoard(theme: .aurora, densityId: "relaxed", size: .large, slotCount: 6)
}

#Preview("Field — Meadow / Open") {
    previewBoard(theme: .meadow, densityId: "open", size: .large, slotCount: 9)
}

#Preview("Keypad — Sunset / Standard, small") {
    previewBoard(theme: .sunset, densityId: "standard", size: .small, slotCount: 4)
}

#Preview("Empty state — Midnight") {
    BoardEmptyState(spec: Theme.midnight.spec, accented: false)
        .frame(width: BoardSize.medium.canvas.width, height: BoardSize.medium.canvas.height)
        .background { ThemeBackground(spec: Theme.midnight.spec) }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding()
}
