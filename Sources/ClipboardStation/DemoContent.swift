import Foundation

enum DemoContent {
    static func makeSnippets(now: Date = Date()) -> [Snippet] {
        [
            Snippet(
                id: UUID(),
                text: """
                Compare answers from ChatGPT, Claude, and Codex. Keep the strongest claim from each model, then combine them into one sharper prompt.
                """,
                title: "Multi-AI prompt notes",
                createdAt: now,
                source: .manualPasteboardImport,
                kind: .text,
                tags: ["prompt", "workflow", "AI"]
            ),
            Snippet(
                id: UUID(),
                text: """
                Source\tSignal\tNext step
                ChatGPT\tClear structure\tReuse outline
                Claude\tBetter tone\tBorrow wording
                Codex\tImplementation detail\tVerify in repo
                """,
                title: "Comparison table",
                createdAt: now.addingTimeInterval(-60),
                source: .manualPasteboardImport,
                kind: .spreadsheet,
                tags: ["table", "research", "AI"]
            ),
            Snippet(
                id: UUID(),
                text: """
                Screenshot OCR example: user wants the floating bubble to stay visible, open quickly, and avoid fragile global shortcut conflicts.
                """,
                title: "Screenshot insight",
                createdAt: now.addingTimeInterval(-120),
                source: .manualPasteboardImport,
                kind: .text,
                tags: ["screenshot", "ux", "shortcut"]
            )
        ]
    }
}
