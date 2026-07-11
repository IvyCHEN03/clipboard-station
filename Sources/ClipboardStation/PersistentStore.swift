import Foundation

struct PersistedState: Codable {
    var snippets: [Snippet]
    var settings: StationSettings
}

final class PersistentStore {
    private let crypto = KeychainCrypto()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("ClipboardStation", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("state.enc")
    }

    func load() -> PersistedState {
        guard let encrypted = try? Data(contentsOf: fileURL),
              let decrypted = try? crypto.decrypt(encrypted),
              let state = try? decoder.decode(PersistedState.self, from: decrypted) else {
            return PersistedState(snippets: [], settings: .defaults)
        }
        return state
    }

    func save(_ state: PersistedState) {
        guard state.settings.persistSnippets else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        do {
            let plain = try encoder.encode(state)
            let encrypted = try crypto.encrypt(plain)
            try encrypted.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("ClipboardStation save failed: \(String(describing: error))")
        }
    }
}
