import Foundation
import Network

struct CollectedWebImage: Sendable {
    let data: Data
    let title: String
    let ocrText: String
    let index: Int
    let batchID: String
    let total: Int
}

final class ImageCollectorBridge: @unchecked Sendable {
    static let port: NWEndpoint.Port = 47_831
    private static let maximumRequestSize = 20 * 1_024 * 1_024

    private let queue = DispatchQueue(label: "com.local.clipboard-station.image-collector")
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var pendingCaptureUntil: Date?
    private var pendingHideUntil: Date?
    private var captureRequestID = 0
    private var consumedRequestID = 0
    private var panelOpen = false
    private let saveImageHandler: @Sendable (CollectedWebImage) async -> Bool

    init(
        port: NWEndpoint.Port = ImageCollectorBridge.port,
        saveImageHandler: @escaping @Sendable (CollectedWebImage) async -> Bool = { _ in false }
    ) {
        self.port = port
        self.saveImageHandler = saveImageHandler
    }

    func start() {
        queue.async { [weak self] in
            guard let self, self.listener == nil else { return }
            do {
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: self.port)
                let listener = try NWListener(using: parameters)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection)
                }
                listener.stateUpdateHandler = { state in
                    if case .failed(let error) = state {
                        NSLog("Image collector bridge failed: \(error)")
                    }
                }
                self.listener = listener
                listener.start(queue: self.queue)
            } catch {
                NSLog("Image collector bridge could not start: \(error)")
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
            self?.pendingCaptureUntil = nil
            self?.pendingHideUntil = nil
            self?.panelOpen = false
        }
    }

    func requestCapture() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: 0)
                    return
                }
                self.captureRequestID += 1
                self.pendingCaptureUntil = Date().addingTimeInterval(8)
                continuation.resume(returning: self.captureRequestID)
            }
        }
    }

    func wasConsumed(_ requestID: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(returning: (self?.consumedRequestID ?? 0) >= requestID)
            }
        }
    }

    func isPanelOpen() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(returning: self?.panelOpen ?? false)
            }
        }
    }

    func requestHidePanel() {
        queue.async { [weak self] in
            self?.pendingHideUntil = Date().addingTimeInterval(8)
            self?.panelOpen = false
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var next = buffer
            if let data {
                next.append(data)
            }
            guard next.count <= Self.maximumRequestSize else {
                self.sendJSON(["ok": false, "error": "图片超过 20 MB"], status: "413 Payload Too Large", on: connection)
                return
            }
            if let request = Self.parseRequest(next) {
                self.process(request, on: connection)
            } else if isComplete || error != nil {
                self.sendJSON(["ok": false, "error": "本地请求不完整"], status: "400 Bad Request", on: connection)
            } else {
                self.receiveRequest(on: connection, buffer: next)
            }
        }
    }

    private func process(_ request: LocalRequest, on connection: NWConnection) {
        if request.method == "OPTIONS" {
            sendJSON(["ok": true], on: connection)
            return
        }
        if request.method == "POST", request.path == "/ocr" {
            let imageData = request.body
            let owner = self
            DispatchQueue.global(qos: .userInitiated).async {
                let text = OCRTextRecognizer.recognize(data: imageData) ?? ""
                owner.queue.async {
                    owner.sendJSON(["ok": !text.isEmpty, "text": text], on: connection)
                }
            }
            return
        }
        if request.method == "POST", request.path.hasPrefix("/save-image") {
            let origin = request.headers["origin"] ?? ""
            guard origin.isEmpty || origin.hasPrefix("chrome-extension://") else {
                sendJSON(["ok": false, "error": "只接受灵感收图扩展"], status: "403 Forbidden", on: connection)
                return
            }
            let imageData = request.body
            let metadata = Self.saveImageMetadata(from: request.path)
            let owner = self
            Task.detached(priority: .userInitiated) {
                let text = OCRTextRecognizer.recognize(data: imageData) ?? ""
                let saved = await owner.saveImageHandler(CollectedWebImage(
                    data: imageData,
                    title: metadata.title,
                    ocrText: text,
                    index: metadata.index,
                    batchID: metadata.batchID,
                    total: metadata.total
                ))
                owner.queue.async {
                    owner.sendJSON([
                        "ok": saved,
                        "recognized": !text.isEmpty
                    ], on: connection)
                }
            }
            return
        }

        let isPanelStateUpdate = request.path.hasPrefix("/panel-state?")
        if isPanelStateUpdate {
            panelOpen = request.path.contains("open=1") || request.path.contains("open=true")
        }
        let isCapturePoll = request.path == "/capture"
        let shouldCapture = isCapturePoll && consumePendingCapture()
        let shouldHide = isCapturePoll && consumePendingHide()
        let isPending = pendingCaptureUntil.map { $0 >= Date() } ?? false
        sendJSON([
            "capture": shouldCapture,
            "hide": shouldHide,
            "panelOpen": panelOpen,
            "pending": isPending,
            "requestID": captureRequestID,
            "consumedID": consumedRequestID
        ], on: connection)
    }

    private func sendJSON(_ object: [String: Any], status: String = "200 OK", on connection: NWConnection) {
        let body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private struct LocalRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private static func parseRequest(_ data: Data) -> LocalRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator),
              let header = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            return nil
        }
        let lines = header.components(separatedBy: "\r\n")
        let requestParts = lines.first?.split(separator: " ") ?? []
        guard requestParts.count >= 2 else { return nil }
        let headers = lines.dropFirst().reduce(into: [String: String]()) { result, line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return }
            result[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                parts[1].trimmingCharacters(in: .whitespaces)
        }
        let contentLength = lines.dropFirst().compactMap { line -> Int? in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                return nil
            }
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }.first ?? 0
        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }
        return LocalRequest(
            method: String(requestParts[0]).uppercased(),
            path: String(requestParts[1]),
            headers: headers,
            body: Data(data[bodyStart..<(bodyStart + contentLength)])
        )
    }

    private static func saveImageMetadata(from path: String) -> (title: String, index: Int, batchID: String, total: Int) {
        guard let components = URLComponents(string: "http://127.0.0.1\(path)") else {
            return ("网页图片", 1, UUID().uuidString, 1)
        }
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let title = values["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let index = max(Int(values["index"] ?? "") ?? 1, 1)
        let batchID = values["batch"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let total = max(Int(values["total"] ?? "") ?? 1, 1)
        return (
            title.isEmpty ? "网页图片" : title,
            index,
            batchID.isEmpty ? UUID().uuidString : batchID,
            total
        )
    }

    private func consumePendingCapture() -> Bool {
        guard let pendingCaptureUntil, pendingCaptureUntil >= Date() else {
            self.pendingCaptureUntil = nil
            return false
        }
        self.pendingCaptureUntil = nil
        consumedRequestID = captureRequestID
        return true
    }

    private func consumePendingHide() -> Bool {
        guard let pendingHideUntil, pendingHideUntil >= Date() else {
            self.pendingHideUntil = nil
            return false
        }
        self.pendingHideUntil = nil
        panelOpen = false
        return true
    }
}
