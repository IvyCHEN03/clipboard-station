import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private weak var store: SnippetStore?
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    init(store: SnippetStore) {
        self.store = store
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let store, store.settings.monitorClipboard else {
            return
        }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        let didChange = currentChangeCount != lastChangeCount
        lastChangeCount = currentChangeCount

        guard didChange else {
            return
        }

        guard !store.shouldIgnorePasteboardChange(currentChangeCount) else {
            return
        }

        guard !NSApp.isActive else {
            return
        }

        store.addPasteboardContents(source: .clipboardCopy)
    }
}
