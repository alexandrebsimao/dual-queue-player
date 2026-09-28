import AppKit
import Foundation

protocol KeyboardShortcutCaptureResponder: AnyObject {}

enum KeyboardShortcutFormatter {
    static func identifier(for event: NSEvent) -> String? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.command),
              !modifiers.contains(.control),
              !modifiers.contains(.option),
              let character = event.charactersIgnoringModifiers?.lowercased().first,
              !character.isWhitespace else { return nil }

        let base = String(character)
        return modifiers.contains(.shift) ? "shift+\(base)" : base
    }

    static func displayName(for shortcut: String?) -> String {
        guard let shortcut, !shortcut.isEmpty else { return "Clique e pressione uma tecla" }
        return shortcut
            .replacingOccurrences(of: "shift+", with: "⇧")
            .uppercased()
    }
}

@MainActor
final class KeyboardShortcutManager {
    var onKey: ((String) -> Void)?
    var isEnabled = true

    func handle(_ event: NSEvent) -> Bool {
        guard isEnabled, event.type == .keyDown, !isTextInputFocused(in: event) else { return false }
        if event.keyCode == 53 { onKey?("escape"); return true }
        if event.keyCode == 123 { onKey?("left"); return true }
        if event.keyCode == 124 { onKey?("right"); return true }
        if event.keyCode == 49 { onKey?("space"); return true }
        if let shortcut = KeyboardShortcutFormatter.identifier(for: event) {
            onKey?(shortcut)
            return true
        }
        return false
    }

    private func isTextInputFocused(in event: NSEvent) -> Bool {
        var responder = event.window?.firstResponder

        while let current = responder {
            if current is NSTextView || current is NSTextField || current is NSSearchField || current is KeyboardShortcutCaptureResponder {
                return true
            }
            responder = current.nextResponder
        }

        return false
    }
}
