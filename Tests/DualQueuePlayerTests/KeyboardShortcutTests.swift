import XCTest
@testable import DualQueuePlayer

final class KeyboardShortcutTests: XCTestCase {
    func testReservedShortcutsIncludeGlobalAndPadKeys() {
        XCTAssertTrue(KeyboardShortcutFormatter.isReserved("a"))
        XCTAssertTrue(KeyboardShortcutFormatter.isReserved("1"))
        XCTAssertTrue(KeyboardShortcutFormatter.isReserved("shift+p"))
        XCTAssertTrue(KeyboardShortcutFormatter.isReserved("command+s"))
        XCTAssertFalse(KeyboardShortcutFormatter.isReserved("c"))
    }

    func testReservedShortcutHasOperationalDescription() {
        let shortcut = KeyboardShortcutFormatter.reservedShortcut(for: "A")

        XCTAssertEqual(shortcut?.displayName, "A")
        XCTAssertEqual(shortcut?.action, "Selecionar a Queue A")
    }

    func testReservedShortcutMapCoversAllApplicationCommands() {
        let expected: Set<String> = [
            "space", "escape", "a", "b", "left", "right",
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
            "p", "shift+p", "command+n", "command+o", "command+s", "command+shift+s"
        ]

        XCTAssertEqual(Set(KeyboardShortcutFormatter.reservedShortcuts.map(\.shortcut)), expected)
    }
}
