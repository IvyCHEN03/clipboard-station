import XCTest
@testable import ClipboardStation

final class MarkdownExportTests: XCTestCase {
    func testRendersReadableSnippetMarkdown() {
        let id = UUID()
        let snippet = Snippet(
            id: id,
            text: "Prompt fragment\nwith two lines",
            title: "Research note",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            source: .clipboardCopy,
            kind: .text,
            tags: ["ai", "workflow"]
        )

        let markdown = MarkdownExport.render(
            snippets: [snippet],
            exportedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        XCTAssertTrue(markdown.contains("# Linggan Floating Ball Export"))
        XCTAssertTrue(markdown.contains("Snippets: 1"))
        XCTAssertTrue(markdown.contains("## 1. Research note"))
        XCTAssertTrue(markdown.contains("- Kind: 文字"))
        XCTAssertTrue(markdown.contains("- Source: 复制监听"))
        XCTAssertTrue(markdown.contains("- Tags: ai, workflow"))
        XCTAssertTrue(markdown.contains("Prompt fragment\nwith two lines"))
    }

    func testRendersScreenshotWithoutOCRAsExplicitPlaceholder() {
        let snippet = Snippet(
            id: UUID(),
            text: "",
            title: "Screenshot",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            source: .screenshot,
            kind: .screenshot,
            attachmentPath: "/tmp/screenshot.png",
            fileName: "screenshot.png"
        )

        let markdown = MarkdownExport.render(snippets: [snippet])

        XCTAssertTrue(markdown.contains("- Attachment: screenshot.png"))
        XCTAssertTrue(markdown.contains("[Screenshot has no OCR text]"))
    }
}
