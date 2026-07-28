import AppKit
import Vision

enum OCRTextRecognizer {
    static func recognize(data: Data) -> String? {
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return recognize(cgImage: cgImage)
    }

    static func recognize(url: URL) -> String? {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return recognize(cgImage: cgImage)
    }

    private static func recognize(cgImage: CGImage) -> String? {
        let original = recognizeLines(in: cgImage)
        guard hasAlpha(cgImage), (original?.count ?? 0) < 8 else {
            return original
        }
        return [
            original,
            recognizeLines(in: flattened(cgImage, background: .white)),
            recognizeLines(in: flattened(cgImage, background: .black))
        ]
            .compactMap { $0 }
            .max { $0.count < $1.count }
    }

    private static func recognizeLines(in cgImage: CGImage?) -> String? {
        guard let cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return nil
        }
        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .alphaOnly, .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        @unknown default:
            return true
        }
    }

    private static func flattened(_ image: CGImage, background: NSColor) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.setFillColor(background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
