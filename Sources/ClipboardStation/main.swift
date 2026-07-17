import AppKit
import Darwin

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
configureMainMenu()
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?
    private var instanceLock: InstanceLock?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isVideoDemo = ProcessInfo.processInfo.environment["CLIPBOARD_STATION_VIDEO_DEMO"] == "1"
        if !isVideoDemo {
            guard let lock = InstanceLock.acquire() else {
                DistributedNotificationCenter.default().postNotificationName(
                    .clipboardStationReopen,
                    object: nil
                )
                NSApp.terminate(nil)
                return
            }
            instanceLock = lock
        }
        statusController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController?.stop()
    }
}

private extension Notification.Name {
    static let clipboardStationReopen = Notification.Name("com.local.clipboard-station.reopen")
}

private final class InstanceLock {
    private let fileDescriptor: Int32

    private init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }

    static func acquire() -> InstanceLock? {
        let directory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClipboardStation", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockPath = directory.appendingPathComponent("app.lock").path
        let fileDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return nil
        }
        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            return nil
        }
        return InstanceLock(fileDescriptor: fileDescriptor)
    }
}

@MainActor
private func configureMainMenu() {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
        withTitle: "退出灵感悬浮球",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: ""
    )
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    NSApplication.shared.mainMenu = mainMenu
}
