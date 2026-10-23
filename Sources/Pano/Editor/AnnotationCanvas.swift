import AppKit
import SwiftUI
import PanoCore

struct AnnotationCanvas: NSViewRepresentable {
    @ObservedObject var model: EditorModel

    func makeNSView(context: Context) -> AnnotationCanvasView {
        let view = AnnotationCanvasView()
        view.model = model
        return view
    }

    func updateNSView(_ view: AnnotationCanvasView, context: Context) {
        view.model = model
        view.needsDisplay = true
        view.window?.invalidateCursorRects(for: view)
    }
}

/// Pointer events stay here; tools, history and committed pixels belong to EditorModel.
@MainActor
final class AnnotationCanvasView: NSView {
    weak var model: EditorModel?
    private var draft: Annotation?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Screenshot canvas")
        setAccessibilityHelp("Choose a tool above, then click or drag on the image to annotate it.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        guard let model else { return }
        let image = NSImage(cgImage: model.image, size: model.original.size)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        guard let draft, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x: bounds.width / model.original.size.width,
                        y: bounds.height / model.original.size.height)
        if draft.tool.isRedaction {
            let rect = draft.region
            context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            let pixelWidth = model.original.size.width / max(1, bounds.width)
            context.setLineWidth(pixelWidth)
            context.setLineDash(phase: 0, lengths: [5 * pixelWidth, 3 * pixelWidth])
            context.stroke(rect)
        } else {
            AnnotationRenderer.drawVector(draft, in: context)
        }
        context.restoreGState()
    }

    private func point(for event: NSEvent, clamp: Bool = false) -> CGPoint? {
        guard let model else { return nil }
        var point = convert(event.locationInWindow, from: nil)
        if clamp {
            point.x = min(max(0, point.x), max(0, bounds.width - 0.01))
            point.y = min(max(0, point.y), max(0, bounds.height - 0.01))
        }
        return ImageGeometry.imagePoint(point, in: bounds, image: model.original.size)
    }

    override func mouseDown(with event: NSEvent) {
        guard let model, !model.isRendering, let point = point(for: event) else { return }
        window?.makeFirstResponder(self)
        if model.tool == .step {
            model.commit(model.annotation(points: [point]))
        } else {
            draft = model.annotation(points: [point, point])
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard var annotation = draft, let point = point(for: event, clamp: true) else { return }
        if annotation.tool == .pen || annotation.tool == .highlight {
            if let last = annotation.points.last, hypot(point.x - last.x, point.y - last.y) < 0.8 { return }
            annotation.points.append(point)
        } else {
            annotation.points = [annotation.points[0], point]
        }
        draft = annotation
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var annotation = draft else { return }
        if let point = point(for: event, clamp: true) {
            if annotation.tool == .pen || annotation.tool == .highlight { annotation.points.append(point) }
            else { annotation.points = [annotation.points[0], point] }
        }
        draft = nil
        model?.commit(annotation)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, draft != nil {
            draft = nil
            needsDisplay = true
        } else { super.keyDown(with: event) }
    }
}
