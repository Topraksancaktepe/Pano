import CoreGraphics

/// Cross-app, Finder, and text-editing commands. Their scope is stated in the
/// description because one combination can have different meanings across apps.
enum CommonShortcutCatalog {
    static func purpose(for shortcut: KeyboardShortcut, character: String) -> String? {
        let key = character.lowercased()
        let flags = shortcut.flags
        let command: CGEventFlags = .maskCommand
        let shift: CGEventFlags = .maskShift
        let option: CGEventFlags = .maskAlternate
        let control: CGEventFlags = .maskControl
        let fn: CGEventFlags = .maskSecondaryFn
        let groups: [(CGEventFlags, [String: String])] = [
            (command, ["b": "Toggle bold text", "i": "Toggle italic text, or show file information in Finder",
                       "u": "Toggle underlined text", "t": "Open a tab, or show font controls in some editors",
                       "d": "Duplicate files in Finder or choose Desktop in file dialogs",
                       "e": "Eject a disk in Finder", "g": "Find the next search result",
                       "j": "Show view options in Finder", "k": "Insert a link, or connect to a server in Finder",
                       "y": "Preview the selected file in Finder", "l": "Focus the address or location field",
                       "1": "Use icon view in Finder or switch to the first tab in some apps",
                       "2": "Use list view in Finder or switch to the second tab in some apps",
                       "3": "Use column view in Finder or switch to the third tab in some apps",
                       "4": "Use gallery view in Finder or switch to the fourth tab in some apps",
                       "[": "Go back to the previous location", "]": "Go forward to the next location",
                       "/": "Toggle the status bar in Finder", ";": "Find the next spelling error",
                       "=": "Increase text size or zoom in", "-": "Reduce text size or zoom out"]),
            ([command, shift], ["c": "Open Computer in Finder", "d": "Open the Desktop folder in Finder",
                "f": "Open Recents in Finder", "g": "Open Go to Folder in Finder or find the previous search result",
                "h": "Open your Home folder in Finder", "i": "Open iCloud Drive in Finder",
                "k": "Open Network in Finder", "n": "Create a folder in Finder",
                "o": "Open Documents in Finder", "p": "Open page setup, or toggle Finder's preview pane",
                "r": "Open AirDrop in Finder", "t": "Reopen a closed tab in browsers or toggle Finder's tab bar",
                "u": "Open Utilities in Finder", "s": "Save a new version or duplicate the document",
                "q": "Log out after confirmation", "/": "Open the Help menu",
                ";": "Open spelling and grammar controls", "[": "Align text to the left",
                "]": "Align text to the right", "\\": "Center-align text"]),
            ([command, option], ["h": "Hide other apps", "m": "Minimize all windows of the current app",
                "w": "Close all windows of the current app", "l": "Open Downloads in Finder",
                "p": "Toggle Finder's path bar", "s": "Toggle Finder's sidebar",
                "n": "Create a Smart Folder in Finder", "t": "Toggle the current app's toolbar",
                "v": "Apply copied formatting, or move copied files in Finder",
                "y": "Preview selected files as a slideshow in Finder", "f": "Focus the search field",
                "c": "Copy the selection's formatting", "i": "Show the inspector"]),
            ([command, control], ["f": "Enter or leave full screen", "d": "Look up the selected word",
                "n": "Put selected Finder items in a new folder", "t": "Add a Finder item to the sidebar",
                "a": "Create an alias in Finder", "q": "Lock the screen"]),
            ([command, control, shift], ["t": "Add the selected Finder item to the Dock"]),
            ([command, option, shift], ["q": "Log out immediately without confirmation"]),
            (control, ["a": "Move to the start of the current line", "e": "Move to the end of the current line",
                "f": "Move one character forward", "b": "Move one character backward",
                "h": "Delete the preceding character", "d": "Delete the following character",
                "k": "Cut text through the end of the line", "y": "Restore text cut by Control-K",
                "l": "Center the cursor in a text view, or clear Terminal's display",
                "p": "Move up a line, or recall a previous Terminal command",
                "n": "Move down a line, or recall the next Terminal command",
                "o": "Insert a line break", "t": "Swap the characters beside the cursor"]),
            (fn, ["a": "Show or hide the Dock", "c": "Show or hide Control Center",
                "d": "Start or stop dictation", "e": "Open the emoji and symbols picker",
                "h": "Reveal the desktop", "n": "Show or hide Notification Center",
                "q": "Create a Quick Note"]),
            ([fn, shift], ["a": "Open the Apps or Launchpad view"])
        ]
        for (modifiers, commands) in groups where flags == modifiers {
            if let purpose = commands[key] { return purpose }
        }
        switch shortcut.keyCode {
        case 51:
            if flags == command { return "Move the selection to Trash in Finder, or delete to the start of a line in text" }
            if flags == [command, shift] { return "Empty Trash after confirmation" }
            if flags == [command, shift, option] { return "Empty Trash without confirmation" }
            if flags == option { return "Delete the preceding word" }
            if flags == fn { return "Delete the following character" }
        case 48:
            if flags == control { return "Move to the next tab or control" }
            if flags == [control, shift] { return "Move to the previous tab or control" }
            if flags.isEmpty { return "Move focus to the next control or insert a tab" }
            if flags == shift { return "Move focus to the previous control" }
        case 49:
            if flags == [command, control] { return "Open the emoji and symbols picker" }
            if flags.isEmpty { return "Insert a space, or preview the selected item in Finder" }
        case 50:
            if flags == [command, shift] { return "Switch to the previous window of the current app" }
            if flags == [command, option] { return "Move focus to a window drawer" }
        case 53:
            if flags.isEmpty { return "Cancel the current operation or dismiss a dialog" }
        case 36:
            if flags.isEmpty { return "Confirm an action or insert a new line" }
        case 123...126:
            let direction = [123: "left", 124: "right", 125: "down", 126: "up"][Int(shortcut.keyCode)]!
            if flags.isEmpty { return "Move the cursor or selection \(direction)" }
            if flags == shift { return "Extend the selection \(direction)" }
            if flags == option { return "Move by a word or paragraph \(direction)" }
            if flags == [option, shift] { return "Extend the selection by a word or paragraph \(direction)" }
            if flags == command {
                return [123: "Move to the start of a line", 124: "Move to the end of a line",
                        125: "Move to the document's end, or open a selected Finder item",
                        126: "Move to the document's start, or open the parent folder in Finder"][Int(shortcut.keyCode)]
            }
            if flags == [command, shift] { return "Select text to the \(direction == "left" || direction == "up" ? "start" : "end") of the \(shortcut.keyCode < 125 ? "line" : "document")" }
        default: break
        }
        return nil
    }
}
