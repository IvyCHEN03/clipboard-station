import Foundation
import Network
import XCTest
@testable import ClipboardStation

final class ImageCollectorBridgeTests: XCTestCase {
    private actor SavedImageBox {
        private(set) var image: CollectedWebImage?

        func store(_ image: CollectedWebImage) {
            self.image = image
        }
    }

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

    func testOCRRouteAcceptsPostedImageBody() async throws {
        let port: NWEndpoint.Port = 47_834
        let bridge = ImageCollectorBridge(port: port)
        bridge.start()
        defer { bridge.stop() }

        try await Task.sleep(for: .milliseconds(250))
        let url = URL(string: "http://127.0.0.1:\(port.rawValue)/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("not-an-image".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["ok"] as? Bool, false)
        XCTAssertEqual(result["text"] as? String, "")
    }

    func testSaveImageRouteDeliversImageToNativeHandler() async throws {
        let port: NWEndpoint.Port = 47_835
        let box = SavedImageBox()
        let bridge = ImageCollectorBridge(port: port) { image in
            await box.store(image)
            return true
        }
        bridge.start()
        defer { bridge.stop() }

        try await Task.sleep(for: .milliseconds(250))
        let title = "帖子灵感 · 1/2"
        var components = URLComponents(string: "http://127.0.0.1:\(port.rawValue)/save-image")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "index", value: "1"),
            URLQueryItem(name: "batch", value: "test-batch"),
            URLQueryItem(name: "total", value: "2")
        ]
        var request = URLRequest(url: try XCTUnwrap(components.url))
        request.httpMethod = "POST"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.setValue("chrome-extension://test-extension", forHTTPHeaderField: "Origin")
        request.httpBody = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["ok"] as? Bool, true)

        let saved = await box.image
        XCTAssertEqual(saved?.title, title)
        XCTAssertEqual(saved?.index, 1)
        XCTAssertEqual(saved?.batchID, "test-batch")
        XCTAssertEqual(saved?.total, 2)
        XCTAssertEqual(saved?.data, request.httpBody)
    }
}
