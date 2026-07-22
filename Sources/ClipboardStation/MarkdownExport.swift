import Foundation

enum MarkdownExport {
    static func render(snippets: [Snippet], title: String = "Linggan Floating Ball Export", exportedAt: Date = Date()) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Exported at: \(isoString(exportedAt))",
            "",
            "Snippets: \(snippets.count)"
        ]

        for (index, snippet) in snippets.enumerated() {
            lines.append("")
            lines.append("## \(index + 1). \(escapeHeading(snippet.title))")
            lines.append("")
            lines.append("- Kind: \(snippet.kind.label)")
            lines.append("- Source: \(snippet.source.label)")
            lines.append("- Created: \(isoString(snippet.createdAt))")
            if !snippet.tags.isEmpty {
                lines.append("- Tags: \(snippet.tags.joined(separator: ", "))")
            }
            let attachmentNames = snippet.allAttachmentFileNames.filter { !$0.isEmpty }
            if !attachmentNames.isEmpty {
                lines.append("- Attachments: \(attachmentNames.joined(separator: ", "))")
            }
            lines.append("")
            lines.append("```")
            lines.append(body(for: snippet))
            lines.append("```")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func body(for snippet: Snippet) -> String {
        let text = snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }
        if snippet.kind == .screenshot {
            return "[Screenshot has no OCR text]"
        }
        if !snippet.allAttachmentFileNames.isEmpty {
            return "[Attachments: \(snippet.allAttachmentFileNames.joined(separator: ", "))]"
        }
        return "[No text]"
    }

    private static func escapeHeading(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
