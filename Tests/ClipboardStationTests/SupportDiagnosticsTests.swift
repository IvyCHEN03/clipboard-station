import XCTest
@testable import ClipboardStation

final class SupportDiagnosticsTests: XCTestCase {
    func testProviderHostKeepsOnlyHost() {
        XCTAssertEqual(
            SupportDiagnostics.providerHost(from: "https://api.deepseek.com/chat/completions?token=secret"),
            "api.deepseek.com"
        )
    }

    func testProviderHostHandlesMissingURL() {
        XCTAssertEqual(SupportDiagnostics.providerHost(from: ""), "not configured")
        XCTAssertEqual(SupportDiagnostics.providerHost(from: "not a url"), "not configured")
    }

    func testRenderedDiagnosticsAvoidsSecretsAndFullProviderURL() {
        let diagnostics = SupportDiagnostics(
            appVersion: "0.4.0",
            appBuild: "4",
            macOSVersion: "macOS 15.5",
            snippetCount: 12,
            filteredSnippetCount: 3,
            draftBlockCount: 2,
            monitorClipboard: true,
            autoPaste: false,
            persistSnippets: true,
            launchAtLogin: true,
            aiEnrichment: true,
            aiProviderHost: SupportDiagnostics.providerHost(from: "https://api.example.com/chat/completions?api_key=secret"),
            aiModel: "demo-model",
            shortcutStatus: "Cmd+Shift+C 监听正常",
            accessibilityTrusted: false
        )

        let rendered = diagnostics.rendered

        XCTAssertTrue(rendered.contains("App: 0.4.0 (4)"))
        XCTAssertTrue(rendered.contains("Snippets: 3/12 visible"))
        XCTAssertTrue(rendered.contains("AI provider host: api.example.com"))
        XCTAssertFalse(rendered.contains("chat/completions"))
        XCTAssertFalse(rendered.contains("secret"))
    }
}
