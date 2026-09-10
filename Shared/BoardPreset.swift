import Foundation
import CoreGraphics

public struct BoardPreset: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var columns: Int
    public var marginX: CGFloat
    public var marginY: CGFloat
    public var spacingX: CGFloat
    public var spacingY: CGFloat
    public var paddingX: CGFloat
    public var paddingY: CGFloat
    public var cornerRadius: CGFloat
    public var outerCornerRadius: CGFloat
    public var themeId: UUID
    public var background: BackgroundStyle
    /// Only meaningful when `background == .transparent`. `false` blends the
    /// wallpaper slice in exactly; `true` lays a glass wash over it.
    public var frostedGlass: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        columns: Int,
        marginX: CGFloat,
        marginY: CGFloat,
        spacingX: CGFloat,
        spacingY: CGFloat,
        paddingX: CGFloat,
        paddingY: CGFloat,
        cornerRadius: CGFloat,
        outerCornerRadius: CGFloat? = nil,
        themeId: UUID,
        background: BackgroundStyle,
        frostedGlass: Bool = false
    ) {
        self.id = id
        self.name = name
        self.columns = columns
        self.marginX = marginX
        self.marginY = marginY
        self.spacingX = spacingX
        self.spacingY = spacingY
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.cornerRadius = cornerRadius
        self.outerCornerRadius = outerCornerRadius ?? cornerRadius
        self.themeId = themeId
        self.background = background
        self.frostedGlass = frostedGlass
    }

    enum CodingKeys: CodingKey {
        case id, name, columns, marginX, marginY, spacingX, spacingY, paddingX, paddingY, cornerRadius, outerCornerRadius, themeId, theme, customTheme, background, frostedGlass
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        columns = try container.decode(Int.self, forKey: .columns)
        marginX = try container.decode(CGFloat.self, forKey: .marginX)
        marginY = try container.decode(CGFloat.self, forKey: .marginY)
        spacingX = try container.decode(CGFloat.self, forKey: .spacingX)
        spacingY = try container.decode(CGFloat.self, forKey: .spacingY)
        paddingX = try container.decode(CGFloat.self, forKey: .paddingX)
        paddingY = try container.decode(CGFloat.self, forKey: .paddingY)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
        outerCornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .outerCornerRadius) ?? cornerRadius
        // Lenient: a value written by an older build (e.g. a removed style) must
        // never throw here, or one bad preset drops the whole store.
        background = (try? container.decode(BackgroundStyle.self, forKey: .background)) ?? .theme
        frostedGlass = (try? container.decode(Bool.self, forKey: .frostedGlass)) ?? false
        
        if let decodedThemeId = try container.decodeIfPresent(UUID.self, forKey: .themeId) {
            themeId = decodedThemeId
        } else if let oldTheme = try container.decodeIfPresent(Theme.self, forKey: .theme) {
            // Migrate from old Theme enum
            let defaultThemes = BoardThemeStore.createDefaultThemes()
            let matched = defaultThemes.first(where: { $0.name == oldTheme.displayName })
            themeId = matched?.id ?? defaultThemes.first!.id
        } else {
            themeId = BoardThemeStore.createDefaultThemes().first!.id
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(columns, forKey: .columns)
        try container.encode(marginX, forKey: .marginX)
        try container.encode(marginY, forKey: .marginY)
        try container.encode(spacingX, forKey: .spacingX)
        try container.encode(spacingY, forKey: .spacingY)
        try container.encode(paddingX, forKey: .paddingX)
        try container.encode(paddingY, forKey: .paddingY)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(outerCornerRadius, forKey: .outerCornerRadius)
        try container.encode(themeId, forKey: .themeId)
        try container.encode(background, forKey: .background)
        try container.encode(frostedGlass, forKey: .frostedGlass)
    }

    public var activeSpec: ThemeSpec {
        BoardThemeStore.loadTheme(id: themeId).spec
    }

    public var layoutValues: BoardLayoutValues {
        BoardLayoutValues(
            columns: columns,
            marginX: marginX,
            marginY: marginY,
            spacingX: spacingX,
            spacingY: spacingY,
            paddingX: paddingX,
            paddingY: paddingY,
            cornerRadius: cornerRadius,
            outerCornerRadius: outerCornerRadius
        )
    }
}
