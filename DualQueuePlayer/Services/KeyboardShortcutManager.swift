import AppKit
import Foundation

protocol KeyboardShortcutCaptureResponder: AnyObject {}

struct ReservedKeyboardShortcut: Identifiable, Hashable {
    let shortcut: String
    let displayName: String
    let action: String

    var id: String { shortcut }
}

enum KeyboardShortcutFormatter {
    static func identifier(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 53: return "escape"
        case 123: return "left"
        case 124: return "right"
        case 49: return "space"
        default: break
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.command),
              !modifiers.contains(.control),
              !modifiers.contains(.option),
              let character = event.charactersIgnoringModifiers?.lowercased().first,
              !character.isWhitespace else { return nil }

        let base = String(character)
        return modifiers.contains(.shift) ? "shift+\(base)" : base
    }

    static let reservedShortcuts: [ReservedKeyboardShortcut] = [
        ReservedKeyboardShortcut(shortcut: "space", displayName: "Space", action: "Play/Pause da playlist ou controle de cues"),
        ReservedKeyboardShortcut(shortcut: "escape", displayName: "Esc", action: "Parar a playlist ou todos os cues"),
        ReservedKeyboardShortcut(shortcut: "a", displayName: "A", action: "Selecionar a Queue A"),
        ReservedKeyboardShortcut(shortcut: "b", displayName: "B", action: "Selecionar a Queue B"),
        ReservedKeyboardShortcut(shortcut: "left", displayName: "←", action: "Faixa anterior ou seleção anterior"),
        ReservedKeyboardShortcut(shortcut: "right", displayName: "→", action: "Próxima faixa ou próxima seleção"),
        ReservedKeyboardShortcut(shortcut: "1", displayName: "1", action: "Acionar o Pad 1"),
        ReservedKeyboardShortcut(shortcut: "2", displayName: "2", action: "Acionar o Pad 2"),
        ReservedKeyboardShortcut(shortcut: "3", displayName: "3", action: "Acionar o Pad 3"),
        ReservedKeyboardShortcut(shortcut: "4", displayName: "4", action: "Acionar o Pad 4"),
        ReservedKeyboardShortcut(shortcut: "5", displayName: "5", action: "Acionar o Pad 5"),
        ReservedKeyboardShortcut(shortcut: "6", displayName: "6", action: "Acionar o Pad 6"),
        ReservedKeyboardShortcut(shortcut: "7", displayName: "7", action: "Acionar o Pad 7"),
        ReservedKeyboardShortcut(shortcut: "8", displayName: "8", action: "Acionar o Pad 8"),
        ReservedKeyboardShortcut(shortcut: "9", displayName: "9", action: "Acionar o Pad 9"),
        ReservedKeyboardShortcut(shortcut: "0", displayName: "0", action: "Acionar o Pad 10"),
        ReservedKeyboardShortcut(shortcut: "p", displayName: "P", action: "Play/Pause no modo Performance"),
        ReservedKeyboardShortcut(shortcut: "shift+p", displayName: "⇧P", action: "Parar todos os cues no modo Performance"),
        ReservedKeyboardShortcut(shortcut: "command+n", displayName: "⌘N", action: "Criar um novo projeto"),
        ReservedKeyboardShortcut(shortcut: "command+o", displayName: "⌘O", action: "Abrir um projeto"),
        ReservedKeyboardShortcut(shortcut: "command+s", displayName: "⌘S", action: "Salvar o projeto"),
        ReservedKeyboardShortcut(shortcut: "command+shift+s", displayName: "⌘⇧S", action: "Salvar o projeto como")
    ]

    static func reservedShortcut(for shortcut: String?) -> ReservedKeyboardShortcut? {
        guard let normalized = normalize(shortcut) else { return nil }
        return reservedShortcuts.first { $0.shortcut == normalized }
    }

    static func isReserved(_ shortcut: String?) -> Bool {
        reservedShortcut(for: shortcut) != nil
    }

    static func normalize(_ shortcut: String?) -> String? {
        guard let shortcut else { return nil }
        let normalized = shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    static func displayName(for shortcut: String?) -> String {
        guard let shortcut, !shortcut.isEmpty else { return "Clique e pressione uma tecla" }
        if let reserved = reservedShortcut(for: shortcut) { return reserved.displayName }
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
