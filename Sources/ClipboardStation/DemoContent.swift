import Foundation

enum DemoContent {
    static func makeSnippets(now: Date = Date()) -> [Snippet] {
        [
            Snippet(
                id: UUID(),
                text: """
                [内容已脱敏] 提取多个 AI 回答的共同结论，保留关键差异，再组合为一段可继续使用的提示词。
                """,
                title: "匿名 AI 讨论片段",
                createdAt: now,
                source: .manualPasteboardImport,
                kind: .text,
                tags: ["prompt", "workflow", "AI"]
            ),
            Snippet(
                id: UUID(),
                text: """
                [字段已脱敏]\t结论\t下一步
                来源 A\t结构清晰\t复用框架
                来源 B\t表达自然\t整理措辞
                来源 C\t信息完整\t继续核对
                """,
                title: "匿名表格摘录",
                createdAt: now.addingTimeInterval(-60),
                source: .manualPasteboardImport,
                kind: .spreadsheet,
                tags: ["table", "research", "AI"]
            ),
            Snippet(
                id: UUID(),
                text: """
                [截图文字已脱敏] 这是一条用于视频演示的本地占位内容，不包含真实姓名、账号、路径或剪贴板数据。
                """,
                title: "匿名截图摘录",
                createdAt: now.addingTimeInterval(-120),
                source: .manualPasteboardImport,
                kind: .text,
                tags: ["screenshot", "ux", "shortcut"]
            )
        ]
    }
}
