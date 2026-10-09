import Foundation
import UIKit
import ImageIO

/// Per-button images for a preset, stored as small PNG files in the App Group
/// container: `buttonImages/<presetId>/<button>_<token>.png`.
///
/// Buttons are numbered from 1 in the order the shortcuts are picked in the
/// widget, so an image follows its button number, not a shortcut's name.
///
/// Memory is the constraint that shapes this. The app downsamples every image
/// once, on write, to at most `maxStoredPixels` on its longest side. The widget
/// then decodes each file straight to the size of its own tile with an ImageIO
/// thumbnail, so the bitmaps it holds add up to roughly the widget's canvas, no
/// matter how many buttons have images. Nothing here throws into rendering:
/// every failure reads as "no image" and the tile falls back to its label.
extension Notification.Name {
    /// Posted after a preset's button images change (saved, removed or copied),
    /// with the preset's id under `ButtonImageStore.presetIdKey` in `userInfo`.
    /// Views that show the images listen for it instead of caching a list.
    static let buttonImagesDidChange = Notification.Name("ButtonImageStore.buttonImagesDidChange")
}

enum ButtonImageStore {
    static let presetIdKey = "presetId"

    private static func announceChange(_ presetId: UUID) {
        NotificationCenter.default.post(name: .buttonImagesDidChange, object: nil, userInfo: [presetIdKey: presetId])
    }

    /// Longest side, in pixels, of a stored image.
    static let maxStoredPixels = 512

    static let buttonRange = 1...BoardGrid.maxSlots

    // MARK: - Writing (app side)

    /// Downsamples `data` and stores it as the image for `button`, replacing any
    /// previous one. Returns `false` when the data isn't an image, the button is
    /// out of range, or the file couldn't be written.
    @discardableResult
    static func save(data: Data, presetId: UUID, button: Int) -> Bool {
        guard buttonRange.contains(button),
              let directory = directory(for: presetId, create: true),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixel: maxStoredPixels)),
              let png = UIImage(cgImage: cgImage).pngData()
        else { return false }

        let name = "\(button)_\(UUID().uuidString).png"
        do {
            try png.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            return false
        }
        // Only drop the old file once the new one is safely on disk.
        for old in files(in: directory) where old.button == button && old.name != name {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(old.name))
        }
        announceChange(presetId)
        return true
    }

    static func remove(presetId: UUID, button: Int) {
        guard let directory = directory(for: presetId, create: false) else { return }
        for file in files(in: directory) where file.button == button {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file.name))
        }
        announceChange(presetId)
    }

    static func removeAll(presetId: UUID) {
        guard let directory = directory(for: presetId, create: false) else { return }
        try? FileManager.default.removeItem(at: directory)
        announceChange(presetId)
    }

    /// Copies every image of one preset to another, for Duplicate.
    static func copyAll(from source: UUID, to destination: UUID) {
        guard let from = directory(for: source, create: false),
              let to = directory(for: destination, create: true) else { return }
        for file in files(in: from) {
            try? FileManager.default.copyItem(
                at: from.appendingPathComponent(file.name),
                to: to.appendingPathComponent(file.name)
            )
        }
        announceChange(destination)
    }

    // MARK: - Reading (widget and editor)

    /// Button numbers that have an image, ascending.
    static func buttons(presetId: UUID) -> [Int] {
        guard let directory = directory(for: presetId, create: false) else { return [] }
        return Array(Set(files(in: directory).map(\.button))).sorted()
    }

    /// The image for `button`, decoded so its longest side is at most `maxPixel`.
    static func image(presetId: UUID, button: Int, maxPixel: Int) -> UIImage? {
        guard buttonRange.contains(button),
              let directory = directory(for: presetId, create: false),
              let file = files(in: directory).first(where: { $0.button == button })
        else { return nil }

        let pixels = max(1, min(maxPixel, maxStoredPixels))
        let key = "\(presetId.uuidString)/\(file.name)@\(pixels)" as NSString
        if let cached = imageCache.object(forKey: key) { return cached }

        let url = directory.appendingPathComponent(file.name)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixel: pixels))
        else { return nil }

        let image = UIImage(cgImage: cgImage)
        imageCache.setObject(image, forKey: key)
        return image
    }

    /// `BoardSize.canvas` is the smallest canvas iOS gives a family (a 320 pt
    /// wide screen); the largest phones give about this much more. Decoding for
    /// the smaller canvas would leave pictures slightly soft on a big phone.
    static let largestCanvasFactor: CGFloat = 1.25

    /// Longest side, in pixels, a tile of `cell` points needs at `scale`.
    static func pixelSize(forCell cell: CGSize, scale: CGFloat) -> Int {
        Int((max(cell.width, cell.height) * max(1, scale) * largestCanvasFactor).rounded(.up))
    }

    // MARK: - Internals

    /// Drops decoded images so the next read decodes again. For tests.
    static func clearCache() {
        imageCache.removeAllObjects()
    }

    /// `NSCache` is thread-safe, so the nonisolated readers above can share it.
    nonisolated(unsafe) private static let imageCache = NSCache<NSString, UIImage>()

    private static func thumbnailOptions(maxPixel: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
    }

    private static func directory(for presetId: UUID, create: Bool) -> URL? {
        guard let base = AppGroup.containerURL else { return nil }
        let url = base
            .appendingPathComponent("buttonImages", isDirectory: true)
            .appendingPathComponent(presetId.uuidString, isDirectory: true)
        if create {
            guard (try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)) != nil else {
                return nil
            }
        } else if !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }
        return url
    }

    /// Files named `<button>_<token>.png`; anything else in the folder is ignored.
    private static func files(in directory: URL) -> [(name: String, button: Int)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            guard name.hasSuffix(".png"),
                  let button = name.split(separator: "_", maxSplits: 1).first.flatMap({ Int($0) }),
                  buttonRange.contains(button)
            else { return nil }
            return (name, button)
        }
    }
}
