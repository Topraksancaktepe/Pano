import AppKit
import SwiftUI
import PanoCore
import UniformTypeIdentifiers

enum EditorGroup: String, CaseIterable {
    case markup = "Markup", redact = "Redact", steps = "Steps"
}

@MainActor
final class EditorModel: ObservableObject {
    let original: Screenshot
    @Published private(set) var image: CGImage
    @Published private(set) var history = AnnotationHistory()
    @Published var group: EditorGroup = .markup
    @Published var markupTool: AnnotationTool = .arrow
    @Published var redactTool: AnnotationTool = .pixelate
    @Published var color: AnnotationColor = .red
    @Published var strokeWidth: CGFloat = 4
    @Published var strength: CGFloat = 18
    @Published var zoom: CGFloat = 1
    @Published private(set) var isRendering = false
    @Published var message = ""
    @Published var errorMessage: String?
    private let renderQueue = DispatchQueue(label: "local.toprak.Pano.render", qos: .userInitiated)
    private var feedback: Task<Void, Never>?

    init(screenshot: Screenshot) {
        original = screenshot
        image = screenshot.image
    }

    var tool: AnnotationTool {
        switch group {
        case .markup: return markupTool
        case .redact: return redactTool
        case .steps: return .step
        }
    }
    var pixelScale: CGFloat { max(1, max(original.size.width, original.size.height) / 1400) }
    var hint: String {
        switch tool {
        case .arrow: return "Drag to point something out."
        case .pen: return "Draw freely on your screenshot."
        case .highlight: return "Drag over the part you want to highlight."
        case .smoothBlur, .pixelate: return "Drag a rectangle over the area to blur."
        case .step: return "Click to place step \(history.nextStep)."
        }
    }

    func annotation(points: [CGPoint]) -> Annotation {
        Annotation(tool: tool, points: points, color: color,
                   width: strokeWidth * pixelScale, strength: strength * pixelScale,
                   number: history.nextStep)
    }

    func commit(_ annotation: Annotation) {
        guard !isRendering, annotation.isMeaningful else { return }
        update { $0.append(annotation) }
    }

    func undo() {
        guard !isRendering, history.canUndo else { return }
        update { $0.undo() }
    }

    func redo() {
        guard !isRendering, history.canRedo else { return }
        update { $0.redo() }
    }

    private func update(_ change: (inout AnnotationHistory) -> Void) {
        let previous = history
        change(&history)
        let annotations = history.annotations
        let source = original.image
        isRendering = true
        renderQueue.async { [weak self] in
            let result = Result { try AnnotationRenderer.render(image: source, annotations: annotations) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let output): self.image = output
                case .failure(let error):
                    self.history = previous
                    self.errorMessage = error.localizedDescription
                }
                self.isRendering = false
            }
        }
    }

    func copy() {
        guard !isRendering else { return }
        do {
            try Screenshot(image: image).copy(to: .general)
            showFeedback("Copied to clipboard")
        } catch { errorMessage = error.localizedDescription }
    }

    func save(in window: NSWindow) {
        guard !isRendering else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Pano-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)) ).png"
        panel.prompt = "Save Image"
        // Freeze exactly the visible, flattened pixels while the save panel is open.
        let output = Screenshot(image: image)
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try output.pngData().write(to: url, options: .atomic)
                self?.showFeedback("Image saved")
            } catch { self?.errorMessage = error.localizedDescription }
        }
    }

    private func showFeedback(_ value: String) {
        feedback?.cancel()
        message = value
        feedback = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.message = ""
        }
    }
}
