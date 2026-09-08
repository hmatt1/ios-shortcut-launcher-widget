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

/// Widget background. The system replaces this in accented mode, so it draws
/// nothing there rather than fighting for the same pixels.
struct BoardBackground: View {
    let spec: ThemeSpec
    let accented: Bool
    let style: BackgroundStyle
    let position: WidgetPosition
    let family: BoardSize

    var isAppPreview: Bool = false
    
    var body: some View {
        if accented {
            Color.clear
        } else {
            switch style {
            case .theme:
                themeBackground
            case .liquidGlass:
                Color.clear
            case .glassTiles, .transparent:
                transparentBackground
            }
        }
    }
    
    @ViewBuilder
    private var themeBackground: some View {
        let colors = spec.background
        if colors.count >= 2 {
            LinearGradient(
                colors: colors.map(\.color),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if let first = colors.first {
            first.color
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var transparentBackground: some View {
        if isAppPreview {
            Color.clear
        } else {
            GeometryReader { proxy in
                if let wp = WallpaperStore.getWallpaper() {
                    let crop = cropOffset(for: position, widgetSize: proxy.size, screen: wp.screen)
                    Image(uiImage: wp.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: wp.screen.width, height: wp.screen.height)
                        .offset(x: crop.width, y: crop.height)
                } else {
                    themeBackground
                }
            }
        }
    }
    
    private func cropOffset(for pos: WidgetPosition, widgetSize: CGSize, screen: CGSize) -> CGSize {
        // Approximate the grid spacing based on actual device dimensions
        let hMargin = (screen.width - (widgetSize.width * (family == .small ? 2 : 1))) / (family == .small ? 3 : 2)
        let vGap = hMargin // Typically horizontal and vertical gaps are identical
        let topMargin: CGFloat = screen.height >= 844 ? 76 : (screen.height >= 812 ? 60 : 47) // Rough safe area + padding
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        // Calculate X
        switch pos {
        case .topLeft, .middleLeft, .bottomLeft, .top, .middle, .bottom:
            x = hMargin
        case .topRight, .middleRight, .bottomRight:
            x = screen.width - hMargin - widgetSize.width
        }
        
        // Calculate Y
        switch pos {
        case .topLeft, .topRight, .top:
            y = topMargin
        case .middleLeft, .middleRight, .middle:
            y = topMargin + widgetSize.height + vGap
        case .bottomLeft, .bottomRight, .bottom:
            y = topMargin + (widgetSize.height + vGap) * 2
        }
        
        // Move image negatively so the target area falls under the widget frame (0,0)
        return CGSize(width: -x, height: -y)
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
