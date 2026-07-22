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
        let today = now.addingTimeInterval(-60 * 60)
        let twoDaysAgo = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let fiveDaysAgo = now.addingTimeInterval(-5 * 24 * 60 * 60)
        let eightDaysAgo = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertTrue(TimeFilter.today.contains(today, now: now))
        XCTAssertFalse(TimeFilter.threeDays.contains(today, now: now))
        XCTAssertTrue(TimeFilter.threeDays.contains(twoDaysAgo, now: now))
        XCTAssertFalse(TimeFilter.threeDays.contains(fiveDaysAgo, now: now))
        XCTAssertFalse(TimeFilter.fishMemory.contains(twoDaysAgo, now: now))
        XCTAssertTrue(TimeFilter.fishMemory.contains(fiveDaysAgo, now: now))
        XCTAssertFalse(TimeFilter.fishMemory.contains(eightDaysAgo, now: now))
    }

    @MainActor
    func testFishMemoryProgressAndExpirationAtSevenDays() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let threeAndHalfDaysAgo = now.addingTimeInterval(-3.5 * 24 * 60 * 60)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)

        XCTAssertEqual(
            SnippetStore.memoryProgress(createdAt: threeAndHalfDaysAgo, now: now),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertFalse(SnippetStore.shouldMoveToMemoryShore(createdAt: threeAndHalfDaysAgo, now: now))
        XCTAssertTrue(SnippetStore.shouldMoveToMemoryShore(createdAt: sevenDaysAgo, now: now))
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
        XCTAssertEqual(snippet.representation, .automatic)
        XCTAssertEqual(snippet.tags, [])
        XCTAssertFalse(snippet.isEnriching)
        XCTAssertFalse(snippet.enrichmentFailed)
    }

    func testRepresentationDefaultsAndCanSwitchToImage() {
        var snippet = Snippet(
            id: UUID(),
            text: "A short note",
            title: "Note",
            createdAt: Date(),
            source: .quickNote
        )
        XCTAssertEqual(snippet.effectiveRepresentation, .text)
        snippet.representation = .image
        XCTAssertEqual(snippet.effectiveRepresentation, .image)
        XCTAssertTrue(snippet.supportsRepresentationToggle)
    }

    func testDetectsDateAndTimeInsideCopiedText() throws {
        let detected = try XCTUnwrap(
            DateContentDetector.firstDate(in: "Review the draft on August 10, 2026 at 2:30 PM")
        )
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: detected.date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 10)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }
}
