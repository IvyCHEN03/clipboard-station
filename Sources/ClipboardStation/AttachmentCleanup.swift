import Foundation

enum AttachmentCleanup {
    @discardableResult
    static func removeAttachments(for snippets: [Snippet], in attachmentsDirectory: URL) -> Int {
        var removed = 0
        let base = attachmentsDirectory.standardizedFileURL.path

        for snippet in snippets {
            for attachmentPath in snippet.allAttachmentPaths {
                let url = URL(fileURLWithPath: attachmentPath).standardizedFileURL
                guard url.path.hasPrefix(base + "/") else {
                    continue
                }
                if (try? FileManager.default.removeItem(at: url)) != nil {
                    removed += 1
                }
            }
        }

        return removed
    }
}
