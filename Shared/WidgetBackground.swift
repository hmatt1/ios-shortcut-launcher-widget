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
        let metrics: (left: CGFloat, right: CGFloat, top: CGFloat, middle: CGFloat, bottom: CGFloat)
        
        switch Int(screen.height) {
        case 956: // 16 Pro Max
            metrics = (left: 38.0, right: 232.0, top: 92.0, middle: 304.0, bottom: 516.0)
        case 932: // 14/15 Pro Max, 14/15/16 Plus
            metrics = (left: 32.66, right: 227.0, top: 84.0, middle: 296.0, bottom: 508.0)
        case 874: // 16 Pro
            metrics = (left: 29.0, right: 211.0, top: 87.0, middle: 290.66, bottom: 495.0)
        case 852: // 14 Pro, 15, 16
            metrics = (left: 27.0, right: 208.0, top: 80.0, middle: 276.0, bottom: 472.0)
        case 926: // 12/13 Pro Max, 14 Plus
            metrics = (left: 32.0, right: 226.0, top: 82.0, middle: 294.0, bottom: 506.0)
        case 896: // 11 Pro Max, XS Max, XR, 11
            metrics = (left: 27.0, right: 218.0, top: 76.0, middle: 286.0, bottom: 496.0)
        case 844: // 12, 13, 14, 12/13 Pro
            metrics = (left: 26.0, right: 206.0, top: 77.0, middle: 273.0, bottom: 469.0)
        case 812: // X, XS, 11 Pro, 12/13 mini
            metrics = (left: 23.0, right: 197.0, top: 71.0, middle: 261.0, bottom: 451.0)
        case 667: // SE2, SE3, 6, 7, 8
            metrics = (left: 27.0, right: 200.0, top: 30.0, middle: 206.0, bottom: 382.0)
        default:
            let hGap: CGFloat = 22
            let leftMargin = (screen.width - (widgetSize.width > 200 ? widgetSize.width : (widgetSize.width * 2 + hGap))) / 2
            let safeMargin = max(leftMargin, 22)
            metrics = (
                left: safeMargin, 
                right: screen.width - safeMargin - widgetSize.width, 
                top: 76.0, 
                middle: 76.0 + widgetSize.height + hGap, 
                bottom: 76.0 + (widgetSize.height + hGap) * 2
            )
        }
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        switch pos {
        case .topLeft, .middleLeft, .bottomLeft:
            x = metrics.left
        case .topRight, .middleRight, .bottomRight:
            x = metrics.right
        case .top, .middle, .bottom:
            x = metrics.left
        }
        
        switch pos {
        case .topLeft, .topRight, .top:
            y = metrics.top
        case .middleLeft, .middleRight, .middle:
            y = metrics.middle
        case .bottomLeft, .bottomRight, .bottom:
            y = metrics.bottom
        }
        
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
