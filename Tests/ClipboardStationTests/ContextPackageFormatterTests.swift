import XCTest
@testable import ClipboardStation

final class ContextPackageFormatterTests: XCTestCase {
    func testFullContextKeepsBoundariesTitlesTagsSourcesAndInstruction() throws {
        let snippets = [
            makeSnippet(title: "Alpha", source: .clipboardCopy, tags: ["AI"], customTags: ["重点"]),
            makeSnippet(title: "Beta", source: .quickNote, tags: ["研究"])
        ]

        let context = try ContextPackageFormatter.fullContext(
            snippets: snippets,
            instruction: "比较不同来源"
        ) { snippet in
            "\(snippet.title) body"
        }

        XCTAssertTrue(context.contains("用户补充要求：\n比较不同来源"))
        XCTAssertTrue(context.contains("[片段 1]\n标题：Alpha"))
        XCTAssertTrue(context.contains("来源：复制监听"))
        XCTAssertTrue(context.contains("标签：AI、重点"))
        XCTAssertTrue(context.contains("[片段 2]\n标题：Beta"))
        XCTAssertTrue(context.contains("来源：随笔"))
    }

    func testMissingOCRTextIsReportedInsteadOfSilentlySkipped() {
        let screenshot = Snippet(
            id: UUID(),
            text: "",
            title: "No OCR",
            createdAt: Date(),
            source: .screenshot,
            kind: .screenshot
        )

        XCTAssertThrowsError(
            try ContextPackageFormatter.fullContext(snippets: [screenshot], instruction: nil) { _ in nil }
        ) { error in
            XCTAssertEqual(error as? ContextPackageError, .missingText("No OCR"))
        }
    }

    func testFourActionsUseDifferentPrompts() {
        let prompts = AIActionType.allCases.map(AIEnricher.systemPrompt(for:))

        XCTAssertEqual(Set(prompts).count, 4)
        XCTAssertTrue(AIEnricher.systemPrompt(for: .faithfulMerge).contains("保留数字、日期"))
        XCTAssertTrue(AIEnricher.systemPrompt(for: .compare).contains("共同点、差异"))
        XCTAssertTrue(AIEnricher.systemPrompt(for: .generatePrompt).contains("输出格式"))
    }

    func testTagPromptIncludesExistingTagsAndReuseRule() {
        let prompt = AIEnricher.taggingSystemPrompt(existingTags: ["研究", "research", "研究"])

        XCTAssertTrue(prompt.contains("已有标签：研究、research"))
        XCTAssertTrue(prompt.contains("优先从已有标签中选择最多 3 个标签"))
        XCTAssertTrue(prompt.contains("不要创建与已有标签近义"))
    }

    func testAITagNormalizationReusesExistingCasingAndLimitsToThree() {
        XCTAssertEqual(
            AIEnricher.normalizedAITags(
                [" research ", "AI", "ai", "新标签", "第四个"],
                existingTags: ["Research", "AI"]
            ),
            ["Research", "AI", "新标签"]
        )
    }

    func testCleanAndSourceOutputs() {
        let snippets = [
            makeSnippet(title: "Alpha", source: .clipboardCopy),
            makeSnippet(title: "Beta", source: .quickNote)
        ]
        let result = "[片段 1] 共同结论。\n[片段 2] 补充差异。"

        XCTAssertEqual(
            ContextPackageFormatter.cleanBody(result),
            "共同结论。 补充差异。"
        )
        let withSources = ContextPackageFormatter.resultWithSources(result, snippets: snippets)
        XCTAssertTrue(withSources.contains("[片段 1] Alpha · 复制监听"))
        XCTAssertTrue(withSources.contains("[片段 2] Beta · 随笔"))
    }

    private func makeSnippet(
        title: String,
        source: SnippetSource,
        tags: [String] = [],
        customTags: [String] = []
    ) -> Snippet {
        Snippet(
            id: UUID(),
            text: "\(title) body",
            title: title,
            createdAt: Date(),
            source: source,
            tags: tags,
            customTags: customTags
        )
    }
}
