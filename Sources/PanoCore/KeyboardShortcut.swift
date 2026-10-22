import Foundation
import CoreGraphics

public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public let keyCode: Int64
    public let modifiers: UInt64
    public static let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand, .maskSecondaryFn]
    public static let defaultShortcut = KeyboardShortcut(keyCode: 21, flags: [.maskCommand, .maskShift])

    public init(keyCode: Int64, flags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = Self.normalized(flags, keyCode: keyCode).rawValue
    }
    private static func normalized(_ flags: CGEventFlags, keyCode: Int64) -> CGEventFlags {
        var result = flags.intersection(modifierMask)
        // macOS marks function/navigation keys with Fn even when it is not held.
        if (96...126).contains(keyCode) || [64, 79, 80, 90].contains(keyCode) {
            result.remove(.maskSecondaryFn)
        }
        return result
    }
    public var flags: CGEventFlags { CGEventFlags(rawValue: modifiers) }
    public var isValid: Bool {
        (0...126).contains(keyCode) && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
            && modifiers == Self.normalized(flags, keyCode: keyCode).rawValue
    }
    public var reserved: Bool {
        (keyCode == 53 && flags == [.maskCommand, .maskAlternate]) ||
        (keyCode == 12 && flags == [.maskCommand, .maskControl])
    }
    public func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        self.keyCode == keyCode && modifiers == Self.normalized(flags, keyCode: keyCode).rawValue
    }
}

public struct ShortcutDraft {
    public private(set) var current: KeyboardShortcut
    public private(set) var candidate: KeyboardShortcut?
    public init(current: KeyboardShortcut) { self.current = current }
    public mutating func record(_ shortcut: KeyboardShortcut) { candidate = shortcut }
    public mutating func cancel() { candidate = nil }
    public mutating func accept() -> KeyboardShortcut? {
        guard let candidate, candidate.isValid, !candidate.reserved else { return nil }
        current = candidate
        self.candidate = nil
        return current
    }
}

public final class ShortcutStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> KeyboardShortcut {
        guard let data = defaults.data(forKey: "captureShortcut"),
              let value = try? JSONDecoder().decode(KeyboardShortcut.self, from: data),
              value.isValid, !value.reserved else { return .defaultShortcut }
        return value
    }
    public func save(_ value: KeyboardShortcut) throws {
        guard value.isValid, !value.reserved else { throw ShortcutError.invalid }
        defaults.set(try JSONEncoder().encode(value), forKey: "captureShortcut")
    }
}

public enum ShortcutError: LocalizedError {
    case invalid
    public var errorDescription: String? { "Choose a key combination that macOS allows apps to use." }
}
