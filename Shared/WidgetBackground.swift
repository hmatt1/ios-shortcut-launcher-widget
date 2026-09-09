import SwiftUI
import WidgetKit

enum BackgroundPlan: Equatable {
    case removed
    case systemDefault
    case theme
    case wallpaperCrop
    case previewMaterial
}

enum BackgroundSurface: Equatable {
    case widget(showsContainerBackground: Bool, renderingMode: WidgetRenderingMode)
    case appPreview
}

func backgroundPlan(style: BackgroundStyle, surface: BackgroundSurface) -> BackgroundPlan {
    switch surface {
    case .appPreview:
        switch style {
        case .liquidGlass: return .previewMaterial
        case .theme: return .theme
        case .transparent, .glassTiles: return .wallpaperCrop
        }

    case let .widget(showsContainerBackground, renderingMode):
        guard showsContainerBackground else { return .removed }
        guard renderingMode == .fullColor else { return .systemDefault }

        switch style {
        case .liquidGlass: return .systemDefault
        case .theme: return .theme
        case .transparent, .glassTiles: return .wallpaperCrop
        }
    }
}

struct WidgetBackground: ViewModifier {
    let style: BackgroundStyle
    let spec: ThemeSpec
    let position: WidgetPosition
    let family: BoardSize
    let wallpaper: Wallpaper?

    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground
    @Environment(\.widgetRenderingMode) private var renderingMode

    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) {
            layer
        }
    }

    @ViewBuilder
    private var layer: some View {
        let plan = backgroundPlan(
            style: style,
            surface: .widget(showsContainerBackground: showsContainerBackground, renderingMode: renderingMode)
        )

        switch plan {
        case .removed:
            Color.clear

        case .systemDefault:
            Rectangle().fill(.regularMaterial)

        case .theme:
            ThemeBackground(spec: spec)

        case .wallpaperCrop:
            if let wallpaper {
                WallpaperCrop(wallpaper: wallpaper, position: position, family: family)
            } else {
                ThemeBackground(spec: spec)
            }

        case .previewMaterial:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

extension View {
    func widgetBackground(
        style: BackgroundStyle,
        spec: ThemeSpec,
        position: WidgetPosition,
        family: BoardSize,
        wallpaper: Wallpaper?
    ) -> some View {
        modifier(WidgetBackground(
            style: style,
            spec: spec,
            position: position,
            family: family,
            wallpaper: wallpaper
        ))
    }
}

struct WallpaperCrop: View {
    let wallpaper: Wallpaper
    let position: WidgetPosition
    let family: BoardSize

    var body: some View {
        GeometryReader { proxy in
            let crop = cropOffset(
                for: position,
                widgetSize: proxy.size,
                screen: wallpaper.screen
            )

            Image(uiImage: wallpaper.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: wallpaper.screen.width, height: wallpaper.screen.height)
                .offset(x: crop.width, y: crop.height)
        }
        .clipped()
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

struct ThemeBackground: View {
    let spec: ThemeSpec

    var body: some View {
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
}

struct PreviewBackground: View {
    let style: BackgroundStyle
    let spec: ThemeSpec
    let position: WidgetPosition
    let family: BoardSize
    let wallpaper: Wallpaper?

    var body: some View {
        let plan = backgroundPlan(
            style: style,
            surface: .appPreview
        )

        switch plan {
        case .removed:
            Color.clear
        case .systemDefault:
            Rectangle().fill(.regularMaterial)
        case .theme:
            ThemeBackground(spec: spec)
        case .wallpaperCrop:
            if let wallpaper {
                WallpaperCrop(wallpaper: wallpaper, position: position, family: family)
            } else {
                ThemeBackground(spec: spec)
            }
        case .previewMaterial:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
