import Foundation
import UIKit
import SwiftUI
import WidgetKit

/// Stores the wallpaper the "Transparent" background blends into.
///
/// The picked photo is normalised once, in the app, to the device's exact
/// native pixels, then sliced into one small PNG per widget slot and written to
/// the App Group container. The widget only ever loads its single small slice,
/// so it never holds a full-screen bitmap and never runs image maths inside the
/// extension's tight memory budget. Nothing is recompressed as JPEG and nothing
/// is redrawn at the wrong scale, so a slice is a pixel-exact piece of the
/// wallpaper.
@MainActor
final class WallpaperStore: ObservableObject {
    static let shared = WallpaperStore()

    private let defaults = AppGroup.defaults

    private static let tokenKey = "wallpaperToken"
    private static let screenWKey = "wallpaperScreenW"   // points
    private static let screenHKey = "wallpaperScreenH"   // points
    private static let scaleKey = "wallpaperScale"

    /// Whether a wallpaper has been stored. Drives the app's "uploaded" tick.
    @Published var hasWallpaper: Bool = false

    private init() {
        hasWallpaper = Self.token != nil
    }

    // MARK: - Writing (app side)

    /// Normalise `image` to `screenPoints * scale` pixels and pre-render every
    /// widget-slot crop. Runs synchronously: it is a one-off on an explicit
    /// upload and takes a few hundred milliseconds.
    func save(image: UIImage, screenPoints: CGSize, scale: CGFloat) {
        let token = UUID().uuidString
        guard Self.render(image: image, screenPoints: screenPoints, scale: scale, token: token) else { return }

        defaults?.set(token, forKey: Self.tokenKey)
        defaults?.set(Double(screenPoints.width), forKey: Self.screenWKey)
        defaults?.set(Double(screenPoints.height), forKey: Self.screenHKey)
        defaults?.set(Double(scale), forKey: Self.scaleKey)
        hasWallpaper = true
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Forget the stored wallpaper and its slices.
    func removeWallpaper() {
        if let dir = Self.cropsDir {
            try? FileManager.default.removeItem(at: dir)
        }
        defaults?.removeObject(forKey: Self.tokenKey)
        Self.imageCache.removeAllObjects()
        hasWallpaper = false
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Reading (widget and app-preview side)

    /// The pixel-exact wallpaper slice behind a widget in `family` at `position`,
    /// or `nil` when no wallpaper is stored.
    nonisolated static func croppedWallpaper(family: BoardSize, position: WidgetPosition) -> UIImage? {
        guard let token, let dir = cropsDir else { return nil }
        let slot = WidgetGeometry.canonicalSlot(family: family, position: position)
        let name = "crop_\(slot.family.fileTag)_\(slot.position.rawValue)_\(token).png"

        if let cached = imageCache.object(forKey: name as NSString) { return cached }

        let url = dir.appendingPathComponent(name)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }

    // MARK: - Internals

    /// `NSCache` is already thread-safe, so it is safe to reach from the
    /// nonisolated readers above.
    nonisolated(unsafe) private static let imageCache = NSCache<NSString, UIImage>()

    nonisolated static var token: String? {
        AppGroup.defaults?.string(forKey: tokenKey)
    }

    private nonisolated static var cropsDir: URL? {
        guard let base = AppGroup.containerURL else { return nil }
        return base.appendingPathComponent("wallpaper", isDirectory: true)
    }

    /// - Returns: `true` when at least one slice was written.
    private nonisolated static func render(
        image: UIImage,
        screenPoints: CGSize,
        scale: CGFloat,
        token: String
    ) -> Bool {
        guard let dir = cropsDir, scale > 0,
              screenPoints.width > 0, screenPoints.height > 0 else { return false }

        let fm = FileManager.default
        try? fm.removeItem(at: dir)                       // drop the previous upload
        guard (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil else { return false }

        let pixelWidth = max(1, Int((screenPoints.width * scale).rounded()))
        let pixelHeight = max(1, Int((screenPoints.height * scale).rounded()))
        guard let normalized = normalizedCGImage(from: image, pixelWidth: pixelWidth, pixelHeight: pixelHeight) else {
            return false
        }

        let bounds = CGRect(x: 0, y: 0, width: normalized.width, height: normalized.height)
        var wrote = false

        for slot in WidgetGeometry.canonicalSlots {
            let framePoints = WidgetGeometry.frame(
                family: slot.family,
                position: slot.position,
                screenPoints: screenPoints
            )
            let pixelRect = CGRect(
                x: framePoints.minX * scale,
                y: framePoints.minY * scale,
                width: framePoints.width * scale,
                height: framePoints.height * scale
            ).integral.intersection(bounds)

            guard !pixelRect.isNull, pixelRect.width >= 1, pixelRect.height >= 1,
                  let cropped = normalized.cropping(to: pixelRect),
                  let data = UIImage(cgImage: cropped).pngData() else { continue }

            let name = "crop_\(slot.family.fileTag)_\(slot.position.rawValue)_\(token).png"
            if (try? data.write(to: dir.appendingPathComponent(name), options: .atomic)) != nil {
                wrote = true
            }
        }

        imageCache.removeAllObjects()
        return wrote
    }

    /// Redraw `image` into exactly `pixelWidth x pixelHeight` pixels, filling the
    /// frame and centre-cropping the overflow, the same way iOS fits a wallpaper.
    private nonisolated static func normalizedCGImage(
        from image: UIImage,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> CGImage? {
        let target = CGSize(width: pixelWidth, height: pixelHeight)

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1              // 1 unit == 1 pixel, so no hidden rescale
        format.opaque = true

        let output = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let iw = image.size.width, ih = image.size.height
            guard iw > 0, ih > 0 else {
                image.draw(in: CGRect(origin: .zero, size: target))
                return
            }
            let fill = max(target.width / iw, target.height / ih)
            let drawn = CGSize(width: iw * fill, height: ih * fill)
            image.draw(in: CGRect(
                x: (target.width - drawn.width) / 2,
                y: (target.height - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            ))
        }
        return output.cgImage
    }
}
