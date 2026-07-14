import AppKit
import Carbon
import Foundation

enum AccessibilityService {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func sendCommandC() {
        sendKey(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
    }

    static func sendCommandV() {
        sendKey(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }

    static func sendImageCollectorShortcut(to processID: pid_t) {
        sendKey(
            keyCode: CGKeyCode(kVK_ANSI_L),
            flags: [.maskControl, .maskShift],
            processID: processID
        )
    }

    private static func sendKey(keyCode: CGKeyCode, flags: CGEventFlags, processID: pid_t? = nil) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        if let processID {
            down?.postToPid(processID)
            up?.postToPid(processID)
        } else {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
