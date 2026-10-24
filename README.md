# Pano

Pano 1.4 adds an optional editor without changing instant screenshot copying. After a capture, click the small preview in the bottom-right corner to edit it.

- **Markup:** arrows, freehand pen, and highlighter, with colors and stroke sizes.
- **Redact:** select an area for smooth blur or pixelation and adjust its strength.
- **Steps:** click to add numbered markers in sequence.
- **Crop:** select the area to keep, move or resize the selection, then apply. Cropping supports undo/redo and sets the exported PNG dimensions.
- Undo/redo, fit/zoom, Copy, and Save as PNG. Exports keep the original screenshot resolution.

The preview disappears after 12 seconds (it pauses while hovered). Editor windows stay open until you close them. Captures are processed locally; blur and annotations are flattened into the exported image. Blur and pixelation are visual obscuring tools, not a guarantee that sensitive information cannot be inferred.

Pano is a small macOS app that captures a selected screen area directly to the clipboard. Its default shortcut is **⌘⇧4**. You can change the shortcut in Pano, and it warns you when the new combination already has a known macOS or app command. The warning describes what that command does before you decide whether to use it.

Pano runs in the menu bar and can start when you log in. Its settings window remains open until you close it. While the window is open, Pano appears in the Dock and ⌘Tab. During screen selection the window temporarily hides, then returns when selection finishes or is cancelled.

## Requirements

- macOS 14 or later
- Accessibility and Screen Recording permissions, granted in System Settings when Pano asks
- Xcode/Swift toolchain to build from source

## Build

```sh
./script/build_and_run.sh --build-only
```

This creates `outputs/Pano.app`. Move it to `/Applications` before opening it and granting permissions. Open the app once, then enable the two permissions it requests. The app registers launch at login on first launch; the switch in Pano controls that setting.

The local build is **ad-hoc signed and not notarized**. macOS may require you to explicitly allow opening a downloaded build. Rebuilding changes the app's signing identity and can require granting its permissions again. A signed, notarized distribution requires an Apple Developer signing identity and notarization, which this repository does not provide.

To run the tests:

```sh
./script/swift.sh test
```

Clipboard tests use isolated pasteboards. They may need a normal macOS desktop session rather than a restricted build environment.

## How it works

Pano intercepts only the chosen key combination while it is ready, lets you select an area using macOS's screen capture tool, then places PNG and TIFF representations on the clipboard. Press **Esc** to cancel without replacing the clipboard. Screenshot files are temporary and removed after capture. Pano has no network calls, capture history, or background screen recording.

Shortcut conflict checks use current macOS system assignments, common Finder and text-editing commands, and the menus of open apps. Closed apps and shortcuts handled outside menus cannot always be checked; Pano says so when detection is incomplete. The descriptions for macOS actions are based on the system's own keyboard shortcut table when available. Pano does not change macOS shortcut settings; quitting Pano restores their normal behavior.

An optional older `PanoControl` helper remains in the source tree for development. The app users need is `Pano.app`; the helper is not part of the main build or installation.
