import Foundation
import UIKit
import AppIntents
import UniformTypeIdentifiers

/// The wallpaper that "Transparent" backgrounds blend into, as in the preset
/// editor's "Upload Wallpaper". It should be a screenshot of your Home Screen
/// wallpaper, taken on this device, so the widget slices line up.

struct SetWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Wallpaper"
    static var description: IntentDescription {
        IntentDescription("Sets the wallpaper image that Transparent widgets blend into. Use a screenshot of your Home Screen wallpaper from this device.")
    }

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Set wallpaper to \(\.$image)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uiImage = UIImage(data: image.data) else { throw PresetIntentError.unreadableImage }
        let before = WallpaperStore.token
        WallpaperStore.shared.save(
            image: uiImage,
            screenPoints: UIScreen.main.bounds.size,
            scale: UIScreen.main.scale
        )
        // `save` is silent on failure; a new token means the slices were written.
        guard WallpaperStore.token != before else { throw PresetIntentError.unreadableImage }
        return .result()
    }
}

struct RemoveWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Wallpaper"
    static var description: IntentDescription {
        IntentDescription("Removes the stored wallpaper. Transparent widgets fall back to the theme's colors.")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        WallpaperStore.shared.removeWallpaper()
        return .result()
    }
}
