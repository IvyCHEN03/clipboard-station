import AppKit
import SwiftUI
import XCTest
@testable import ClipboardStation

final class MarketingScreenshotTests: XCTestCase {
    @MainActor
    func testRenderLatestInterfaceWhenRequested() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["CLIPBOARD_STATION_RENDER_SCREENSHOT"],
              !outputPath.isEmpty else {
            return
        }

        let store = SnippetStore()
        let view = NSHostingView(
            rootView: StationView(
                store: store,
                quitApp: {},
                restartApp: {},
                setPinned: { _ in }
            )
        )
        view.frame = NSRect(x: 0, y: 0, width: 720, height: 920)
        view.wantsLayer = true
        view.layer?.contentsScale = 2
        view.layoutSubtreeIfNeeded()

        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            XCTFail("Could not create marketing screenshot bitmap")
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not encode marketing screenshot")
            return
        }
        try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
}
