import XCTest
@testable import ClipboardStation

final class AttachmentCleanupTests: XCTestCase {
    func testRemovesOnlyFilesInsideAttachmentDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AttachmentCleanupTests-\(UUID().uuidString)", isDirectory: true)
        let attachments = root.appendingPathComponent("Attachments", isDirectory: true)
        let outside = root.appendingPathComponent("outside.png")
        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let inside = attachments.appendingPathComponent("inside.png")
        try Data([1, 2, 3]).write(to: inside)
        try Data([4, 5, 6]).write(to: outside)

        let insideSnippet = Snippet(
            id: UUID(),
            text: "",
            title: "Inside",
            createdAt: Date(),
            source: .screenshot,
            kind: .screenshot,
            attachmentPath: inside.path,
            fileName: "inside.png"
        )
        let outsideSnippet = Snippet(
            id: UUID(),
            text: "",
            title: "Outside",
            createdAt: Date(),
            source: .screenshot,
            kind: .screenshot,
            attachmentPath: outside.path,
            fileName: "outside.png"
        )

        let removed = AttachmentCleanup.removeAttachments(for: [insideSnippet, outsideSnippet], in: attachments)

        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: inside.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
}
