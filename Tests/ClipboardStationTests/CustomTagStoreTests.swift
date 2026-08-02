import XCTest
@testable import ClipboardStation

@MainActor
final class CustomTagStoreTests: XCTestCase {
    func testCreatesDeduplicatesRemovesAndGloballyRenamesCustomTags() {
        let first = makeSnippet(title: "First")
        let second = makeSnippet(title: "Second", customTags: ["Research"])
        let store = SnippetStore(testingSnippets: [first, second])

        XCTAssertTrue(store.addCustomTag(" 重点 ", to: [first.id, second.id]))
        XCTAssertFalse(store.addCustomTag("重点", to: [first.id, second.id]))
        XCTAssertEqual(store.snippets[0].customTags, ["重点"])
        XCTAssertEqual(store.snippets[1].customTags, ["Research", "重点"])

        XCTAssertTrue(store.renameCustomTag("重点", to: "待验证"))
        XCTAssertEqual(store.snippets[0].customTags, ["待验证"])
        XCTAssertEqual(store.snippets[1].customTags, ["Research", "待验证"])

        store.removeCustomTag("待验证", from: first.id)
        XCTAssertEqual(store.snippets[0].customTags, [])

        store.deleteCustomTag("research")
        XCTAssertEqual(store.snippets[1].customTags, ["待验证"])
    }

    func testRejectsEmptyLongAndAITagDuplicates() {
        let snippet = makeSnippet(title: "Tagged", tags: ["AI"])
        let store = SnippetStore(testingSnippets: [snippet])

        XCTAssertFalse(store.addCustomTag(" ", to: [snippet.id]))
        XCTAssertFalse(store.addCustomTag("这是一个超过十个字符的标签", to: [snippet.id]))
        XCTAssertFalse(store.addCustomTag("ai", to: [snippet.id]))
        XCTAssertTrue(store.snippets[0].customTags.isEmpty)
    }

    func testAIEnrichmentDoesNotOverwriteCustomTags() {
        let snippet = makeSnippet(title: "Original", customTags: ["手动重点"])
        let store = SnippetStore(testingSnippets: [snippet])

        store.applyEnrichment(
            AIEnrichment(title: "AI 标题", tags: ["Research", " research ", "整理", "第四个"]),
            to: snippet.id
        )

        XCTAssertEqual(store.snippets[0].title, "AI 标题")
        XCTAssertEqual(store.snippets[0].tags, ["Research", "整理", "第四个"])
        XCTAssertEqual(store.snippets[0].customTags, ["手动重点"])
    }

    func testFrequentTagStatsIncludeCustomTagsCaseInsensitively() {
        let first = makeSnippet(title: "First", customTags: ["重点"])
        let second = makeSnippet(title: "Second", customTags: [" 重点 "])
        let store = SnippetStore(testingSnippets: [first, second])

        XCTAssertEqual(store.frequentTags.first, KeywordStat(tag: "重点", count: 2))
        XCTAssertEqual(store.customTagStats.first, KeywordStat(tag: "重点", count: 2))
    }

    func testCleanupRemovesBlankLongAndDuplicateCustomTags() {
        let snippet = makeSnippet(
            title: "Messy",
            customTags: [" 重点 ", "", "重点", "这是一个超过十个字符的标签"]
        )
        let store = SnippetStore(testingSnippets: [snippet])

        store.cleanupCustomTags()

        XCTAssertEqual(store.snippets[0].customTags, ["重点"])
    }

    private func makeSnippet(
        title: String,
        tags: [String] = [],
        customTags: [String] = []
    ) -> Snippet {
        Snippet(
            id: UUID(),
            text: "\(title) body",
            title: title,
            createdAt: Date(),
            source: .clipboardCopy,
            tags: tags,
            customTags: customTags
        )
    }
}
