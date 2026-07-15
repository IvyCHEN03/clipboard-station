import Foundation
import Network

final class ImageCollectorBridge: @unchecked Sendable {
    static let port: NWEndpoint.Port = 47_831

    private let queue = DispatchQueue(label: "com.local.clipboard-station.image-collector")
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var pendingCaptureUntil: Date?
    private var pendingHideUntil: Date?
    private var captureRequestID = 0
    private var consumedRequestID = 0
    private var panelOpen = false

    init(port: NWEndpoint.Port = ImageCollectorBridge.port) {
        self.port = port
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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            let requestLine = data.flatMap { String(data: $0, encoding: .utf8) }?
                .split(separator: "\r\n", maxSplits: 1)
                .first ?? ""
            let isPanelStateUpdate = requestLine.contains(" /panel-state?")
            if isPanelStateUpdate {
                self.panelOpen = requestLine.contains("open=1") || requestLine.contains("open=true")
            }
            let isCapturePoll = requestLine.contains(" /capture ")
            let shouldCapture = isCapturePoll && self.consumePendingCapture()
            let shouldHide = isCapturePoll && self.consumePendingHide()
            let isPending = self.pendingCaptureUntil.map { $0 >= Date() } ?? false
            let body = "{\"capture\":\(shouldCapture ? "true" : "false"),\"hide\":\(shouldHide ? "true" : "false"),\"panelOpen\":\(self.panelOpen ? "true" : "false"),\"pending\":\(isPending ? "true" : "false"),\"requestID\":\(self.captureRequestID),\"consumedID\":\(self.consumedRequestID)}"
            let response = [
                "HTTP/1.1 200 OK",
                "Content-Type: application/json",
                "Content-Length: \(body.utf8.count)",
                "Cache-Control: no-store",
                "Access-Control-Allow-Origin: *",
                "Connection: close",
                "",
                body
            ].joined(separator: "\r\n")
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
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
