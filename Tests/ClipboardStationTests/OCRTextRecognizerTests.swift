import AppKit
import XCTest
@testable import ClipboardStation

final class OCRTextRecognizerTests: XCTestCase {
    @MainActor
    func testRecognizesBlackTextOnTransparentBackground() throws {
        let image = NSImage(size: NSSize(width: 900, height: 200), flipped: false) { rect in
            NSGraphicsContext.current?.cgContext.clear(rect)
            let text = NSString(string: "LINGGAN OCR 2026")
            text.draw(
                at: NSPoint(x: 40, y: 62),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 72, weight: .bold),
                    .foregroundColor: NSColor.black
                ]
            )
            return true
        }
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))

        let recognized = try XCTUnwrap(OCRTextRecognizer.recognize(data: png))
        XCTAssertTrue(recognized.contains("2026"), recognized)
    }
}
