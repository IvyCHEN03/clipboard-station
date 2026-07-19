import Carbon
import XCTest
@testable import ClipboardStation

final class KeyboardShortcutDefinitionTests: XCTestCase {
    func testFormatsCustomShortcut() {
        XCTAssertEqual(
            KeyboardShortcutDefinition.displayName(
                keyCode: UInt32(kVK_ANSI_P),
                modifiers: UInt32(cmdKey | optionKey)
            ),
            "Cmd+Option+P"
        )
        XCTAssertEqual(KeyboardShortcutDefinition.keyLabel(for: 999), "Key 999")
    }

    func testRejectsReservedAndUnmodifiedShortcuts() {
        XCTAssertNotNil(
            KeyboardShortcutDefinition.validationMessage(
                keyCode: UInt32(kVK_ANSI_A),
                modifiers: 0
            )
        )
        XCTAssertNotNil(
            KeyboardShortcutDefinition.validationMessage(
                keyCode: UInt32(kVK_ANSI_C),
                modifiers: UInt32(cmdKey)
            )
        )
        XCTAssertNotNil(
            KeyboardShortcutDefinition.validationMessage(
                keyCode: UInt32(kVK_ANSI_Z),
                modifiers: UInt32(cmdKey | shiftKey)
            )
        )
    }

    func testMatchesOnlyExactSupportedModifiers() {
        XCTAssertTrue(
            KeyboardShortcutDefinition.matches(
                keyCode: UInt32(kVK_ANSI_K),
                modifiers: UInt32(cmdKey | shiftKey),
                expectedKeyCode: UInt32(kVK_ANSI_K),
                expectedModifiers: UInt32(cmdKey | shiftKey)
            )
        )
        XCTAssertFalse(
            KeyboardShortcutDefinition.matches(
                keyCode: UInt32(kVK_ANSI_K),
                modifiers: UInt32(cmdKey | shiftKey | optionKey),
                expectedKeyCode: UInt32(kVK_ANSI_K),
                expectedModifiers: UInt32(cmdKey | shiftKey)
            )
        )
    }
}
