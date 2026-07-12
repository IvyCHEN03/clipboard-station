import XCTest
@testable import ClipboardStation

final class DemoContentTests: XCTestCase {
    func testDemoSnippetsShowCoreWorkflowSurfaces() {
        let snippets = DemoContent.makeSnippets(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(snippets.count, 3)
        XCTAssertTrue(snippets.contains { $0.kind == .text })
        XCTAssertTrue(snippets.contains { $0.kind == .spreadsheet })
        XCTAssertTrue(snippets.allSatisfy { !$0.title.isEmpty && !$0.text.isEmpty })
    }

    func testDemoSnippetsIncludeUsefulTagsForFiltering() {
        let tags = Set(DemoContent.makeSnippets().flatMap(\.tags))

        XCTAssertTrue(tags.contains("AI"))
        XCTAssertTrue(tags.contains("workflow"))
        XCTAssertTrue(tags.contains("table"))
        XCTAssertTrue(tags.contains("screenshot"))
    }

    func testDemoSnippetsAreNewestFirst() {
        let snippets = DemoContent.makeSnippets(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertGreaterThan(snippets[0].createdAt, snippets[1].createdAt)
        XCTAssertGreaterThan(snippets[1].createdAt, snippets[2].createdAt)
    }
}
