import Foundation

enum ContextPackageError: LocalizedError, Equatable {
    case missingText(String)
    case inputTooLong(Int)

    var errorDescription: String? {
        switch self {
        case let .missingText(title):
            return "“\(title)”没有 OCR 文字，不能加入纯文本 AI 整理"
        case let .inputTooLong(limit):
            return "组合内容超过 \(limit) 字，请减少片段后重试"
        }
    }
}

enum ContextPackageFormatter {
    static let maximumContextLength = 24_000

    static func fullContext(
        snippets: [Snippet],
        instruction: String?,
        textProvider: (Snippet) -> String?
    ) throws -> String {
        var sections: [String] = []
        let cleanInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanInstruction.isEmpty {
            sections.append("用户补充要求：\n\(cleanInstruction)")
        }

        for (index, snippet) in snippets.enumerated() {
            guard let text = textProvider(snippet)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty else {
                throw ContextPackageError.missingText(snippet.title)
            }
            let tags = snippet.allTags.isEmpty ? "无" : snippet.allTags.joined(separator: "、")
            sections.append(
                """
                [片段 \(index + 1)]
                标题：\(snippet.title)
                来源：\(snippet.source.label)
                标签：\(tags)
                正文：
                \(text)
                """
            )
        }

        let result = sections.joined(separator: "\n\n")
        guard result.count <= maximumContextLength else {
            throw ContextPackageError.inputTooLong(maximumContextLength)
        }
        return result
    }

    static func cleanBody(_ result: String) -> String {
        replacingSnippetReferences(in: result)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resultWithSources(_ result: String, snippets: [Snippet]) -> String {
        let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let sources = snippets.enumerated().map { index, snippet in
            "[片段 \(index + 1)] \(snippet.title) · \(snippet.source.label)"
        }
        guard !sources.isEmpty else {
            return cleanResult
        }
        return "\(cleanResult)\n\n来源：\n\(sources.joined(separator: "\n"))"
    }

    private static func replacingSnippetReferences(in value: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: #"\s*\[片段\s*\d+\]\s*"#,
            options: []
        ) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(
            in: value,
            options: [],
            range: range,
            withTemplate: " "
        )
    }
}
