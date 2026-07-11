import AppKit
import Carbon
import Foundation

@MainActor
final class ScreenshotShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollingTask: Task<Void, Never>?
    private var seenScreenshotPaths = Set<String>()
    private weak var store: SnippetStore?

    init(store: SnippetStore) {
        self.store = store
    }

    func start() {
        stop()
        seedSeenScreenshots()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
            return event
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    self?.tryImportAnyNewScreenshot()
                }
            }
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        pollingTask?.cancel()
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard event.keyCode == UInt16(kVK_ANSI_4),
              flags.contains(.command),
              flags.contains(.shift) else {
            return
        }
        beginScreenshotImportWindow()
    }

    private func beginScreenshotImportWindow() {
        let startedAt = Date()
        Task { [weak self] in
            for _ in 0..<90 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run {
                    self?.tryImportRecentScreenshot(after: startedAt)
                }
                if Task.isCancelled {
                    return
                }
            }
        }
    }

    private func tryImportRecentScreenshot(after startedAt: Date) {
        guard let url = latestScreenshot(after: startedAt) else {
            return
        }
        seenScreenshotPaths.insert(url.path)
        store?.addAttachmentFile(from: url, kind: .screenshot, source: .screenshot)
    }

    private func tryImportAnyNewScreenshot() {
        guard let url = latestScreenshot(after: Date().addingTimeInterval(-120)) else {
            return
        }
        seenScreenshotPaths.insert(url.path)
        store?.addAttachmentFile(from: url, kind: .screenshot, source: .screenshot)
    }

    private func latestScreenshot(after startedAt: Date) -> URL? {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        let candidates = [
            desktop,
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        ].compactMap { $0 }

        var newest: (url: URL, date: Date)?
        for directory in candidates {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for file in files where isScreenshotFile(file) && !seenScreenshotPaths.contains(file.path) {
                guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modified = values.contentModificationDate,
                      modified >= startedAt.addingTimeInterval(-1) else {
                    continue
                }
                if newest == nil || modified > newest!.date {
                    newest = (file, modified)
                }
            }
        }
        return newest?.url
    }

    private func seedSeenScreenshots() {
        seenScreenshotPaths.removeAll()
        for directory in screenshotDirectories() {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for file in files where isScreenshotFile(file) {
                seenScreenshotPaths.insert(file.path)
            }
        }
    }

    private func screenshotDirectories() -> [URL] {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return [
            desktop,
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        ].compactMap { $0 }
    }

    private func isScreenshotFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic", "tiff"].contains(ext) else {
            return false
        }
        let name = url.lastPathComponent.lowercased()
        return name.contains("screenshot") || name.contains("截屏")
    }
}
