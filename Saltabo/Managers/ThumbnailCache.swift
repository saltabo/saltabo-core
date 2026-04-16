import AppKit
import CoreGraphics

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "Saltabo.thumbnail-cache", qos: .userInitiated)

    private init() {}

    func image(for window: WindowDescriptor, targetSize: NSSize) -> NSImage? {
        let key = cacheKey(for: window.id, targetSize: targetSize)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        guard let raw = Self.capture(windowID: window.id) else { return nil }
        let image = NSImage(cgImage: raw, size: targetSize)
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    func warm(_ windows: [WindowDescriptor], targetSize: NSSize) {
        windows.forEach { window in
            queue.async { [weak self] in
                _ = self?.image(for: window, targetSize: targetSize)
            }
        }
    }

    private func cacheKey(for windowID: CGWindowID, targetSize: NSSize) -> String {
        "\(windowID)-\(Int(targetSize.width))x\(Int(targetSize.height))"
    }

    private static func capture(windowID: CGWindowID) -> CGImage? {
        typealias Function = @convention(c) (
            CGRect,
            CGWindowListOption,
            CGWindowID,
            CGWindowImageOption
        ) -> CGImage?

        guard let handle = dlopen(nil, RTLD_LAZY) else { return nil }
        defer { dlclose(handle) }

        guard let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let function = unsafeBitCast(symbol, to: Function.self)

        return function(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution])
    }
}
