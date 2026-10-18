import AppKit
import ImageIO
import Vision

enum MediaService {
    private static let thumbnails = NSCache<NSString, NSImage>()
    static func validImage(_ data: Data) -> Bool {
        guard data.count <= 8 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && width <= 12000 && height <= 12000 && width * height <= 40_000_000
    }
    static func thumbnail(_ item: ClipItem) -> NSImage? {
        let key = item.id.uuidString as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let data = item.imageData, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: .zero)
        thumbnails.totalCostLimit = 12 * 1024 * 1024
        thumbnails.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height)
        return image
    }
    static func purgeThumbnails() { thumbnails.removeAllObjects() }
    static func extractText(_ data: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(data: data)
            try handler.perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }
}
