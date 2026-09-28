import AppKit
import Foundation

@MainActor
final class KeyboardShortcutManager {
    var onKey: ((String) -> Void)?
    var isEnabled = true

    func handle(_ event: NSEvent) -> Bool {
        guard isEnabled, event.type == .keyDown, !isTextInputFocused(in: event) else { return false }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let shiftPrefix = event.modifierFlags.contains(.shift) ? "shift+" : ""
        if event.keyCode == 53 { onKey?("escape"); return true }
        if event.keyCode == 123 { onKey?("\(shiftPrefix)left"); return true }
        if event.keyCode == 124 { onKey?("\(shiftPrefix)right"); return true }
        if event.keyCode == 49 { onKey?("space"); return true }
        if !key.isEmpty {
            onKey?("\(shiftPrefix)\(key)")
            return true
        }
        return false
    }

    private func isTextInputFocused(in event: NSEvent) -> Bool {
        var responder = event.window?.firstResponder

        while let current = responder {
            if current is NSTextView || current is NSTextField || current is NSSearchField {
                return true
            }
            responder = current.nextResponder
        }

        return false
    }
}
