import Foundation
import UIKit
import SwiftUI

@MainActor
final class WallpaperStore: ObservableObject {
    static let shared = WallpaperStore()
    
    private let defaults = AppGroup.defaults
    
    private let imageDataKey = "wallpaperImageData"
    private let screenWidthKey = "wallpaperScreenWidth"
    private let screenHeightKey = "wallpaperScreenHeight"
    
    @Published var image: UIImage?
    var screenBounds: CGSize?
    
    init() {
        load()
    }
    
    func save(image: UIImage, screenBounds: CGSize) {
        self.image = image
        self.screenBounds = screenBounds
        
        // Downsample to a reasonable size if needed, but JPEG compression is usually fine.
        if let data = image.jpegData(compressionQuality: 0.8) {
            defaults?.set(data, forKey: imageDataKey)
            defaults?.set(Double(screenBounds.width), forKey: screenWidthKey)
            defaults?.set(Double(screenBounds.height), forKey: screenHeightKey)
        }
    }
    
    func load() {
        if let data = defaults?.data(forKey: imageDataKey),
           let img = UIImage(data: data) {
            self.image = img
            
            let w = defaults?.double(forKey: screenWidthKey) ?? 0
            let h = defaults?.double(forKey: screenHeightKey) ?? 0
            
            if w > 0 && h > 0 {
                self.screenBounds = CGSize(width: w, height: h)
            }
        }
    }
    
    static func getWallpaper() -> (image: UIImage, screen: CGSize)? {
        let defaults = AppGroup.defaults
        if let data = defaults?.data(forKey: "wallpaperImageData"),
           let img = UIImage(data: data) {
            let w = defaults?.double(forKey: "wallpaperScreenWidth") ?? 0
            let h = defaults?.double(forKey: "wallpaperScreenHeight") ?? 0
            if w > 0 && h > 0 {
                return (img, CGSize(width: w, height: h))
            }
        }
        return nil
    }
}
