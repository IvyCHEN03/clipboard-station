import AppKit
import SwiftUI

@MainActor
final class FloatingTriggerController {
    private static let triggerSize = NSSize(width: 36, height: 36)

    private enum DefaultsKey {
        static let originX = "floating-trigger-origin-x"
        static let originY = "floating-trigger-origin-y"
    }

    private var window: NSPanel?
    private var dragStartOrigin: NSPoint?
    private let action: () -> Void
    private let commandAction: () -> Void
    private let restartAction: () -> Void
    private let quitAction: () -> Void

    init(
        action: @escaping () -> Void,
        commandAction: @escaping () -> Void,
        restartAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.action = action
        self.commandAction = commandAction
        self.restartAction = restartAction
        self.quitAction = quitAction
        configureWindow()
    }

    func show() {
        positionWindow()
        window?.orderFrontRegardless()
    }

    func close() {
        window?.close()
        window = nil
    }

    private func configureWindow() {
        let triggerView = FloatingTriggerView(
            action: action,
            commandAction: commandAction,
            restartAction: restartAction,
            quitAction: quitAction,
            dragChanged: { [weak self] translation in
                self?.moveWindow(translation: translation)
            },
            dragEnded: { [weak self] in
                self?.finishDragging()
            }
        )
        let host = NSHostingController(rootView: triggerView)
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        host.view.layer?.masksToBounds = true
        host.view.layer?.cornerRadius = Self.triggerSize.width / 2
        host.view.appearance = NSAppearance(named: .aqua)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.triggerSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = host
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        window = panel
    }

    private func positionWindow() {
        guard let window,
              let screen = NSScreen.main else {
            return
        }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let savedX = UserDefaults.standard.object(forKey: DefaultsKey.originX) as? Double
        let savedY = UserDefaults.standard.object(forKey: DefaultsKey.originY) as? Double
        let fallback = NSPoint(
            x: frame.maxX - size.width - 8,
            y: frame.midY - size.height / 2
        )
        let origin = clamp(
            NSPoint(x: savedX ?? fallback.x, y: savedY ?? fallback.y),
            size: size,
            in: frame
        )
        window.setFrameOrigin(origin)
    }

    private func moveWindow(translation: CGSize) {
        guard let window,
              let screen = window.screen ?? NSScreen.main else {
            return
        }
        if dragStartOrigin == nil {
            dragStartOrigin = window.frame.origin
        }
        guard let dragStartOrigin else {
            return
        }
        let next = NSPoint(
            x: dragStartOrigin.x + translation.width,
            y: dragStartOrigin.y - translation.height
        )
        window.setFrameOrigin(clamp(next, size: window.frame.size, in: screen.visibleFrame))
    }

    private func finishDragging() {
        guard let window,
              let screen = window.screen ?? NSScreen.main else {
            dragStartOrigin = nil
            return
        }
        let frame = screen.visibleFrame
        var origin = window.frame.origin
        let leftDistance = abs(origin.x - frame.minX)
        let rightDistance = abs(frame.maxX - (origin.x + window.frame.width))
        origin.x = leftDistance < rightDistance
            ? frame.minX + 8
            : frame.maxX - window.frame.width - 8
        origin = clamp(origin, size: window.frame.size, in: frame)
        window.setFrameOrigin(origin)
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.originX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.originY)
        dragStartOrigin = nil
    }

    private func clamp(_ origin: NSPoint, size: NSSize, in frame: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, frame.minX + 8), frame.maxX - size.width - 8),
            y: min(max(origin.y, frame.minY + 8), frame.maxY - size.height - 8)
        )
    }
}

private struct FloatingTriggerView: View {
    @State private var hovering = false
    @State private var pressed = false
    let action: () -> Void
    let commandAction: () -> Void
    let restartAction: () -> Void
    let quitAction: () -> Void
    let dragChanged: (CGSize) -> Void
    let dragEnded: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.93, blue: 1.0),
                            Color(red: 0.36, green: 0.70, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(.white.opacity(0.78), lineWidth: 1.2)
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1, y: -1)
            Circle()
                .fill(.white.opacity(0.72))
                .frame(width: 7, height: 5)
                .offset(x: -8, y: -8)
        }
        .frame(width: 32, height: 32)
        .scaleEffect(pressed ? 0.94 : (hovering ? 1.06 : 1.0))
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .frame(width: 36, height: 36)
        .background(Color.clear)
        .clipShape(Circle())
        .contentShape(Circle())
        .overlay {
            FloatingTriggerMouseCapture(
                pressed: $pressed,
                action: action,
                commandAction: commandAction,
                restartAction: restartAction,
                quitAction: quitAction,
                dragChanged: dragChanged,
                dragEnded: dragEnded
            )
        }
        .onHover { hovering = $0 }
        .help("点一下打开/关闭灵感悬浮球，Cmd+点收当前浏览器帖子图片，拖动可换位置")
    }
}

private struct FloatingTriggerMouseCapture: NSViewRepresentable {
    @Binding var pressed: Bool
    let action: () -> Void
    let commandAction: () -> Void
    let restartAction: () -> Void
    let quitAction: () -> Void
    let dragChanged: (CGSize) -> Void
    let dragEnded: () -> Void

    func makeNSView(context: Context) -> CaptureView {
        CaptureView(
            pressed: $pressed,
            action: action,
            commandAction: commandAction,
            restartAction: restartAction,
            quitAction: quitAction,
            dragChanged: dragChanged,
            dragEnded: dragEnded
        )
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.pressed = $pressed
        nsView.action = action
        nsView.commandAction = commandAction
        nsView.restartAction = restartAction
        nsView.quitAction = quitAction
        nsView.dragChanged = dragChanged
        nsView.dragEnded = dragEnded
    }

    final class CaptureView: NSView {
        var pressed: Binding<Bool>
        var action: () -> Void
        var commandAction: () -> Void
        var restartAction: () -> Void
        var quitAction: () -> Void
        var dragChanged: (CGSize) -> Void
        var dragEnded: () -> Void
        private var downLocation: NSPoint?
        private var didDrag = false

        init(
            pressed: Binding<Bool>,
            action: @escaping () -> Void,
            commandAction: @escaping () -> Void,
            restartAction: @escaping () -> Void,
            quitAction: @escaping () -> Void,
            dragChanged: @escaping (CGSize) -> Void,
            dragEnded: @escaping () -> Void
        ) {
            self.pressed = pressed
            self.action = action
            self.commandAction = commandAction
            self.restartAction = restartAction
            self.quitAction = quitAction
            self.dragChanged = dragChanged
            self.dragEnded = dragEnded
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func mouseDown(with event: NSEvent) {
            downLocation = event.locationInWindow
            didDrag = false
            pressed.wrappedValue = true
        }

        override func mouseDragged(with event: NSEvent) {
            guard let downLocation else {
                return
            }
            let current = event.locationInWindow
            let delta = CGSize(
                width: current.x - downLocation.x,
                height: downLocation.y - current.y
            )
            if abs(delta.width) > 4 || abs(delta.height) > 4 {
                didDrag = true
            }
            dragChanged(delta)
        }

        override func mouseUp(with event: NSEvent) {
            defer {
                downLocation = nil
                pressed.wrappedValue = false
            }

            if didDrag {
                dragEnded()
                return
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) {
                commandAction()
            } else {
                action()
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            let menu = NSMenu(title: "灵感悬浮球")
            let captureItem = NSMenuItem(title: "收取当前帖子图片", action: #selector(captureCurrentPost), keyEquivalent: "")
            captureItem.target = self
            menu.addItem(captureItem)
            let openItem = NSMenuItem(title: "打开灵感悬浮球", action: #selector(openStation), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
            menu.addItem(.separator())
            let restartItem = NSMenuItem(title: "重启灵感悬浮球", action: #selector(restartStation), keyEquivalent: "")
            restartItem.target = self
            menu.addItem(restartItem)
            let quitItem = NSMenuItem(title: "彻底退出灵感悬浮球", action: #selector(quitStation), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        @objc private func openStation() {
            action()
        }

        @objc private func captureCurrentPost() {
            commandAction()
        }

        @objc private func restartStation() {
            restartAction()
        }

        @objc private func quitStation() {
            quitAction()
        }
    }
}
