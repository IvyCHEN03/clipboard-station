import AppKit
import SwiftUI

final class StationPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }

        let selector: Selector?
        switch key {
        case "a":
            selector = #selector(NSText.selectAll(_:))
        case "c":
            selector = #selector(NSText.copy(_:))
        case "v":
            selector = #selector(NSText.paste(_:))
        case "x":
            selector = #selector(NSText.cut(_:))
        default:
            selector = nil
        }

        if let selector, NSApp.sendAction(selector, to: nil, from: self) {
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    private enum DefaultsKey {
        static let stationOriginX = "station-window-origin-x"
        static let stationOriginY = "station-window-origin-y"
    }

    private let store = SnippetStore()
    private let isVideoDemo = ProcessInfo.processInfo.environment["CLIPBOARD_STATION_VIDEO_DEMO"] == "1"
    private let monitor: ClipboardMonitor
    private let screenshotMonitor: ScreenshotShortcutMonitor
    private let imageCollectorBridge = ImageCollectorBridge()
    private let hotKey = HotKeyController()
    private let keyboardMonitor = KeyboardShortcutMonitor()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var floatingTrigger: FloatingTriggerController?
    private var stationWindow: NSPanel?
    private var didPromptForAccessibility = false
    private var carbonHotKeyActive = false
    private var eventTapActive = false

    private static let videoDemoCommand = Notification.Name("com.local.clipboard-station.video-demo-command")

    override init() {
        monitor = ClipboardMonitor(store: store)
        screenshotMonitor = ScreenshotShortcutMonitor(store: store)
        super.init()
        configureStatusItem()
        configureStationWindow()
        if !isVideoDemo {
            configureFloatingTrigger()
            configureReopenObserver()
            configureServices()
        } else {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(handleVideoDemoCommand(_:)),
                name: Self.videoDemoCommand,
                object: nil
            )
        }
        showStationWindow()
    }

    func stop() {
        monitor.stop()
        screenshotMonitor.stop()
        hotKey.stop()
        keyboardMonitor.stop()
        imageCollectorBridge.stop()
        floatingTrigger?.close()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleVideoDemoCommand(_ notification: Notification) {
        guard isVideoDemo, let command = notification.object as? String else { return }
        store.applyVideoDemoCommand(command)
        showStationWindow()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = Self.menuBarBubbleIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "灵感悬浮球：点击打开/关闭"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private static func menuBarBubbleIcon() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let bubbleRect = NSRect(x: 2, y: 3, width: 16, height: 14)
        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 7, yRadius: 7)
        NSColor(calibratedRed: 0.42, green: 0.74, blue: 1.0, alpha: 1).setFill()
        bubble.fill()

        let shine = NSBezierPath(ovalIn: NSRect(x: 5, y: 11, width: 5, height: 4))
        NSColor.white.withAlphaComponent(0.65).setFill()
        shine.fill()

        let sparkle = NSBezierPath()
        sparkle.move(to: NSPoint(x: 12, y: 13.5))
        sparkle.line(to: NSPoint(x: 13.3, y: 10.8))
        sparkle.line(to: NSPoint(x: 16, y: 9.5))
        sparkle.line(to: NSPoint(x: 13.3, y: 8.2))
        sparkle.line(to: NSPoint(x: 12, y: 5.5))
        sparkle.line(to: NSPoint(x: 10.7, y: 8.2))
        sparkle.line(to: NSPoint(x: 8, y: 9.5))
        sparkle.line(to: NSPoint(x: 10.7, y: 10.8))
        sparkle.close()
        NSColor.white.setFill()
        sparkle.fill()

        image.unlockFocus()
        image.isTemplate = false
        image.accessibilityDescription = "灵感悬浮球"
        return image
    }

    private func configureStationWindow() {
        let rootView = StationView(
            store: store,
            quitApp: { Self.quitCompletely() },
            restartApp: { Self.restartApplication() }
        )
        let host = NSHostingController(rootView: rootView)
        let panel = StationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = host
        panel.title = isVideoDemo ? "灵感悬浮球 Demo" : "灵感悬浮球"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        stationWindow = panel
        restoreStationWindowPosition()
    }

    private static func restartApplication() {
        let bundleURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep 0.5; /usr/bin/open \"$1\"",
            "restart-linggan",
            bundleURL.path
        ]
        try? process.run()
        NSApp.terminate(nil)
    }

    private static func quitCompletely() {
        let label = "com.local.clipboard-station.agent"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        if (try? process.run()) != nil {
            process.waitUntilExit()
        }
        NSApp.terminate(nil)
    }

    private func configureFloatingTrigger() {
        floatingTrigger = FloatingTriggerController(
            action: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    if await self.imageCollectorBridge.isPanelOpen() {
                        self.imageCollectorBridge.requestHidePanel()
                    } else {
                        self.togglePopoverFromKeyboard()
                    }
                }
            },
            commandAction: { [weak self] in
                self?.captureBrowserImagesFromFloatingTrigger()
            },
            restartAction: { Self.restartApplication() },
            quitAction: { Self.quitCompletely() }
        )
        floatingTrigger?.show()
    }

    private func configureReopenObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showFromExternalOpen(_:)),
            name: Notification.Name("com.local.clipboard-station.reopen"),
            object: nil
        )
    }

    private func configureServices() {
        imageCollectorBridge.start()
        store.settingsChanged = { [weak self] settings in
            Task { @MainActor in
                self?.applyRuntimeSettings(settings)
            }
        }
        applyRuntimeSettings(store.settings)
    }

    private func applyRuntimeSettings(_ settings: StationSettings) {
        monitor.start()
        screenshotMonitor.start()
        restartHotKey()
        restartKeyboardMonitor()
        refreshShortcutStatus()
        LaunchAtLogin.setEnabled(settings.launchAtLogin)
    }

    private func restartHotKey() {
        carbonHotKeyActive = hotKey.start(settings: store.settings) { [weak self] in
            self?.showStationWindow()
            self?.refreshShortcutStatus()
            self?.store.showToast("已打开")
        } quitHandler: { [weak self] in
            self?.hideStationWindow()
            self?.store.showToast("已收起，可从菜单栏或小泡泡打开")
        }
    }

    private func restartKeyboardMonitor() {
        eventTapActive = keyboardMonitor.start { [weak self] in
            self?.showStationWindow()
            self?.refreshShortcutStatus()
            self?.store.showToast("已打开")
        } copyHandler: { [weak self] in
            self?.captureRecentClipboardCopy()
        } quitHandler: { [weak self] in
            self?.hideStationWindow()
            self?.store.showToast("已收起，可从菜单栏或小泡泡打开")
        }
    }

    private func refreshShortcutStatus() {
        let accessibilityTrusted = AccessibilityService.isTrusted(prompt: false)
        let active = carbonHotKeyActive || eventTapActive
        let detail: String
        if carbonHotKeyActive {
            detail = "Cmd+Shift+C 全局热键正常"
        } else if eventTapActive {
            detail = "Cmd+Shift+C 后备监听正常"
        } else if accessibilityTrusted {
            detail = "Cmd+Shift+C 注册失败，可能被其他 App 占用"
        } else {
            detail = "需要辅助功能权限或释放快捷键冲突"
        }
        store.isAccessibilityTrusted = accessibilityTrusted
        store.refreshRuntimeStatus(shortcutListening: active, detail: detail)
    }

    private func captureRecentClipboardCopy() {
        guard store.settings.monitorClipboard, !NSApp.isActive else {
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            store.addPasteboardContents(source: .clipboardCopy)
            store.ignorePasteboardChange(NSPasteboard.general.changeCount)
        }
    }

    private func captureSelection() {
        let shouldPrompt = !didPromptForAccessibility
        didPromptForAccessibility = true
        guard AccessibilityService.isTrusted(prompt: shouldPrompt) else {
            showStationWindow()
            store.showToast("已打开。开启辅助功能权限后可同时拉取选中文本")
            return
        }

        let pasteboard = NSPasteboard.general
        AccessibilityService.sendCommandC()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                showStationWindow()
                store.showToast("已打开")
                return
            }
            store.add(text: text, source: .hotkeySelection, force: true)
            showStationWindow()
        }
    }

    private func captureBrowserImagesFromFloatingTrigger() {
        Task { [weak self] in
            guard let self else { return }
            let requestID = await imageCollectorBridge.requestCapture()
            store.showToast("正在收取当前浏览器帖子图片")
            try? await Task.sleep(for: .seconds(2))
            guard requestID > 0,
                  !(await imageCollectorBridge.wasConsumed(requestID)) else {
                return
            }
            store.showToast("浏览器扩展未响应：请重新加载 Linggan Image Collector 并刷新帖子")
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        togglePopoverFromKeyboard()
    }

    @objc private func showFromExternalOpen(_ notification: Notification) {
        showStationWindow()
        store.showToast("已打开")
    }

    private func togglePopoverFromKeyboard() {
        if stationWindow?.isVisible == true {
            hideStationWindow()
        } else {
            showStationWindow()
        }
    }

    func windowWillClose(_ notification: Notification) {
        saveStationWindowPosition()
        NSApp.deactivate()
    }

    func windowDidMove(_ notification: Notification) {
        saveStationWindowPosition()
    }

    private func hideStationWindow() {
        stationWindow?.orderOut(nil)
        NSApp.deactivate()
    }

    private func showStationWindow() {
        guard let stationWindow else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        stationWindow.makeKeyAndOrderFront(nil)
    }

    private func restoreStationWindowPosition() {
        guard let stationWindow, let screen = NSScreen.main else { return }
        let defaults = UserDefaults.standard
        let savedX = defaults.object(forKey: DefaultsKey.stationOriginX) as? Double
        let savedY = defaults.object(forKey: DefaultsKey.stationOriginY) as? Double
        let visibleFrame = screen.visibleFrame
        let size = stationWindow.frame.size
        let fallback = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        let requested = NSPoint(x: savedX ?? fallback.x, y: savedY ?? fallback.y)
        let matchingScreen = NSScreen.screens.first { screen in
            screen.visibleFrame.intersects(NSRect(origin: requested, size: size))
        } ?? screen
        let frame = matchingScreen.visibleFrame
        let origin = NSPoint(
            x: min(max(requested.x, frame.minX), frame.maxX - size.width),
            y: min(max(requested.y, frame.minY), frame.maxY - size.height)
        )
        stationWindow.setFrameOrigin(origin)
    }

    private func saveStationWindowPosition() {
        guard let origin = stationWindow?.frame.origin else { return }
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.stationOriginX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.stationOriginY)
    }
}
