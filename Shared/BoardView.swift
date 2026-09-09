import SwiftUI

extension ThemeSpec {
    /// Tile fill. In accented mode the system keeps the opacity of translucent
    /// content and tints it, so a faint chip is what preserves the board's
    /// structure once the color is taken away.
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
    let style: BackgroundStyle
    let accented: Bool

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
                if !accented && style == .glassTiles {
                    shape
                        .fill(.regularMaterial)
                        .overlay(
                            shape
                                .fill(surface.opacity(0.15))
                        )
                        .padding(0.5)
                } else {
                    shape
                        .fill(surface)
                        .padding(0.5)
                }
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
