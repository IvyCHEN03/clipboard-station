import Foundation

enum AppMetadata {
    static let version: String = {
        if let override = ProcessInfo.processInfo.environment["CLIPBOARD_STATION_VERSION_OVERRIDE"],
           !override.isEmpty {
            return override
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0"
    }()

    static let build: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
    }()

    static var displayVersion: String {
        "v\(version)"
    }
}
