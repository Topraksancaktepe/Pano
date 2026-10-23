import Foundation

public struct AnnotationHistory: Sendable {
    public private(set) var annotations: [Annotation] = []
    private var undone: [Annotation] = []
    public init() {}
    public var canUndo: Bool { !annotations.isEmpty }
    public var canRedo: Bool { !undone.isEmpty }
    public var nextStep: Int { (annotations.filter { $0.tool == .step }.map(\.number).max() ?? 0) + 1 }

    public mutating func append(_ value: Annotation) {
        guard value.isMeaningful else { return }
        var annotation = value
        if annotation.tool == .step { annotation.number = nextStep }
        annotations.append(annotation)
        undone.removeAll()
    }

    public mutating func undo() {
        if let last = annotations.popLast() { undone.append(last) }
    }

    public mutating func redo() {
        if let last = undone.popLast() { annotations.append(last) }
    }
}
