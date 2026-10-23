import CoreGraphics

public enum EditorShortcutPolicy {
    /// Native save sheets retain text editing and dialog keys. In the image window,
    /// reserve only actual editor/window commands, leaving normal capture bindings active.
    public static func canCapture(_ shortcut: KeyboardShortcut, editorFocused: Bool, sheetFocused: Bool) -> Bool {
        if sheetFocused { return false }
        guard editorFocused else { return true }
        if shortcut.flags == .maskCommand {
            return ![1, 6, 8, 12, 13, 46].contains(shortcut.keyCode) // S, Z, C, Q, W, M
        }
        return !(shortcut.keyCode == 6 && shortcut.flags == [.maskCommand, .maskShift])
    }
}
