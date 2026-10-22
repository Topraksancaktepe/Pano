import Foundation
import PanoCore

/// These OS resources are optional: future versions can move them. Live hotkey
/// detection still works if names are unavailable; the UI reports that honestly.
enum SystemShortcutSource {
    static func names(for shortcut: CaptureShortcut, enabled: [CaptureShortcut]) -> [String] {
        let roots = [
            "/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex/Contents/Resources",
            "/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources"
        ]
        for root in roots {
            for language in ["en", "en_GB", "English"] {
                let file = URL(fileURLWithPath: root).appendingPathComponent("\(language).lproj/DefaultShortcutsTable.xml")
                guard let data = try? Data(contentsOf: file),
                      let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { continue }
                var names: [String: String] = [:]
                if let locData = try? Data(contentsOf: URL(fileURLWithPath: root).appendingPathComponent("DefaultShortcutsTable.loctable")),
                   let translations = try? PropertyListSerialization.propertyList(from: locData, format: nil) as? [String: Any] {
                    names = translations["en"] as? [String: String] ?? [:]
                }
                CFPreferencesAppSynchronize("com.apple.symbolichotkeys" as CFString)
                let overrides = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                    "com.apple.symbolichotkeys" as CFString) as? [String: Any] ?? [:]
                var codes: [Int64: Int64] = [:]
                for code in Int64(0)...126 {
                    let char = CaptureShortcut(keyCode: code, flags: []).character
                    if char.unicodeScalars.count == 1, let scalar = char.unicodeScalars.first,
                       codes[Int64(scalar.value)] == nil { codes[Int64(scalar.value)] = code }
                }
                return SystemShortcutCatalog.names(for: shortcut, table: table, localizations: names,
                                                   overrides: overrides, enabled: enabled, characterKeyCodes: codes)
            }
        }
        return []
    }
}
