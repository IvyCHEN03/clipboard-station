import Foundation

struct PersistedState: Codable {
    var snippets: [Snippet]
    var deletedSnippets: [DeletedSnippet]
    var settings: StationSettings
    var quickNoteText: String

    enum CodingKeys: String, CodingKey {
        case snippets
        case deletedSnippets
        case settings
        case quickNoteText
    }

    init(
        snippets: [Snippet],
        deletedSnippets: [DeletedSnippet] = [],
        settings: StationSettings,
        quickNoteText: String = ""
    ) {
        self.snippets = snippets
        self.deletedSnippets = deletedSnippets
        self.settings = settings
        self.quickNoteText = quickNoteText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snippets = try container.decode([Snippet].self, forKey: .snippets)
        deletedSnippets = try container.decodeIfPresent([DeletedSnippet].self, forKey: .deletedSnippets) ?? []
        settings = try container.decode(StationSettings.self, forKey: .settings)
        quickNoteText = try container.decodeIfPresent(String.self, forKey: .quickNoteText) ?? ""
    }

    @discardableResult
    mutating func restoreAllDeletedAsFavorites() -> Int {
        let activeIDs = Set(snippets.map(\.id))
        var restored = deletedSnippets
            .map(\.snippet)
            .filter { !activeIDs.contains($0.id) }
        for index in restored.indices {
            restored[index].isFavorite = true
        }
        guard !restored.isEmpty else {
            deletedSnippets.removeAll()
            return 0
        }
        snippets.append(contentsOf: restored)
        snippets.sort { $0.createdAt > $1.createdAt }
        deletedSnippets.removeAll()
        return restored.count
    }
}

final class PersistentStore: @unchecked Sendable {
    private let crypto = KeychainCrypto()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL
    private let backupURL: URL

    init(directory customDirectory: URL? = nil) {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let directory: URL
        if let customDirectory {
            directory = customDirectory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directory = base.appendingPathComponent("ClipboardStation", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("state.enc")
        backupURL = directory.appendingPathComponent("state.backup.enc")
    }

    func load() -> PersistedState {
        loadIfAvailable() ?? PersistedState(snippets: [], deletedSnippets: [], settings: .defaults)
    }

    func loadIfAvailable() -> PersistedState? {
        if !FileManager.default.fileExists(atPath: fileURL.path),
           !FileManager.default.fileExists(atPath: backupURL.path) {
            return PersistedState(snippets: [], deletedSnippets: [], settings: .defaults)
        }
        if let primary = decodeState(at: fileURL) {
            return primary
        }
        let backup = decodeState(at: backupURL)
        if backup != nil {
            NSLog("ClipboardStation restored state from encrypted backup")
        }
        return backup
    }

    func save(_ state: PersistedState) {
        guard state.settings.persistSnippets else {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: backupURL)
            return
        }

        do {
            let plain = try encoder.encode(state)
            let encrypted = try crypto.encrypt(plain)
            if decodeState(at: fileURL) != nil {
                let current = try Data(contentsOf: fileURL)
                try current.write(to: backupURL, options: [.atomic])
            }
            try encrypted.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("ClipboardStation save failed: \(String(describing: error))")
        }
    }

    private func decodeState(at url: URL) -> PersistedState? {
        guard FileManager.default.fileExists(atPath: url.path),
              let encrypted = try? Data(contentsOf: url),
              let decrypted = try? crypto.decrypt(encrypted),
              let state = try? decoder.decode(PersistedState.self, from: decrypted) else {
            return nil
        }
        return state
    }
}
