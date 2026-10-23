# Pano Capture Editor Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement inline. The user delegated design and routine choices; proceed with the existing native app.

**Goal:** Add a bottom-right capture preview and a compact six-tool screenshot editor.
**Architecture:** PanoCore owns image data, annotation/history values, geometry and full-resolution rendering. SwiftUI owns editor controls and observable state. Narrow AppKit bridges handle pointer input, windows and native save panels.
**Tech Stack:** Swift 5.10, AppKit, SwiftUI, CoreGraphics, CoreImage, ImageIO; macOS 14+.
**Spec:** docs/superpowers/specs/2026-10-23-capture-editor-design.md

## Global Constraints

- No third-party dependencies; keep macOS 14+.
- English UI; preserve existing settings and immediate clipboard capture.
- Original pixel dimensions and top-left annotation coordinates at all scales.
- Keep windows open until explicitly closed; preview is intentionally transient.
- No automatic public release or permission reset.

## Review Focus

- Capture cancellation preserves the existing clipboard and restores hidden windows.
- Retina and non-square images export upright at original dimensions.
- Redaction only changes the selected bounded area and exports flattened pixels.
- Repeated captures cannot replace a document currently being edited.
- Closing settings or one editor leaves other editor windows usable.

### Task 1: Capture payload, annotations and rendering

**Files:** Sources/PanoCore/CaptureOutput.swift; new Screenshot.swift, Annotation.swift, AnnotationHistory.swift, AnnotationRenderer.swift, ImageGeometry.swift; Tests/PanoCoreTests/AnnotationTests.swift.
**Interfaces:** CaptureOutput.read(file:exitStatus:) -> Screenshot?; Screenshot.copy(to:), pngData(); AnnotationRenderer.render(image:annotations:) -> CGImage; AnnotationHistory.append/undo/redo; ImageGeometry.fit and imagePoint.

- [ ] Write and run failing tests for clipboard payload, history branching and numbering, fitted coordinate conversion, orientation, all tools and redaction isolation.
- [ ] Implement types and renderer. Draw vectors in image coordinates, use bounded CI filters for redaction, and preserve resolution on PNG export.
- [ ] Run PanoCoreTests and inspect all failures.

### Task 2: Editor window and tools

**Files:** new Sources/Pano/Editor/{EditorModel,EditorView,AnnotationCanvas,EditorWindowController}.swift; Sources/Pano/PanoApp.swift.
**Interfaces:** EditorModel owns one Screenshot and AnnotationHistory; EditorWindowController owns one NSWindow. The delegate owns controllers by UUID.

- [ ] Implement compact tool groups, color/size options, undo/redo, image fit/zoom, Copy and native PNG Save.
- [ ] Bridge image mouse gestures into canonical coordinates and lightweight draft drawing; commit only complete gestures.
- [ ] Add menu routing for undo/redo/copy/save and preserve activation across settings and editor windows.
- [ ] Build and verify visible window, tool switches, drawing, undo/redo and exports.

### Task 3: Preview and capture integration

**Files:** new Sources/Pano/CapturePreview.swift; Sources/Pano/{CaptureService,AppModel,PanoApp}.swift; script/build_and_run.sh; README.md.
**Interfaces:** CaptureService.capture returns Result<Screenshot?,Error>; AppModel.onCapture(Screenshot); preview onEdit opens that specific Screenshot.

- [ ] Retain validated capture pixels before temporary file deletion; copy immediately and trigger preview.
- [ ] Present nonactivating preview at display corner with hover-aware expiry and dismiss. Hide all Pano windows while capturing and restore afterward.
- [ ] Build Pano 1.4.0, run the complete suite, manually exercise capture-to-preview-to-editor and PNG/clipboard output.
- [ ] Review changes and deliver a tested local bundle, installing the update when permitted by the existing app workflow.
