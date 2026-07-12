import Foundation

struct SupportDiagnostics: Equatable {
    var appVersion: String
    var appBuild: String
    var macOSVersion: String
    var snippetCount: Int
    var filteredSnippetCount: Int
    var draftBlockCount: Int
    var monitorClipboard: Bool
    var autoPaste: Bool
    var persistSnippets: Bool
    var launchAtLogin: Bool
    var aiEnrichment: Bool
    var aiProviderHost: String
    var aiModel: String
    var shortcutStatus: String
    var accessibilityTrusted: Bool

    var rendered: String {
        """
        Linggan Floating Ball Diagnostics
        App: \(appVersion) (\(appBuild))
        macOS: \(macOSVersion)
        Snippets: \(filteredSnippetCount)/\(snippetCount) visible
        Draft blocks: \(draftBlockCount)
        Clipboard monitor: \(enabledText(monitorClipboard))
        Auto paste: \(enabledText(autoPaste))
        Persistence: \(enabledText(persistSnippets))
        Launch at login: \(enabledText(launchAtLogin))
        AI tagging: \(enabledText(aiEnrichment))
        AI provider host: \(aiProviderHost)
        AI model: \(redactedIfEmpty(aiModel))
        Shortcut: \(shortcutStatus)
        Accessibility: \(accessibilityTrusted ? "trusted" : "not trusted")
        """
    }

    static func providerHost(from baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let host = url.host,
              !host.isEmpty else {
            return "not configured"
        }
        return host
    }

    private func enabledText(_ value: Bool) -> String {
        value ? "enabled" : "disabled"
    }

    private func redactedIfEmpty(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "not configured" : trimmed
    }
}
