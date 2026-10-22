import AppKit
import Carbon
import PanoCore

typealias CaptureShortcut = PanoCore.KeyboardShortcut

extension CaptureShortcut {
    var keyLabel: String {
        let special: [Int64: String] = [36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
            65: ".", 67: "*", 69: "+", 75: "/", 76: "Enter", 78: "−", 81: "=",
            82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
            105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
            115: "Home", 116: "Page Up", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
            121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑", 64: "F17", 79: "F18", 80: "F19", 90: "F20"]
        return special[keyCode] ?? character.uppercased()
    }

    var character: String { translatedCharacter(modifiers: 0) }
    var menuCharacter: String {
        var modifiers: UInt32 = 0
        if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
        return translatedCharacter(modifiers: modifiers >> 8)
    }

    private func translatedCharacter(modifiers: UInt32) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "Key \(keyCode)" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return "Key \(keyCode)" }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var state: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        let result = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), modifiers,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                    &state, chars.count, &length, &chars)
        guard result == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: length)
    }

    var keycaps: [String] {
        var parts: [String] = []
        if flags.contains(.maskSecondaryFn) { parts.append("fn") }
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyLabel)
        return parts
    }
    var display: String { keycaps.joined() }
}
