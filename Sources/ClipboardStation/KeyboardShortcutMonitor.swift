import AppKit
import Carbon

@MainActor
final class KeyboardShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var openHandler: (() -> Void)?
    private var copyHandler: (() -> Void)?
    private var quitHandler: (() -> Void)?

    var isEventTapActive: Bool {
        eventTap != nil
    }

    @discardableResult
    func start(openHandler: @escaping () -> Void, copyHandler: @escaping () -> Void, quitHandler: @escaping () -> Void) -> Bool {
        stop()
        self.openHandler = openHandler
        self.copyHandler = copyHandler
        self.quitHandler = quitHandler

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                _ = self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = self?.handle(event) ?? false
            if consumed {
                return nil
            }
            return event
        }
        startEventTap()
        return eventTap != nil
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        eventTapSource = nil
        eventTap = nil
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()

        if flags == [.command, .shift], key == "c" {
            openHandler?()
            return true
        } else if flags == [.command, .shift], key == "z" {
            quitHandler?()
            return true
        } else if flags == .command, key == "c" {
            copyHandler?()
        }
        return false
    }

    private func startEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    let monitor = Unmanaged<KeyboardShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                    Task { @MainActor in
                        monitor.enableEventTap()
                    }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<KeyboardShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags
                if monitor.shouldConsume(keyCode: keyCode, flags: flags) {
                    Task { @MainActor in
                        monitor.handle(keyCode: keyCode, flags: flags)
                    }
                    return nil
                }
                Task { @MainActor in
                    monitor.handle(keyCode: keyCode, flags: flags)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func enableEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    private func handle(keyCode: UInt32, flags: CGEventFlags) {
        let command = flags.contains(.maskCommand)
        let shift = flags.contains(.maskShift)

        if command && shift && keyCode == UInt32(kVK_ANSI_C) {
            openHandler?()
        } else if command && shift && keyCode == UInt32(kVK_ANSI_Z) {
            quitHandler?()
        } else if command && !shift && keyCode == UInt32(kVK_ANSI_C) {
            copyHandler?()
        }
    }

    private func shouldConsume(keyCode: UInt32, flags: CGEventFlags) -> Bool {
        let command = flags.contains(.maskCommand)
        let shift = flags.contains(.maskShift)
        return command
            && shift
            && (keyCode == UInt32(kVK_ANSI_C) || keyCode == UInt32(kVK_ANSI_Z))
    }
}
