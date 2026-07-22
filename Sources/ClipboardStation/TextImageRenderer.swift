import AppKit
import Foundation

enum TextImageRenderer {
    static func image(text: String, title: String? = nil) -> NSImage? {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        let width: CGFloat = 720
        let inset: CGFloat = 34
        let titleHeight: CGFloat = title?.isEmpty == false ? 42 : 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.lineBreakMode = .byWordWrapping
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let body = NSAttributedString(string: content, attributes: bodyAttributes)
        let bodyRect = body.boundingRect(
            with: CGSize(width: width - inset * 2, height: 4_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = min(max(180, ceil(bodyRect.height) + inset * 2 + titleHeight), 4_096)
        let image = NSImage(size: CGSize(width: width, height: height))
        image.lockFocusFlipped(true)
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), xRadius: 18, yRadius: 18).fill()

        var bodyY = inset
        if let title, !title.isEmpty {
            NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
            ).draw(in: CGRect(x: inset, y: inset, width: width - inset * 2, height: 30))
            bodyY += titleHeight
        }
        body.draw(in: CGRect(x: inset, y: bodyY, width: width - inset * 2, height: height - bodyY - inset))
        image.unlockFocus()
        return image
    }

    static func pngData(text: String, title: String? = nil) -> Data? {
        guard let image = image(text: text, title: title),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
