import XCTest
@testable import ClipboardStation

final class AIEnrichmentTests: XCTestCase {
    func testDecodesTagsArray() throws {
        let data = """
        {"title":"Prompt notes","tags":["prompt","research","workflow"]}
        """.data(using: .utf8)!

        let enrichment = try JSONDecoder().decode(AIEnrichment.self, from: data)

        XCTAssertEqual(enrichment.title, "Prompt notes")
        XCTAssertEqual(enrichment.tags, ["prompt", "research", "workflow"])
    }

    func testDecodesKeywordsArrayAsTags() throws {
        let data = """
        {"title":"剪贴板","keywords":["AI","复制","整理"]}
        """.data(using: .utf8)!

        let enrichment = try JSONDecoder().decode(AIEnrichment.self, from: data)

        XCTAssertEqual(enrichment.title, "剪贴板")
        XCTAssertEqual(enrichment.tags, ["AI", "复制", "整理"])
    }

    func testSplitsStringTags() throws {
        let data = """
        {"title":"多来源片段","tags":"AI，剪贴板、截图\\n表格 prompt"}
        """.data(using: .utf8)!

        let enrichment = try JSONDecoder().decode(AIEnrichment.self, from: data)

        XCTAssertEqual(enrichment.tags, ["AI", "剪贴板", "截图", "表格", "prompt"])
    }

    func testCleansMarkdownFenceFromPolishedContent() {
        let content = """
        ```text
        第一段与第二段已经自然衔接。
        ```
        """

        XCTAssertEqual(
            AIEnricher.cleanPolishedContent(content),
            "第一段与第二段已经自然衔接。"
        )
    }
}
