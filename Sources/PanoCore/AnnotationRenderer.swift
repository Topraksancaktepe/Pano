import AppKit
import CoreImage
import CoreText

public enum AnnotationRenderer {
    private static let filters = CIContext(options: [.cacheIntermediates: false])

    public static func render(image: CGImage, annotations: [Annotation]) throws -> CGImage {
        guard !annotations.isEmpty else { return image }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CaptureError.invalidImage }
        context.draw(image, in: bounds)
        for annotation in annotations where annotation.isMeaningful {
            if annotation.tool.isRedaction {
                guard let composed = context.makeImage() else { throw CaptureError.invalidImage }
                try redact(annotation, image: composed, context: context, bounds: bounds)
            } else {
                context.saveGState()
                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1, y: -1)
                context.clip(to: bounds)
                drawVector(annotation, in: context)
                context.restoreGState()
            }
        }
        guard let result = context.makeImage() else { throw CaptureError.invalidImage }
        return result
    }

    /// Draws into a top-left coordinate system, also used for lightweight live strokes.
    public static func drawVector(_ annotation: Annotation, in context: CGContext) {
        guard let first = annotation.points.first else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let width = max(1, annotation.width)
        context.setStrokeColor(annotation.color.nsColor.cgColor)
        context.setFillColor(annotation.color.nsColor.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch annotation.tool {
        case .arrow:
            guard let last = annotation.points.last else { return }
            let angle = atan2(last.y - first.y, last.x - first.x)
            let length = min(max(width * 4, 12), hypot(last.x - first.x, last.y - first.y) * 0.45)
            context.move(to: first)
            context.addLine(to: last)
            context.strokePath()
            context.move(to: CGPoint(x: last.x - length * cos(angle - .pi / 6), y: last.y - length * sin(angle - .pi / 6)))
            context.addLine(to: last)
            context.addLine(to: CGPoint(x: last.x - length * cos(angle + .pi / 6), y: last.y - length * sin(angle + .pi / 6)))
            context.strokePath()
        case .pen, .highlight:
            if annotation.tool == .highlight {
                context.setAlpha(0.35)
                context.setBlendMode(.multiply)
                context.setLineWidth(width * 5)
                context.setLineCap(.butt)
            }
            // A single path avoids alpha accumulating where a highlighter crosses itself.
            context.move(to: first)
            for point in annotation.points.dropFirst() { context.addLine(to: point) }
            context.strokePath()
        case .step:
            let radius = max(12, width * 4)
            let circle = CGRect(x: first.x - radius, y: first.y - radius, width: radius * 2, height: radius * 2)
            context.setShadow(offset: CGSize(width: 0, height: 1), blur: radius * 0.15,
                              color: NSColor.black.withAlphaComponent(0.22).cgColor)
            context.fillEllipse(in: circle)
            context.setShadow(offset: .zero, blur: 0)
            context.setLineWidth(max(1, radius * 0.09))
            context.setStrokeColor(NSColor.white.cgColor)
            context.strokeEllipse(in: circle.insetBy(dx: 0.6, dy: 0.6))
            let font = CTFontCreateWithName(".AppleSystemUIFont-Bold" as CFString, radius * 1.1, nil)
            let textColor = annotation.color.textColor
            let string = NSAttributedString(string: String(annotation.number), attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor.cgColor
            ])
            let line = CTLineCreateWithAttributedString(string)
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let textWidth = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            context.translateBy(x: first.x, y: first.y)
            context.scaleBy(x: 1, y: -1)
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: -textWidth / 2, y: -(ascent - descent) / 2)
            CTLineDraw(line, context)
        case .smoothBlur, .pixelate: break
        }
    }

    private static func redact(_ annotation: Annotation, image: CGImage, context: CGContext, bounds: CGRect) throws {
        let region = annotation.region.intersection(bounds).integral.intersection(bounds)
        guard !region.isEmpty, !region.isNull else { return }
        // CI uses a bottom-left origin. Output cropping uses CGImage's top-left origin.
        let input = CIImage(cgImage: image)
        let strength = max(2, annotation.strength)
        let output: CIImage
        if annotation.tool == .smoothBlur {
            output = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: strength])
        } else {
            output = input.clampedToExtent().applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: strength,
                kCIInputCenterKey: CIVector(x: 0, y: 0)
            ])
        }
        guard let filtered = filters.createCGImage(output, from: input.extent),
              let cropped = filtered.cropping(to: region)
        else { throw CaptureError.invalidImage }
        let destination = CGRect(x: region.minX, y: bounds.height - region.maxY,
                                 width: region.width, height: region.height)
        context.saveGState()
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(cropped, in: destination)
        context.restoreGState()
    }
}
