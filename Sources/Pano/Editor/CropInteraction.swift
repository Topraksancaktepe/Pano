import AppKit
import PanoCore

struct CropDrag {
    private enum Mode { case new, move, resize(horizontal: Int, vertical: Int) }
    private let start: CGPoint
    private let initial: CGRect
    private let mode: Mode

    init(start: CGPoint, selection: CGRect?, tolerance: CGFloat) {
        self.start = start
        initial = selection ?? .zero
        guard let selection, selection.insetBy(dx: -tolerance, dy: -tolerance).contains(start) else {
            mode = .new
            return
        }
        let horizontal = abs(start.x - selection.minX) < tolerance ? -1
            : abs(start.x - selection.maxX) < tolerance ? 1 : 0
        let vertical = abs(start.y - selection.minY) < tolerance ? -1
            : abs(start.y - selection.maxY) < tolerance ? 1 : 0
        if horizontal != 0 || vertical != 0 { mode = .resize(horizontal: horizontal, vertical: vertical) }
        else { mode = .move }
    }

    func region(at point: CGPoint, image: CGSize) -> CGRect {
        switch mode {
        case .new:
            return CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                          width: abs(point.x - start.x), height: abs(point.y - start.y))
        case .move:
            return ImageGeometry.moveCrop(initial,
                by: CGSize(width: point.x - start.x, height: point.y - start.y), image: image)
        case .resize(let horizontal, let vertical):
            let x0 = horizontal == -1 ? point.x : initial.minX
            let x1 = horizontal == 1 ? point.x : initial.maxX
            let y0 = vertical == -1 ? point.y : initial.minY
            let y1 = vertical == 1 ? point.y : initial.maxY
            return CGRect(x: min(x0, x1), y: min(y0, y1), width: abs(x1 - x0), height: abs(y1 - y0))
        }
    }
}

enum CropOverlay {
    static func draw(_ selection: CGRect, image: CGSize, pixelWidth: CGFloat, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.addRect(CGRect(origin: .zero, size: image))
        context.addRect(selection)
        context.setFillColor(NSColor.black.withAlphaComponent(0.48).cgColor)
        context.fillPath(using: .evenOdd)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.2 * pixelWidth)
        context.stroke(selection)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.6 * pixelWidth)
        for fraction: CGFloat in [1 / 3, 2 / 3] {
            let x = selection.minX + selection.width * fraction
            let y = selection.minY + selection.height * fraction
            context.move(to: CGPoint(x: x, y: selection.minY))
            context.addLine(to: CGPoint(x: x, y: selection.maxY))
            context.move(to: CGPoint(x: selection.minX, y: y))
            context.addLine(to: CGPoint(x: selection.maxX, y: y))
        }
        context.strokePath()
        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        for x in [selection.minX, selection.midX, selection.maxX] {
            for y in [selection.minY, selection.midY, selection.maxY] {
                if x == selection.midX && y == selection.midY { continue }
                let handle = CGRect(x: x - 3 * pixelWidth, y: y - 3 * pixelWidth,
                                    width: 6 * pixelWidth, height: 6 * pixelWidth)
                context.fill(handle)
                context.stroke(handle)
            }
        }
    }
}
