import Foundation

public enum ShortcutUsage {
    public static func description(standard: String?, systemNames: [String], appCommands: [String], systemMatch: Bool) -> String {
        var explanations: [String] = []
        if let standard { explanations.append(explain(standard)) }
        for name in systemNames {
            let sentence = explainSystem(name)
            if !explanations.contains(sentence) { explanations.append(sentence) }
        }
        if systemMatch && systemNames.isEmpty {
            explanations.append("macOS has assigned this shortcut to a system action, but Pano could not identify its exact purpose.")
        }
        for command in Array(Set(appCommands)).sorted() {
            if let separator = command.range(of: " (", options: .backwards), command.hasSuffix(")") {
                let title = String(command[..<separator.lowerBound])
                let app = String(command[separator.upperBound..<command.index(before: command.endIndex)])
                if title.caseInsensitiveCompare(standard ?? "") == .orderedSame
                    || systemNames.contains(where: { $0.caseInsensitiveCompare(title) == .orderedSame }) { continue }
                explanations.append("Runs the “\(title)” command in \(app).")
            } else {
                explanations.append("Runs the “\(command)” command.")
            }
        }
        if explanations.isEmpty { return "Pano could not determine what this shortcut does in every app." }
        return explanations.joined(separator: " ")
    }

    private static func explain(_ name: String) -> String {
        let descriptions = [
            "Copy": "Copies the selected content to the clipboard.",
            "Paste": "Pastes the clipboard contents into the current app.",
            "Cut": "Cuts the selection and places it on the clipboard.",
            "Select All": "Selects all content in the current document or view.",
            "Undo": "Reverses the most recent edit or action.",
            "Redo": "Repeats an action that was undone.",
            "Quit": "Closes the current app.",
            "Close Window": "Closes the current window or tab.",
            "Save": "Saves changes to the current document.",
            "Open": "Opens a file or the selected item.",
            "New Window / Document": "Creates a new window or document in the current app.",
            "Print": "Opens printing options for the current document.",
            "Find": "Searches within the current app or document.",
            "Hide App": "Hides the current app's windows.",
            "Minimize": "Moves the active window to the Dock.",
            "Settings": "Opens settings for the current app.",
            "Reload": "Refreshes content in many apps, or reveals an alias's original item in Finder.",
            "Switch Apps": "Switches to another open app.",
            "Switch Apps Backward": "Cycles backward through open apps.",
            "Switch Windows": "Switches between windows of the current app.",
            "Paste and Match Style": "Pastes content using the formatting of its destination.",
            "Paste and Match Style in some apps": "In some apps, pastes content using the destination's formatting.",
            "Interrupt / Cancel in Terminal": "Interrupts the running command in Terminal and some other apps.",
            "Page Down / Literal Input in some apps": "Pages down in text editors, or inserts the next key literally in Terminal.",
            "Typing or keyboard navigation": "Types a character or navigates the current app, depending on the selected key."
        ]
        return descriptions[name] ?? "In supported apps, this shortcut is used to \(name.prefix(1).lowercased() + name.dropFirst())."
    }

    private static func explainSystem(_ name: String) -> String {
        let suffix = " (with Fn)"
        if name.hasSuffix(suffix) {
            let sentence = explainSystem(String(name.dropLast(suffix.count)))
            return "With Fn held, this combination also has a macOS assignment: " + sentence
        }
        let descriptions = [
            "Turn Dock hiding on/off": "Shows or automatically hides the Dock.",
            "Decrease display brightness": "Makes the display dimmer.",
            "Increase display brightness": "Makes the display brighter.",
            "Show Notification Center": "Shows notifications and widgets.",
            "Turn Do Not Disturb on/off": "Turns Do Not Disturb on or off to control interruptions.",
            "Turn Stage Manager on/off": "Turns Stage Manager on or off to organize windows into groups.",
            "Move left a Space": "Switches to the desktop or full-screen app to the left.",
            "Move right a Space": "Switches to the desktop or full-screen app to the right.",
            "Quick Note": "Opens a Quick Note for writing something down.",
            "Game Overlay": "Opens game controls and related options over the current game.",
            "Minimize": "Moves the active window to the Dock.",
            "Zoom": "Toggles the active window between its standard and enlarged size.",
            "Fill": "Resizes the active window to fill the available desktop area.",
            "Center": "Moves the active window to the center of the desktop.",
            "Return to Previous Size": "Restores the window's size before it was tiled or resized.",
            "Tile Left Half": "Resizes and moves the active window into the left half of the desktop.",
            "Tile Right Half": "Resizes and moves the active window into the right half of the desktop.",
            "Tile Top Half": "Resizes and moves the active window into the top half of the desktop.",
            "Tile Bottom Half": "Resizes and moves the active window into the bottom half of the desktop.",
            "Tile Top Left Quarter": "Fits the active window into the top-left quarter of the desktop.",
            "Tile Top Right Quarter": "Fits the active window into the top-right quarter of the desktop.",
            "Tile Bottom Left Quarter": "Fits the active window into the bottom-left quarter of the desktop.",
            "Tile Bottom Right Quarter": "Fits the active window into the bottom-right quarter of the desktop.",
            "Arrange Left and Right": "Arranges windows side by side, with the active window on the left.",
            "Arrange Right and Left": "Arranges windows side by side, with the active window on the right.",
            "Arrange Top and Bottom": "Stacks windows vertically, with the active window above the other.",
            "Arrange Bottom and Top": "Stacks windows vertically, with the active window below the other.",
            "Arrange in Quarters": "Arranges windows into the four quarters of the desktop.",
            "Full Screen Tile Left": "Places the active window on the left side of a full-screen Split View.",
            "Full Screen Tile Right": "Places the active window on the right side of a full-screen Split View.",
            "Change the way Tab moves focus": "Changes which controls you can reach with the Tab key.",
            "Turn keyboard access on or off": "Enables or disables navigating interface controls with the keyboard.",
            "Move focus to the menu bar": "Selects the menu bar so you can navigate its menus with the keyboard.",
            "Move focus to the Dock": "Selects the Dock so you can navigate its apps with the keyboard.",
            "Move focus to active or next window": "Moves keyboard focus to the active window or the next window.",
            "Move focus to the window toolbar": "Moves keyboard focus to the window's toolbar controls.",
            "Move focus to the floating window": "Moves keyboard focus to a floating panel or utility window.",
            "Move focus to next window": "Switches keyboard focus to another window of the current app.",
            "Move focus to status menus": "Selects the status icons on the right side of the menu bar.",
            "Show contextual menu": "Opens the menu of actions for the currently selected item.",
            "Show/Hide Trackpad Handwriting": "Opens or closes handwriting input using the trackpad.",
            "Select the previous input source": "Switches to the previously used keyboard language or input method.",
            "Select next source in Input menu": "Switches to the next keyboard language or input method.",
            "Ask Siri about selected area": "Lets you select a screen area to ask Siri about its content.",
            "Ask Siri about active window": "Asks Siri about the content of the active window.",
            "Save picture of the Touch Bar as a file": "Captures the Touch Bar and saves it as an image file.",
            "Copy picture of the Touch Bar to the clipboard": "Captures the Touch Bar and copies the image to the clipboard.",
            "Turn Presenter Overlay (small) on or off": "Shows or hides your camera image as a small overlay while sharing your screen.",
            "Turn Presenter Overlay (large) on or off": "Shows or hides the large presenter camera overlay while sharing your screen.",
            "Show Apps": "Opens the view for browsing and launching installed apps.",
            "Increase contrast": "Increases the difference between light and dark areas on screen.",
            "Decrease contrast": "Reduces the enhanced display contrast.",
            "Invert colors": "Reverses display colors for accessibility.",
            "Turn Live Captions on or off": "Shows or hides automatic text captions for spoken audio.",
            "Turn type to speak on or off": "Enables or disables typing text to have it spoken aloud in Live Captions.",
            "Turn keep onscreen on or off": "Keeps the Live Captions window visible or allows it to hide.",
            "Switch between transcribing computer audio and microphone": "Changes whether Live Captions transcribes Mac audio or nearby speech from the microphone.",
            "Pause or resume transcription": "Pauses or resumes generating Live Captions from audio.",
            "Turn Live Speech on or off": "Enables or disables speaking typed text aloud with Live Speech.",
            "Toggle visibility": "Shows or hides the Live Speech window.",
            "Pause or resume speech": "Pauses or continues speech playback in Live Speech.",
            "Cancel speech": "Stops the current Live Speech utterance.",
            "Hide or show phrases": "Shows or hides saved phrases in Live Speech.",
            "Show Accessibility controls": "Opens quick controls for accessibility features.",
            "Turn speak item under the pointer on or off": "Enables or disables reading aloud the item beneath the pointer.",
            "Turn speak selection on or off": "Enables or disables reading selected text aloud.",
            "Turn typing feedback on or off": "Enables or disables spoken feedback as you type.",
            "Turn VoiceOver on or off": "Starts or stops VoiceOver, the screen reader that describes the interface aloud.",
            "Turn zoom on or off": "Enables or disables screen magnification for accessibility.",
            "Turn image smoothing on or off": "Enables or disables smoothing of the magnified screen image.",
            "Zoom out": "Reduces accessibility screen magnification.",
            "Zoom in": "Increases accessibility screen magnification.",
            "Turn focus following on or off": "Changes whether the magnified view follows keyboard focus.",
            "Show Help menu": "Opens the current app's Help menu to find commands and guidance.",
            "Mission Control": "Opens Mission Control to show your open windows and desktops.",
            "Application windows": "Shows the windows of the current app.",
            "Show Desktop": "Moves windows aside to reveal the desktop.",
            "Show Spotlight search": "Opens Spotlight to find apps, files, and other content.",
            "Show Finder search window": "Opens a Finder window for searching files.",
            "Screenshot and recording options": "Opens the tools for taking screenshots and recording the screen.",
            "Save picture of selected area as a file": "Captures a selected screen area and saves it as an image file.",
            "Copy picture of selected area to the clipboard": "Captures a selected screen area and copies the image to the clipboard.",
            "Save picture of screen as a file": "Captures the entire screen and saves it as an image file.",
            "Copy picture of screen to the clipboard": "Captures the entire screen and copies the image to the clipboard."
        ]
        return descriptions[name] ?? "Runs the macOS “\(name)” action."
    }
}
