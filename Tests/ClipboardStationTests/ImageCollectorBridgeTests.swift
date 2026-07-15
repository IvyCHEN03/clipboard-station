import Foundation
import Network
import XCTest
@testable import ClipboardStation

final class ImageCollectorBridgeTests: XCTestCase {
    func testCaptureRequestIsDeliveredOnce() async throws {
        let port: NWEndpoint.Port = 47_832
        let bridge = ImageCollectorBridge(port: port)
        bridge.start()
        defer { bridge.stop() }

        try await Task.sleep(for: .milliseconds(250))
        let requestID = await bridge.requestCapture()
        XCTAssertEqual(requestID, 1)
        try await Task.sleep(for: .milliseconds(50))

        let url = URL(string: "http://127.0.0.1:\(port.rawValue)/capture")!
        let (firstData, _) = try await URLSession.shared.data(from: url)
        let first = try XCTUnwrap(JSONSerialization.jsonObject(with: firstData) as? [String: Any])
        XCTAssertEqual(first["capture"] as? Bool, true)
        XCTAssertEqual(first["requestID"] as? Int, 1)
        XCTAssertEqual(first["consumedID"] as? Int, 1)

        let (secondData, _) = try await URLSession.shared.data(from: url)
        let second = try XCTUnwrap(JSONSerialization.jsonObject(with: secondData) as? [String: Any])
        XCTAssertEqual(second["capture"] as? Bool, false)
        XCTAssertEqual(second["hide"] as? Bool, false)
        XCTAssertEqual(second["requestID"] as? Int, 1)
        XCTAssertEqual(second["consumedID"] as? Int, 1)
        let wasConsumed = await bridge.wasConsumed(requestID)
        XCTAssertTrue(wasConsumed)
    }

    func testPanelStateAndHideRequestAreDelivered() async throws {
        let port: NWEndpoint.Port = 47_833
        let bridge = ImageCollectorBridge(port: port)
        bridge.start()
        defer { bridge.stop() }

        try await Task.sleep(for: .milliseconds(250))
        let openURL = URL(string: "http://127.0.0.1:\(port.rawValue)/panel-state?open=1")!
        _ = try await URLSession.shared.data(from: openURL)
        let isOpen = await bridge.isPanelOpen()
        XCTAssertTrue(isOpen)

        bridge.requestHidePanel()
        try await Task.sleep(for: .milliseconds(50))
        let isOpenAfterHide = await bridge.isPanelOpen()
        XCTAssertFalse(isOpenAfterHide)

        let pollURL = URL(string: "http://127.0.0.1:\(port.rawValue)/capture")!
        let (firstData, _) = try await URLSession.shared.data(from: pollURL)
        let first = try XCTUnwrap(JSONSerialization.jsonObject(with: firstData) as? [String: Any])
        XCTAssertEqual(first["hide"] as? Bool, true)

        let (secondData, _) = try await URLSession.shared.data(from: pollURL)
        let second = try XCTUnwrap(JSONSerialization.jsonObject(with: secondData) as? [String: Any])
        XCTAssertEqual(second["hide"] as? Bool, false)
    }
}
