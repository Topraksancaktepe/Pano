import AppKit
import ApplicationServices
import Carbon
import PanoCore

struct MenuApp: Sendable {
    let pid: pid_t
    let name: String
}

struct ConflictReport: Sendable {
    let tasks: [String]
    let incomplete: Bool
    var usageDescription: String = ""
}

enum ShortcutConflictDetector {
    @MainActor static func inspect(_ shortcut: CaptureShortcut) async -> ConflictReport {
        let character = shortcut.character
        let menuCharacter = shortcut.menuCharacter
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != "local.toprak.Pano" }
            .map { MenuApp(pid: $0.processIdentifier, name: $0.localizedName ?? "App") }
        // Carbon's hotkey API runs on the main thread; menu IPC runs off it.
        var tasks: [String] = []
        var enabled: [CaptureShortcut] = []
        var symbolicKeys: Unmanaged<CFArray>?
        let systemReadable = CopySymbolicHotKeys(&symbolicKeys) == noErr
        if let entries = symbolicKeys?.takeRetainedValue() as? [[String: Any]] {
            for entry in entries {
                guard (entry[kHISymbolicHotKeyEnabled] as? NSNumber)?.boolValue == true,
                      let code = entry[kHISymbolicHotKeyCode] as? NSNumber,
                      let mods = entry[kHISymbolicHotKeyModifiers] as? NSNumber else { continue }
                let value = CaptureShortcut(keyCode: code.int64Value, flags: carbonFlags(mods.uint32Value))
                enabled.append(value)
            }
        }
        let systemMatch = enabled.contains(shortcut)
        let systemNames = SystemShortcutSource.names(for: shortcut, enabled: enabled)
        if systemMatch { tasks.append(contentsOf: systemNames.isEmpty ? ["A macOS system action"] : systemNames) }
        let standard = ShortcutConflict.standard(for: shortcut, character: character)?.task
        if let standard { tasks.append(standard) }
        let menuReport = await Task.detached(priority: .userInitiated) {
            scanMenus(apps, shortcut: shortcut, characters: [character, menuCharacter])
        }.value
        tasks.append(contentsOf: menuReport.tasks)
        return ConflictReport(tasks: Array(Set(tasks)).sorted(), incomplete: !systemReadable || menuReport.incomplete,
            usageDescription: ShortcutUsage.description(standard: standard, systemNames: systemNames,
                                                       appCommands: menuReport.tasks, systemMatch: systemMatch))
    }

    private static func carbonFlags(_ value: UInt32) -> CGEventFlags {
        var flags: CGEventFlags = []
        if value & UInt32(cmdKey) != 0 { flags.insert(.maskCommand) }
        if value & UInt32(shiftKey) != 0 { flags.insert(.maskShift) }
        if value & UInt32(optionKey) != 0 { flags.insert(.maskAlternate) }
        if value & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        if value & (1 << 17) != 0 { flags.insert(.maskSecondaryFn) }
        return flags
    }

    private static func scanMenus(_ apps: [MenuApp], shortcut: CaptureShortcut, characters: [String]) -> ConflictReport {
        var tasks: [String] = []
        var incomplete = false
        let deadline = Date().addingTimeInterval(4)
        func read(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
            if result == .success { return value }
            if result != .attributeUnsupported && result != .noValue { incomplete = true }
            return nil
        }
        for app in apps {
            guard Date() < deadline else { incomplete = true; break }
            let element = AXUIElementCreateApplication(app.pid)
            AXUIElementSetMessagingTimeout(element, 0.15)
            guard let raw = read(element, kAXMenuBarAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else {
                incomplete = true; continue
            }
            let menu = unsafeBitCast(raw, to: AXUIElement.self)
            var queue: [(AXUIElement, Int)] = [(menu, 0)]
            var visited = 0
            while let (item, depth) = queue.popLast() {
                guard Date() < deadline, visited < 1500 else { incomplete = true; break }
                visited += 1
                let char = read(item, kAXMenuItemCmdCharAttribute) as? String
                let code = read(item, kAXMenuItemCmdVirtualKeyAttribute) as? NSNumber
                if (char?.isEmpty == false || code != nil),
                   let mods = read(item, kAXMenuItemCmdModifiersAttribute) as? NSNumber {
                    var flags: CGEventFlags = []
                    let value = mods.intValue
                    if value & 8 == 0 { flags.insert(.maskCommand) }
                    if value & 1 != 0 { flags.insert(.maskShift) }
                    if value & 2 != 0 { flags.insert(.maskAlternate) }
                    if value & 4 != 0 { flags.insert(.maskControl) }
                    if ShortcutConflict.menuMatches(shortcut, virtualKey: code?.int64Value,
                                                    character: char, flags: flags, candidateCharacters: characters),
                       let title = read(item, kAXTitleAttribute) as? String, !title.isEmpty {
                        tasks.append("\(title) (\(app.name))")
                    }
                }
                if let children = read(item, kAXChildrenAttribute) as? [AXUIElement], !children.isEmpty {
                    if depth < 10 { queue.append(contentsOf: children.map { ($0, depth + 1) }) }
                    else { incomplete = true }
                }
            }
        }
        return ConflictReport(tasks: tasks, incomplete: incomplete)
    }

}
