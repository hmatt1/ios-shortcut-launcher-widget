import SwiftUI
import WidgetKit

enum BackgroundPlan: Equatable {
    case removed
    case systemDefault
    case theme
    /// Transparent style. The widget keeps its container background clear and
    /// draws the pre-rendered wallpaper slice as content (see `LauncherWidgetView`)
    /// so the system's Liquid Glass never composites over it. The app preview
    /// draws the slice directly.
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
        case .transparent: return .wallpaperCrop
        }

    case let .widget(showsContainerBackground, renderingMode):
        guard showsContainerBackground else { return .removed }
        guard renderingMode == .fullColor else { return .systemDefault }

        switch style {
        case .liquidGlass: return .systemDefault
        case .theme: return .theme
        case .transparent: return .wallpaperCrop
        }
    }
}

struct WidgetBackground: ViewModifier {
    let style: BackgroundStyle
    let spec: ThemeSpec
    let position: WidgetPosition
    let family: BoardSize

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
            // The slice is drawn as widget content in `LauncherWidgetView`, so
            // the container stays clear and the system never glasses it.
            Color.clear

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
        family: BoardSize
    ) -> some View {
        modifier(WidgetBackground(
            style: style,
            spec: spec,
            position: position,
            family: family
        ))
    }
}

/// One pre-rendered wallpaper slice, scaled to cover its container. Falls back
/// to the theme background when no wallpaper is stored.
struct WallpaperCropImage: View {
    let family: BoardSize
    let position: WidgetPosition
    let fallback: ThemeSpec

    var body: some View {
        if let image = WallpaperStore.croppedWallpaper(family: family, position: position) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ThemeBackground(spec: fallback)
        }
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

/// The in-app preview of the widget background.
struct PreviewBackground: View {
    let style: BackgroundStyle
    let spec: ThemeSpec
    let position: WidgetPosition
    let family: BoardSize

    var body: some View {
        let plan = backgroundPlan(style: style, surface: .appPreview)

        switch plan {
        case .removed:
            Color.clear
        case .systemDefault:
            Rectangle().fill(.regularMaterial)
        case .theme:
            ThemeBackground(spec: spec)
        case .wallpaperCrop:
            WallpaperCropImage(family: family, position: position, fallback: spec)
        case .previewMaterial:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
