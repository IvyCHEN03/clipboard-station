import Foundation
import XCTest
@testable import ClipboardStation

final class PersistentStoreTests: XCTestCase {
    func testRestoreAllDeletedProtectsRecoveredSnippetsAsFavorites() {
        let active = makeSnippet(title: "Active")
        let deleted = makeSnippet(title: "Recovered")
        var state = PersistedState(
            snippets: [active],
            deletedSnippets: [DeletedSnippet(snippet: deleted, deletedAt: Date())],
            settings: .defaults
        )

        XCTAssertEqual(state.restoreAllDeletedAsFavorites(), 1)
        XCTAssertTrue(state.deletedSnippets.isEmpty)
        XCTAssertEqual(state.snippets.count, 2)
        XCTAssertEqual(state.snippets.first(where: { $0.id == deleted.id })?.isFavorite, true)
    }

    func testCorruptPrimaryFallsBackToLastValidEncryptedBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PersistentStore(directory: directory)
        let first = PersistedState(
            snippets: [makeSnippet(title: "First")],
            settings: .defaults
        )
        let second = PersistedState(
            snippets: [makeSnippet(title: "Second"), makeSnippet(title: "Newest")],
            settings: .defaults
        )

        store.save(first)
        store.save(second)
        try Data("corrupt".utf8).write(
            to: directory.appendingPathComponent("state.enc"),
            options: .atomic
        )

        let recovered = store.loadIfAvailable()
        XCTAssertEqual(recovered?.snippets.map(\.title), ["First"])
    }

    private func makeSnippet(title: String) -> Snippet {
        Snippet(
            id: UUID(),
            text: title,
            title: title,
            createdAt: Date(),
            source: .clipboardCopy
        )
    }
}
