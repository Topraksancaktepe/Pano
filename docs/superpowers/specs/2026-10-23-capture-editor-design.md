# Pano capture preview and editor

The user wants Pano's current simple settings and instant clipboard workflow, with an optional screenshot editor inspired by CleanShot X. The user delegated the design and remaining routine choices. This iteration implements the requested screenshot tools; price and the wider CleanShot feature set are future product goals.

## Experience

- Every successful capture is copied immediately, then a compact preview appears at the bottom right of the display where capture started. It never takes keyboard focus. Click it to edit, or dismiss it. It disappears after 12 seconds, pauses while hovered, and is hidden during another capture. Only the latest preview is shown.
- The editor is a normal resizable window that stays open until closed. Captures already being edited remain independent of subsequent captures.
- A compact top bar contains three groups: **Markup** (Arrow, Pen, Highlight), **Redact** (Smooth Blur, Pixelate), **Steps** (numbered circular markers). This interpretation of "outline steps" follows CleanShot's counter tool.
- Markup exposes a small color palette and three stroke sizes; Redact exposes two styles and strength; Steps numbers each click in sequence. Tool choices reveal their options only when selected.
- Undo and redo apply to complete gestures. Copy and Save export the edited image at its original pixel resolution. Copy does not close the editor. Save uses a native PNG save panel. Closing an editor does not overwrite the clipboard.
- All user-facing app copy is English. Retain the existing green accent and native light/dark appearance.

## Approach and constraints

Extend the existing SwiftPM/AppKit/SwiftUI app, macOS 14+, with no third-party dependency. A fully SwiftUI canvas would simplify layout but make precise pointer events and cursors harder. A full AppKit editor would duplicate the existing SwiftUI style. Use SwiftUI for controls and a small NSViewRepresentable for image drawing and mouse input; AppKit owns preview/editor windows.

PanoCore holds capture pixels, annotation values, undo history, coordinate conversion and deterministic full-resolution rendering. The editor retains a validated CGImage instead of reading the global clipboard after capture. The existing cancellation and clipboard preservation guarantees remain. Blur and pixelation are flattened into exported pixels; the source image is never embedded in the PNG. Do not claim blur is cryptographic redaction.

Annotations use top-left image pixel coordinates regardless of Retina scale, zoom or window size. Restrict strokes and regions to image bounds. Render redactions against the composed image in order and cache committed output; show lightweight outlines during region drags. Keep the preview and all editor windows out of subsequent captures and restore them afterward. Manage activation policy according to all visible regular windows, not only settings.

## Acceptance

Exercise all six tools, undo/redo, copy, save, closing, recapture and reopening through the app. Verify exact output dimensions, orientation, bounds, blur region isolation, history branching, cancelled captures and preview placement with automated tests. Validate app UI on this Mac. Build the new version locally; publishing another GitHub release is outside this request.
