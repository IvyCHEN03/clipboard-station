import Foundation

enum LaunchAtLogin {
    private static let label = "com.local.clipboard-station.agent"

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try installLaunchAgent()
            } else {
                try uninstallLaunchAgent()
            }
        } catch {
            NSLog("ClipboardStation launch-at-login update failed: \(String(describing: error))")
        }
    }

    private static func installLaunchAgent() throws {
        guard let executablePath = Bundle.main.executableURL?.path else {
            return
        }
        let plistURL = try launchAgentURL()
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL, options: [.atomic])
        bootstrap(plistURL: plistURL)
    }

    private static func uninstallLaunchAgent() throws {
        let plistURL = try launchAgentURL()
        bootout(plistURL: plistURL)
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private static func launchAgentURL() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private static func bootstrap(plistURL: URL) {
        runLaunchctl(arguments: ["bootout", guiDomain(), plistURL.path])
        runLaunchctl(arguments: ["bootstrap", guiDomain(), plistURL.path])
    }

    private static func bootout(plistURL: URL) {
        runLaunchctl(arguments: ["bootout", guiDomain(), plistURL.path])
    }

    private static func guiDomain() -> String {
        "gui/\(getuid())"
    }

    private static func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}
