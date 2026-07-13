import XCTest
@testable import ClipboardStation

final class ClipboardBackupTests: XCTestCase {
    func testBackupRoundTripPreservesSnippetsSettingsAndAttachments() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let attachmentURL = directory.appendingPathComponent("screenshot.png")
        let attachmentData = Data([0x89, 0x50, 0x4E, 0x47])
        try attachmentData.write(to: attachmentURL)

        var settings = StationSettings.defaults
        settings.aiEnrichment = true
        settings.aiModel = "test-model"

        let snippet = Snippet(
            id: UUID(),
            text: "Recognized OCR text",
            title: "Screenshot note",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            source: .screenshot,
            kind: .screenshot,
            attachmentPath: attachmentURL.path,
            fileName: "screenshot.png",
            tags: ["ocr", "demo"]
        )

        let backup = ClipboardBackupCodec.makeBackup(
            snippets: [snippet],
            settings: settings,
            appVersion: "0.4.0",
            exportedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        let encoded = try ClipboardBackupCodec.encode(backup)
        let decoded = try ClipboardBackupCodec.decode(encoded)

        XCTAssertEqual(decoded.formatVersion, ClipboardBackup.currentFormatVersion)
        XCTAssertEqual(decoded.appVersion, "0.4.0")
        XCTAssertEqual(decoded.snippets, [snippet])
        XCTAssertEqual(decoded.settings, settings)
        XCTAssertEqual(decoded.attachments.count, 1)
        XCTAssertEqual(decoded.attachments.first?.snippetID, snippet.id)
        XCTAssertEqual(decoded.attachments.first?.fileName, "screenshot.png")
        XCTAssertEqual(decoded.attachments.first?.data, attachmentData)
    }

    func testRejectsUnsupportedFutureBackupVersion() throws {
        let data = """
        {
          "formatVersion": 999,
          "appVersion": "9.9.9",
          "exportedAt": "2026-07-13T00:00:00Z",
          "snippets": [],
          "settings": {},
          "attachments": []
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try ClipboardBackupCodec.decode(data)) { error in
            XCTAssertEqual(error as? ClipboardBackupError, .unsupportedVersion(999))
        }
    }
}
