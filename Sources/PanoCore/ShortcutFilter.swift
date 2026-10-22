import CoreGraphics

public enum ShortcutDecision: Equatable {
    case pass, trigger, suppress
    case record(KeyboardShortcut)
}

public struct ShortcutFilter {
    private var consumedKeys = Set<Int64>()
    public init() {}

    public mutating func handle(keyCode: Int64, down: Bool, flags: CGEventFlags,
                                isRepeat: Bool, enabled: Bool,
                                shortcut: KeyboardShortcut = .defaultShortcut,
                                recording: Bool = false) -> ShortcutDecision {
        // Always swallow the release, even if the binding or recorder changed mid-press.
        if consumedKeys.contains(keyCode) {
            if !down { consumedKeys.remove(keyCode) }
            return .suppress
        }
        if recording && down {
            consumedKeys.insert(keyCode)
            guard !isRepeat else { return .suppress }
            return .record(KeyboardShortcut(keyCode: keyCode, flags: flags))
        }
        guard enabled, down, !isRepeat, shortcut.matches(keyCode: keyCode, flags: flags) else { return .pass }
        consumedKeys.insert(keyCode)
        return .trigger
    }
}
