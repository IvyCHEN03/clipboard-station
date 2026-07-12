import XCTest
@testable import ClipboardStation

final class ModelTests: XCTestCase {
    func testSnippetMatchesTitleTextSourceKindAndTags() {
        let snippet = Snippet(
            id: UUID(),
            text: "Collect Markdown prompt fragments",
            title: "AI Research Notes",
            createdAt: Date(),
            source: .clipboardCopy,
            kind: .spreadsheet,
            tags: ["workflow", "剪贴板整理"]
        )

        XCTAssertTrue(snippet.matchesKeyword("research"))
        XCTAssertTrue(snippet.matchesKeyword("markdown"))
        XCTAssertTrue(snippet.matchesKeyword("复制监听"))
        XCTAssertTrue(snippet.matchesKeyword("表格"))
        XCTAssertTrue(snippet.matchesKeyword("剪贴板"))
        XCTAssertTrue(snippet.matchesKeyword("剪贴板整理和排序"))
        XCTAssertFalse(snippet.matchesKeyword("screenshot"))
    }

    func testEmptyKeywordMatchesEverything() {
        let snippet = Snippet(
            id: UUID(),
            text: "Any text",
            title: "Any title",
            createdAt: Date(),
            source: .manualPasteboardImport
        )

        XCTAssertTrue(snippet.matchesKeyword(""))
        XCTAssertTrue(snippet.matchesKeyword("   \n"))
    }

    func testTimeFiltersContainExpectedDates() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let twoDaysAgo = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let fiveDaysAgo = now.addingTimeInterval(-5 * 24 * 60 * 60)
        let eightDaysAgo = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertTrue(TimeFilter.threeDays.contains(twoDaysAgo, now: now))
        XCTAssertFalse(TimeFilter.threeDays.contains(fiveDaysAgo, now: now))
        XCTAssertTrue(TimeFilter.fishMemory.contains(fiveDaysAgo, now: now))
        XCTAssertFalse(TimeFilter.fishMemory.contains(eightDaysAgo, now: now))
    }

    func testDecodingLegacySnippetDefaultsKindAndTransientState() throws {
        let id = UUID()
        let data = """
        {
          "id": "\(id.uuidString)",
          "text": "Legacy text",
          "title": "Legacy title",
          "createdAt": "2026-07-12T10:00:00Z",
          "source": "clipboardCopy",
          "isEnriching": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snippet = try decoder.decode(Snippet.self, from: data)

        XCTAssertEqual(snippet.kind, .text)
        XCTAssertEqual(snippet.tags, [])
        XCTAssertFalse(snippet.isEnriching)
        XCTAssertFalse(snippet.enrichmentFailed)
    }
}
