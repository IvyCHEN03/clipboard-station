import AppKit
import XCTest
@testable import ClipboardStation

final class StationPanelTests: XCTestCase {
    func testPositionLockKeepsOriginUntilUnpinned() async {
        await MainActor.run {
            let panel = StationPanel(
                contentRect: NSRect(x: 100, y: 120, width: 440, height: 620),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false
            )
            let originalOrigin = panel.frame.origin
            let requestedOrigin = NSPoint(x: originalOrigin.x + 80, y: originalOrigin.y + 60)

            panel.setPositionLocked(true)
            panel.setFrameOrigin(requestedOrigin)

            XCTAssertFalse(panel.isMovable)
            XCTAssertFalse(panel.styleMask.contains(.resizable))
            XCTAssertEqual(panel.frame.origin, originalOrigin)
            XCTAssertEqual(panel.level, .floating)

            panel.setPositionLocked(false)
            panel.setFrameOrigin(requestedOrigin)

            XCTAssertTrue(panel.isMovable)
            XCTAssertTrue(panel.styleMask.contains(.resizable))
            XCTAssertEqual(panel.frame.origin, requestedOrigin)
            XCTAssertEqual(panel.level, .normal)
        }
    }
}
