import XCTest
import AppKit
import ImageIO
@testable import PanoCore

final class AnnotationTests: XCTestCase {
    private func image(width: Int = 120, height: Int = 80, patterned: Bool = false) -> CGImage {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
        for y in 0..<height {
            for x in 0..<width {
                let white = patterned ? (x / 2 + y / 2).isMultiple(of: 2) : y < height / 2
                let offset = y * rep.bytesPerRow + x * 4
                rep.bitmapData![offset] = white ? 255 : 0
                rep.bitmapData![offset + 1] = white ? 255 : 0
                rep.bitmapData![offset + 2] = white || !patterned ? 255 : 0
                rep.bitmapData![offset + 3] = 255
            }
        }
        return rep.cgImage!
    }

    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> NSColor {
        NSBitmapImageRep(cgImage: image).colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    }

    func testHistoryNumbersStepsAndDiscardsRedoAfterNewGesture() {
        var history = AnnotationHistory()
        history.append(Annotation(tool: .step, points: [CGPoint(x: 20, y: 20)]))
        history.append(Annotation(tool: .step, points: [CGPoint(x: 50, y: 20)]))
        XCTAssertEqual(history.annotations.map(\.number), [1, 2])
        history.undo()
        XCTAssertEqual(history.nextStep, 2)
        XCTAssertTrue(history.canRedo)
        history.append(Annotation(tool: .pen, points: [.zero, CGPoint(x: 30, y: 20)]))
        XCTAssertFalse(history.canRedo)
        history.append(Annotation(tool: .step, points: [CGPoint(x: 80, y: 20)]))
        XCTAssertEqual(history.annotations.last?.number, 2)
        history.undo()
        history.redo()
        XCTAssertEqual(history.annotations.last?.number, 2)
    }

    func testEmptyGesturesDoNotCreateUndoEntries() {
        var history = AnnotationHistory()
        history.append(Annotation(tool: .pixelate, points: [CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 10)]))
        history.append(Annotation(tool: .pen, points: []))
        history.undo()
        history.redo()
        XCTAssertTrue(history.annotations.isEmpty)
        XCTAssertFalse(history.canUndo)
    }

    func testImageCoordinatesRespectAspectFitAndRejectLetterbox() {
        let frame = ImageGeometry.fit(image: CGSize(width: 1000, height: 500),
                                      in: CGRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertEqual(frame, CGRect(x: 0, y: 100, width: 400, height: 200))
        XCTAssertEqual(ImageGeometry.imagePoint(CGPoint(x: 200, y: 150), in: frame,
                        image: CGSize(width: 1000, height: 500)), CGPoint(x: 500, y: 125))
        XCTAssertNil(ImageGeometry.imagePoint(CGPoint(x: 200, y: 50), in: frame,
                         image: CGSize(width: 1000, height: 500)))
    }

    func testNoEditsPreserveUprightNonSquarePixelsAndExportDimensions() throws {
        let source = image()
        let rendered = try AnnotationRenderer.render(image: source, annotations: [])
        let screenshot = Screenshot(image: rendered)
        let data = try screenshot.pngData()
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(decoded.pixelsWide, 120)
        XCTAssertEqual(decoded.pixelsHigh, 80)
        XCTAssertGreaterThan(pixel(rendered, 10, 5).redComponent, 0.95)
        XCTAssertLessThan(pixel(rendered, 10, 75).redComponent, 0.05)
    }

    func testVectorToolsDrawAtTopLeftImageCoordinates() throws {
        for tool in [AnnotationTool.arrow, .pen, .highlight, .step] {
            let points = tool == .step ? [CGPoint(x: 30, y: 20)]
                : [CGPoint(x: 10, y: 20), CGPoint(x: 60, y: 20)]
            let annotation = Annotation(tool: tool, points: points, color: .red, width: 8)
            let rendered = try AnnotationRenderer.render(image: image(), annotations: [annotation])
            let marked = pixel(rendered, tool == .step ? 12 : 30, 20)
            XCTAssertLessThan(marked.greenComponent, 0.95, "\(tool) should draw in the top half")
            XCTAssertLessThan(pixel(rendered, 30, 70).redComponent, 0.05, "Bottom stays blue")
        }
    }

    func testBothRedactionsChangeSelectedPixelsButNotOutside() throws {
        let source = image(patterned: true)
        for tool in [AnnotationTool.smoothBlur, .pixelate] {
            // Reverse drag, partially beyond the image: normalize and clamp it.
            let annotation = Annotation(tool: tool,
                points: [CGPoint(x: 65, y: 60), CGPoint(x: -10, y: 15)], strength: 14)
            let output = try AnnotationRenderer.render(image: source, annotations: [annotation])
            XCTAssertEqual(output.width, source.width)
            XCTAssertEqual(output.height, source.height)
            XCTAssertEqual(pixel(output, 100, 5).redComponent, pixel(source, 100, 5).redComponent, accuracy: 0.01)
            XCTAssertEqual(pixel(output, 100, 75).redComponent, pixel(source, 100, 75).redComponent, accuracy: 0.01)
            var changed = 0
            for y in 20..<55 {
                for x in 5..<60 {
                    if abs(pixel(output, x, y).redComponent - pixel(source, x, y).redComponent) > 0.1 { changed += 1 }
                }
            }
            XCTAssertGreaterThan(changed, 200, "\(tool) must alter pixels in the selected area")
        }
    }

    func testEditedClipboardContainsFlattenedPNGAndTIFF() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let rendered = try AnnotationRenderer.render(image: image(), annotations: [
            Annotation(tool: .pen, points: [CGPoint(x: 10, y: 20), CGPoint(x: 60, y: 20)], color: .red, width: 8)
        ])
        try Screenshot(image: rendered).copy(to: board)
        let png = try XCTUnwrap(board.data(forType: .png))
        let result = try XCTUnwrap(NSBitmapImageRep(data: png)?.cgImage)
        XCTAssertLessThan(pixel(result, 30, 20).greenComponent, 0.5)
        XCTAssertNotNil(board.data(forType: .tiff))
        XCTAssertEqual(result.width, 120)
    }

    func testPreviewUsesVisibleDisplayBoundsIncludingNegativeOrigin() {
        let display = CGRect(x: -1440, y: 40, width: 1440, height: 860)
        let frame = ImageGeometry.previewFrame(size: CGSize(width: 260, height: 190), visibleFrame: display)
        XCTAssertEqual(frame.maxX, -22)
        XCTAssertEqual(frame.minY, 62)
        XCTAssertTrue(display.contains(frame))
    }

    func testCaptureShortcutStillWorksInEditorUnlessItIsAnEditingCommand() {
        XCTAssertTrue(EditorShortcutPolicy.canCapture(.defaultShortcut, editorFocused: true, sheetFocused: false))
        for shortcut in [KeyboardShortcut(keyCode: 8, flags: .maskCommand),
                         KeyboardShortcut(keyCode: 6, flags: .maskCommand),
                         KeyboardShortcut(keyCode: 6, flags: [.maskCommand, .maskShift]),
                         KeyboardShortcut(keyCode: 1, flags: .maskCommand)] {
            XCTAssertFalse(EditorShortcutPolicy.canCapture(shortcut, editorFocused: true, sheetFocused: false))
            XCTAssertTrue(EditorShortcutPolicy.canCapture(shortcut, editorFocused: false, sheetFocused: false))
            XCTAssertFalse(EditorShortcutPolicy.canCapture(shortcut, editorFocused: false, sheetFocused: true))
        }
        XCTAssertFalse(EditorShortcutPolicy.canCapture(.defaultShortcut, editorFocused: false, sheetFocused: true))
    }
}
