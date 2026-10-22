import Foundation
import CoreGraphics

/// Reads the system's own shortcut table; user assignments replace defaults.
public enum SystemShortcutCatalog {
    public static func names(for shortcut: KeyboardShortcut, table: [[String: Any]],
                             localizations: [String: String], overrides: [String: Any],
                             enabled: [KeyboardShortcut], characterKeyCodes: [Int64: Int64] = [:]) -> [String] {
        guard enabled.contains(shortcut) else { return [] }
        var names: [String] = []
        func visit(_ nodes: [[String: Any]]) {
            for node in nodes {
                if let children = node["elements"] as? [[String: Any]] { visit(children) }
                guard let identifier = (node["sybmolichotkey"] as? NSNumber)?.intValue,
                      let rawName = node["name"] as? String else { continue }
                let name = rawName.replacingOccurrences(of: "DO_NOT_LOCALIZE: ", with: "")
                let title = localizations[name] ?? name
                let preferred = (node["prefs_sybmolichotkey"] as? NSNumber)?.intValue
                let primary = preferred.flatMap { overrides[String($0)] != nil ? $0 : nil } ?? identifier
                var ids = [(primary, false)]
                if let slow = (node["slow_sybmolichotkey"] as? NSNumber)?.intValue { ids.append((slow, true)) }
                for (id, isSlow) in ids {
                    let override = overrides[String(id)] as? [String: Any]
                    let active = (override?["enabled"] as? NSNumber)?.boolValue
                        ?? (node["enabled"] as? NSNumber)?.boolValue ?? true
                    if !active { continue }
                    var code = (node["key"] as? NSNumber)?.int64Value
                    if code == nil, let character = (node["charKey"] as? NSNumber)?.int64Value {
                        code = characterKeyCodes[character]
                    }
                    var modifiers = (node["modifier"] as? NSNumber)?.uint64Value ?? 0
                    if isSlow { modifiers |= CGEventFlags.maskShift.rawValue }
                    if let value = override?["value"] as? [String: Any] {
                        guard value["type"] as? String == "standard",
                              let parameters = value["parameters"] as? [NSNumber], parameters.count == 3 else { continue }
                        code = parameters[1].int64Value
                        modifiers = parameters[2].uint64Value
                    }
                    guard let code, (0...126).contains(code) else { continue }
                    let binding = KeyboardShortcut(keyCode: code, flags: CGEventFlags(rawValue: modifiers))
                    if binding == shortcut {
                        // Navigation events carry an implicit Fn bit, so the recorder
                        // cannot distinguish this variant. Explain that condition.
                        let fnIsAmbiguous = modifiers & CGEventFlags.maskSecondaryFn.rawValue != 0
                            && !binding.flags.contains(.maskSecondaryFn)
                        names.append(title + (fnIsAmbiguous ? " (with Fn)" : ""))
                    }
                }
            }
        }
        visit(table)
        return Array(Set(names)).sorted()
    }
}
