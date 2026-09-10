import SwiftUI
import WidgetKit

enum BackgroundPlan: Equatable {
    case removed
    case systemDefault
    case theme
    /// Draw the pre-rendered wallpaper slice. In the widget this only fires for
    /// the frosted variant; the perfect variant draws the slice as content
    /// instead (see `LauncherWidgetView`) so the system's Liquid Glass never
    /// composites over it.
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
    /// `true` renders the wallpaper slice as the container background so iOS
    /// lays its Liquid Glass over it. `false` (perfect) keeps the container
    /// clear because the slice is drawn as widget content elsewhere.
    let frosted: Bool

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
            if frosted {
                WallpaperCropImage(family: family, position: position, fallback: spec)
                    .overlay { Rectangle().fill(.ultraThinMaterial) }
            } else {
                Color.clear
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
        frosted: Bool
    ) -> some View {
        modifier(WidgetBackground(
            style: style,
            spec: spec,
            position: position,
            family: family,
            frosted: frosted
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

/// The in-app preview. There is no system Liquid Glass here, so perfect and
/// frosted differ only by the material wash.
struct PreviewBackground: View {
    let style: BackgroundStyle
    let spec: ThemeSpec
    let position: WidgetPosition
    let family: BoardSize
    let frosted: Bool

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
            ZStack {
                WallpaperCropImage(family: family, position: position, fallback: spec)
                if frosted {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
        case .previewMaterial:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
