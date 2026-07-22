import Foundation

struct ClipboardBackup: Codable, Equatable {
    var formatVersion: Int
    var appVersion: String
    var exportedAt: Date
    var snippets: [Snippet]
    var settings: StationSettings
    var attachments: [BackupAttachment]

    static let currentFormatVersion = 1
}

struct BackupAttachment: Codable, Equatable {
    var snippetID: UUID
    var fileName: String
    var data: Data
}

enum ClipboardBackupError: Error, Equatable {
    case unsupportedVersion(Int)
}

enum ClipboardBackupCodec {
    static func makeBackup(
        snippets: [Snippet],
        settings: StationSettings,
        appVersion: String,
        exportedAt: Date = Date()
    ) -> ClipboardBackup {
        let attachments = snippets.flatMap { snippet -> [BackupAttachment] in
            let names = snippet.allAttachmentFileNames
            return snippet.allAttachmentPaths.enumerated().compactMap { index, attachmentPath in
                let url = URL(fileURLWithPath: attachmentPath)
                guard let data = try? Data(contentsOf: url) else {
                    return nil
                }
                let fileName = names.indices.contains(index) ? names[index] : url.lastPathComponent
                return BackupAttachment(
                    snippetID: snippet.id,
                    fileName: fileName,
                    data: data
                )
            }
        }

        return ClipboardBackup(
            formatVersion: ClipboardBackup.currentFormatVersion,
            appVersion: appVersion,
            exportedAt: exportedAt,
            snippets: snippets,
            settings: settings,
            attachments: attachments
        )
    }

    static func encode(_ backup: ClipboardBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> ClipboardBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(ClipboardBackup.self, from: data)
        guard backup.formatVersion <= ClipboardBackup.currentFormatVersion else {
            throw ClipboardBackupError.unsupportedVersion(backup.formatVersion)
        }
        return backup
    }
}
