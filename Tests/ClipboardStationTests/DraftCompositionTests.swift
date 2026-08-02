import XCTest
@testable import ClipboardStation

@MainActor
final class DraftCompositionTests: XCTestCase {
    func testSingleAndMultipleAddFollowSuppliedVisibleOrder() {
        let snippets = makeSnippets(4)
        let store = SnippetStore(testingSnippets: snippets)

        XCTAssertEqual(store.addToDraft(id: snippets[2].id).addedCount, 1)
        XCTAssertEqual(
            store.addToDraft(idsInDisplayOrder: [snippets[3].id, snippets[1].id]).addedCount,
            2
        )
        XCTAssertEqual(
            store.draftSnippetIDs,
            [snippets[2].id, snippets[3].id, snippets[1].id]
        )
    }

    func testRewoundVisibleOrderIsPreservedByBatchAddition() {
        let snippets = makeSnippets(4)
        let store = SnippetStore(testingSnippets: snippets)
        let visibleOrder = snippets.reversed().map(\.id)

        store.addToDraft(idsInDisplayOrder: visibleOrder)

        XCTAssertEqual(store.draftSnippetIDs, visibleOrder)
    }

    func testPartialAndCompleteDuplicatesAreSkipped() {
        let snippets = makeSnippets(3)
        let store = SnippetStore(testingSnippets: snippets)
        store.addToDraft(idsInDisplayOrder: [snippets[0].id, snippets[1].id])

        let partial = store.addToDraft(
            idsInDisplayOrder: [snippets[1].id, snippets[2].id],
            showFeedback: false
        )
        XCTAssertEqual(partial, DraftAdditionResult(addedCount: 1, duplicateCount: 1, unavailableCount: 0))
        XCTAssertEqual(store.draftSnippetIDs, snippets.map(\.id))

        let complete = store.addToDraft(
            idsInDisplayOrder: snippets.map(\.id),
            showFeedback: false
        )
        XCTAssertEqual(complete, DraftAdditionResult(addedCount: 0, duplicateCount: 3, unavailableCount: 0))
        XCTAssertEqual(store.draftSnippetIDs, snippets.map(\.id))
    }

    func testInternalDraftReorderingStillMovesExistingBlock() {
        let snippets = makeSnippets(3)
        let store = SnippetStore(testingSnippets: snippets)
        store.addToDraft(idsInDisplayOrder: snippets.map(\.id))

        store.moveDraftBlock(id: snippets[2].id, before: snippets[0].id)

        XCTAssertEqual(store.draftSnippetIDs, [snippets[2].id, snippets[0].id, snippets[1].id])
    }

    func testInstructionModeAndOrderChangesInvalidateAIResult() {
        let snippets = makeSnippets(2)
        let store = SnippetStore(testingSnippets: snippets)
        store.addToDraft(idsInDisplayOrder: snippets.map(\.id))
        store.acceptAIResult("Result [片段 1]")
        XCTAssertTrue(store.hasCurrentPolishedDraft)

        store.draftExtraText = "保留数字"
        XCTAssertFalse(store.hasCurrentPolishedDraft)

        store.acceptAIResult("New result")
        store.setAIAction(.compare)
        XCTAssertFalse(store.hasCurrentPolishedDraft)

        store.acceptAIResult("Compare result")
        store.moveDraftBlock(id: snippets[1].id, before: snippets[0].id)
        XCTAssertFalse(store.hasCurrentPolishedDraft)
    }

    func testOutputsWorkWithoutAIConfigurationAndDefaultCopyCleansReferences() throws {
        let snippets = makeSnippets(2)
        let store = SnippetStore(testingSnippets: snippets)
        store.addToDraft(idsInDisplayOrder: snippets.map(\.id))
        store.draftExtraText = "保留原文"
        store.draftTextSlots["before-\(snippets[1].id.uuidString)"] = "比较下面的来源"

        let context = try store.currentDraftContext()
        XCTAssertTrue(context.contains("用户补充要求：\n保留原文"))
        XCTAssertTrue(context.contains("比较下面的来源\n\nBody 2"))
        XCTAssertNotNil(store.draftOutput(format: .fullContext))
        XCTAssertEqual(store.draftOutput(format: nil), "Body 1\n\n比较下面的来源\n\nBody 2")

        store.acceptAIResult("[片段 1] 合并结果")
        XCTAssertEqual(store.draftOutput(format: nil), "合并结果")
        XCTAssertTrue(store.draftOutput(format: .withSources)?.contains("来源：") == true)
    }

    func testOriginalSnippetEditInvalidatesAIResult() {
        let snippets = makeSnippets(1)
        let store = SnippetStore(testingSnippets: snippets)
        store.addToDraft(id: snippets[0].id)
        store.acceptAIResult("Old result")
        XCTAssertTrue(store.hasCurrentPolishedDraft)

        store.snippets[0].text = "Edited body"

        XCTAssertFalse(store.hasCurrentPolishedDraft)
        XCTAssertEqual(store.draftOutput(format: nil), "Edited body")
    }

    private func makeSnippets(_ count: Int) -> [Snippet] {
        (0..<count).map { index in
            Snippet(
                id: UUID(),
                text: "Body \(index + 1)",
                title: "Title \(index + 1)",
                createdAt: Date().addingTimeInterval(TimeInterval(-index)),
                source: .clipboardCopy,
                tags: ["tag\(index + 1)"]
            )
        }
    }
}
