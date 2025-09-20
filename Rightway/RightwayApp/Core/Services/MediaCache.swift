import Foundation

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#else
#error("MediaCache requires UIKit or AppKit support")
#endif

protocol MediaCache {
    func image(for key: String) -> PlatformImage?
    func store(image: PlatformImage, for key: String)
}

final class DefaultMediaCache: MediaCache {
    private let cache = NSCache<NSString, PlatformImage>()

    func image(for key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)
    }

    func store(image: PlatformImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
