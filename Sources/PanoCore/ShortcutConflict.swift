import Foundation
import CoreGraphics

public struct ShortcutConflict: Equatable, Sendable {
    public let task: String
    public init(task: String) { self.task = task }

    public static func menuMatches(_ shortcut: KeyboardShortcut, virtualKey: Int64?, character: String?,
                                   flags: CGEventFlags, candidateCharacters: [String]) -> Bool {
        guard shortcut.flags == flags else { return false }
        if let virtualKey { return shortcut.keyCode == virtualKey }
        guard let character, !character.isEmpty else { return false }
        return candidateCharacters.contains { $0.lowercased() == character.lowercased() }
    }

    /// Common app commands still deserve a warning when their app is not running.
    public static func standard(for shortcut: KeyboardShortcut, character: String) -> ShortcutConflict? {
        if let purpose = CommonShortcutCatalog.purpose(for: shortcut, character: character) {
            return Self(task: purpose)
        }
        let key = character.lowercased()
        let flags = shortcut.flags
        if flags == .maskCommand {
            let names = ["c": "Copy", "v": "Paste", "x": "Cut", "a": "Select All",
                         "z": "Undo", "q": "Quit", "w": "Close Window", "s": "Save",
                         "o": "Open", "n": "New Window / Document", "p": "Print", "f": "Find",
                         "h": "Hide App", "m": "Minimize", ",": "Settings", "r": "Reload"]
            if let name = names[key] { return Self(task: name) }
            if shortcut.keyCode == 48 { return Self(task: "Switch Apps") }
            if shortcut.keyCode == 50 { return Self(task: "Switch Windows") }
        }
        if flags == [.maskCommand, .maskShift] {
            if key == "z" { return Self(task: "Redo") }
            if key == "v" { return Self(task: "Paste and Match Style in some apps") }
            if shortcut.keyCode == 48 { return Self(task: "Switch Apps Backward") }
        }
        if flags == [.maskCommand, .maskAlternate, .maskShift], key == "v" {
            return Self(task: "Paste and Match Style")
        }
        if flags == .maskControl, key == "c" { return Self(task: "Interrupt / Cancel in Terminal") }
        if flags == .maskControl, key == "v" { return Self(task: "Page Down / Literal Input in some apps") }
        if flags.intersection([.maskControl, .maskCommand, .maskAlternate]).isEmpty {
            return Self(task: "Typing or keyboard navigation")
        }
        return nil
    }
}
