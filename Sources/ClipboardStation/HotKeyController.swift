import Carbon
import Foundation

@MainActor
final class HotKeyController {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var quitHotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var quitHandler: (() -> Void)?

    @discardableResult
    func start(settings: StationSettings, handler: @escaping () -> Void, quitHandler: @escaping () -> Void) -> Bool {
        stop()
        self.handler = handler
        self.quitHandler = quitHandler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard hotKeyID.signature == FourCharCode("CLIP") else {
                    return noErr
                }
                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    if hotKeyID.id == 2 {
                        controller.quitHandler?()
                    } else {
                        controller.handler?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        guard installStatus == noErr else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: FourCharCode("CLIP"), id: 1)
        let registerStatus = RegisterEventHotKey(
            settings.hotkeyKeyCode,
            settings.hotkeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            hotKeyRef = nil
        }

        let quitHotKeyID = EventHotKeyID(signature: FourCharCode("CLIP"), id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Z),
            UInt32(cmdKey | shiftKey),
            quitHotKeyID,
            GetApplicationEventTarget(),
            0,
            &quitHotKeyRef
        )

        return registerStatus == noErr
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let quitHotKeyRef {
            UnregisterEventHotKey(quitHotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        hotKeyRef = nil
        quitHotKeyRef = nil
        eventHandler = nil
    }
}

private func FourCharCode(_ string: String) -> UInt32 {
    var result: UInt32 = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + UInt32(scalar.value)
    }
    return result
}
