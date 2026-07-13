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

    init(action: @escaping () -> Void) {
        self.action = action
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
        .onTapGesture {
            action()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 7)
                .onChanged { value in
                    pressed = true
                    dragChanged(value.translation)
                }
                .onEnded { _ in
                    pressed = false
                    dragEnded()
                }
        )
        .onHover { hovering = $0 }
        .help("点一下打开/关闭灵感悬浮球，拖动可换位置")
    }
}
