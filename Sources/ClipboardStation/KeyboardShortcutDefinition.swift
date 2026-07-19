import AppKit
import Carbon

struct ShortcutKeyOption: Identifiable, Equatable {
    let keyCode: UInt32
    let label: String

    var id: UInt32 { keyCode }
}

enum ShortcutModifier: String, CaseIterable, Identifiable {
    case command
    case shift
    case option
    case control

    var id: String { rawValue }

    var carbonMask: UInt32 {
        switch self {
        case .command: UInt32(cmdKey)
        case .shift: UInt32(shiftKey)
        case .option: UInt32(optionKey)
        case .control: UInt32(controlKey)
        }
    }

    var symbol: String {
        switch self {
        case .command: "⌘"
        case .shift: "⇧"
        case .option: "⌥"
        case .control: "⌃"
        }
    }

    var displayName: String {
        switch self {
        case .command: "Cmd"
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        }
    }
}

enum KeyboardShortcutDefinition {
    static let defaultKeyCode = UInt32(kVK_ANSI_C)
    static let defaultModifiers = UInt32(cmdKey | shiftKey)
    static let quitKeyCode = UInt32(kVK_ANSI_Z)
    static let quitModifiers = UInt32(cmdKey | shiftKey)

    static let supportedKeys: [ShortcutKeyOption] = [
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_A), label: "A"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_B), label: "B"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_C), label: "C"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_D), label: "D"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_E), label: "E"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_F), label: "F"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_G), label: "G"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_H), label: "H"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_I), label: "I"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_J), label: "J"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_K), label: "K"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_L), label: "L"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_M), label: "M"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_N), label: "N"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_O), label: "O"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_P), label: "P"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_Q), label: "Q"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_R), label: "R"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_S), label: "S"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_T), label: "T"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_U), label: "U"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_V), label: "V"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_W), label: "W"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_X), label: "X"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_Y), label: "Y"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_Z), label: "Z"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_0), label: "0"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_1), label: "1"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_2), label: "2"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_3), label: "3"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_4), label: "4"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_5), label: "5"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_6), label: "6"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_7), label: "7"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_8), label: "8"),
        ShortcutKeyOption(keyCode: UInt32(kVK_ANSI_9), label: "9"),
        ShortcutKeyOption(keyCode: UInt32(kVK_Space), label: "Space")
    ]

    static func displayName(keyCode: UInt32, modifiers: UInt32) -> String {
        let modifierNames = ShortcutModifier.allCases.compactMap { modifier in
            modifiers & modifier.carbonMask != 0 ? modifier.displayName : nil
        }
        return (modifierNames + [keyLabel(for: keyCode)]).joined(separator: "+")
    }

    static func keyLabel(for keyCode: UInt32) -> String {
        supportedKeys.first { $0.keyCode == keyCode }?.label ?? "Key \(keyCode)"
    }

    static func isSupported(keyCode: UInt32) -> Bool {
        supportedKeys.contains { $0.keyCode == keyCode }
    }

    static func validationMessage(keyCode: UInt32, modifiers: UInt32) -> String? {
        guard modifiers & supportedModifierMask != 0 else {
            return "请至少选择一个修饰键"
        }
        if keyCode == UInt32(kVK_ANSI_C), modifiers == UInt32(cmdKey) {
            return "Cmd+C 需要保留给普通复制"
        }
        if keyCode == quitKeyCode, modifiers == quitModifiers {
            return "Cmd+Shift+Z 已用于收起窗口"
        }
        return nil
    }

    static func matches(
        keyCode: UInt32,
        modifiers: UInt32,
        expectedKeyCode: UInt32,
        expectedModifiers: UInt32
    ) -> Bool {
        keyCode == expectedKeyCode
            && modifiers & supportedModifierMask == expectedModifiers & supportedModifierMask
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    private static let supportedModifierMask = UInt32(cmdKey | shiftKey | optionKey | controlKey)
}
