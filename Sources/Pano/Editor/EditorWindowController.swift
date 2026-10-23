import AppKit
import SwiftUI
import PanoCore

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let id = UUID()
    let model: EditorModel
    var onClose: (UUID) -> Void = { _ in }
    var savePanelOpen: Bool { window?.attachedSheet != nil }

    init(screenshot: Screenshot) {
        model = EditorModel(screenshot: screenshot)
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1100, height: 760)
        let size = NSSize(width: min(1000, visible.width - 60), height: min(720, visible.height - 60))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Pano — Edit Screenshot"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 760, height: 470)
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView(model: model, onSave: { [weak self] in self?.save() }))
        window.center()
        window.setFrameAutosaveName("PanoScreenshotEditor")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func present() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func save() {
        guard let window, !savePanelOpen else { return }
        model.save(in: window)
    }
    func windowWillClose(_ notification: Notification) { onClose(id) }
}
