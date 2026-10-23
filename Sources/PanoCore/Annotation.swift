import AppKit

public enum AnnotationTool: String, CaseIterable, Identifiable, Sendable {
    case arrow, pen, highlight, smoothBlur, pixelate, step
    public var id: String { rawValue }
    public var isRedaction: Bool { self == .smoothBlur || self == .pixelate }
}

public enum AnnotationColor: String, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, blue, purple, white, black
    public var id: String { rawValue }
    public var nsColor: NSColor {
        switch self {
        case .red: return NSColor(srgbRed: 0.96, green: 0.25, blue: 0.30, alpha: 1)
        case .orange: return NSColor(srgbRed: 1, green: 0.55, blue: 0.18, alpha: 1)
        case .yellow: return NSColor(srgbRed: 1, green: 0.85, blue: 0.16, alpha: 1)
        case .green: return NSColor(srgbRed: 0.19, green: 0.76, blue: 0.52, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.20, green: 0.55, blue: 1, alpha: 1)
        case .purple: return NSColor(srgbRed: 0.65, green: 0.40, blue: 0.97, alpha: 1)
        case .white: return .white
        case .black: return NSColor(srgbRed: 0.09, green: 0.10, blue: 0.12, alpha: 1)
        }
    }
}

public struct Annotation: Identifiable, Sendable {
    public let id = UUID()
    public let tool: AnnotationTool
    public var points: [CGPoint]
    public let color: AnnotationColor
    public let width: CGFloat
    public let strength: CGFloat
    public var number: Int

    public init(tool: AnnotationTool, points: [CGPoint], color: AnnotationColor = .red,
                width: CGFloat = 4, strength: CGFloat = 16, number: Int = 1) {
        self.tool = tool
        self.points = points
        self.color = color
        self.width = width
        self.strength = strength
        self.number = number
    }

    public var region: CGRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                      width: abs(last.x - first.x), height: abs(last.y - first.y))
    }

    public var isMeaningful: Bool {
        if tool == .step { return points.count == 1 }
        if tool.isRedaction { return region.width >= 2 && region.height >= 2 }
        guard points.count >= 2, let first = points.first else { return false }
        return points.contains { hypot($0.x - first.x, $0.y - first.y) >= 1 }
    }
}
