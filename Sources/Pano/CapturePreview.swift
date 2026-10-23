import AppKit
import SwiftUI
import PanoCore

private final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class CapturePreview {
    private var panel: NSPanel?
    private var timer: Timer?
    private var session = UUID()
    private var suspended = false
    var onEdit: (Screenshot) -> Void = { _ in }

    func show(_ screenshot: Screenshot, on screen: NSScreen?) {
        dismiss()
        session = UUID()
        suspended = false
        let visible = (screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1000, height: 700)
        let frame = ImageGeometry.previewFrame(size: NSSize(width: 270, height: 196), visibleFrame: visible)
        let panel = PreviewPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: CapturePreviewView(screenshot: screenshot,
            onEdit: { [weak self] in
                guard let self else { return }
                self.dismiss()
                self.onEdit(screenshot)
            }, onDismiss: { [weak self] in self?.dismiss() },
            onHover: { [weak self] hovering in self?.hoverChanged(hovering) }))
        self.panel = panel
        panel.orderFrontRegardless()
        scheduleDismissal()
    }

    func hideForCapture() -> () -> Void {
        let token = session
        let wasVisible = panel?.isVisible == true
        suspended = true
        timer?.invalidate()
        panel?.orderOut(nil)
        return { [weak self] in
            guard let self, self.session == token else { return }
            self.suspended = false
            if wasVisible {
                self.panel?.orderFrontRegardless()
                self.scheduleDismissal()
            }
        }
    }

    func dismiss() {
        session = UUID()
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func hoverChanged(_ hovering: Bool) {
        timer?.invalidate()
        if !hovering && !suspended { scheduleDismissal() }
    }

    private func scheduleDismissal() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }
}

private struct CapturePreviewView: View {
    let screenshot: Screenshot
    let onEdit: () -> Void
    let onDismiss: () -> Void
    let onHover: (Bool) -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onEdit) {
                Image(nsImage: NSImage(cgImage: screenshot.image, size: screenshot.size))
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                    .overlay(alignment: .center) {
                        if hovering {
                            Label("Edit Screenshot", systemImage: "pencil.tip")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 13).padding(.vertical, 9)
                                .background(.regularMaterial, in: Capsule())
                        }
                    }
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Edit captured screenshot")
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(EditorTheme.accent)
                Text("Copied to clipboard").fontWeight(.medium)
                Spacer()
                Text("\(screenshot.image.width) × \(screenshot.image.height)").foregroundStyle(.secondary)
                    .font(.system(size: 9)).monospacedDigit()
            }
            .font(.system(size: 10)).padding(.horizontal, 12).frame(height: 31)
            .background(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    .frame(width: 21, height: 21).background(.regularMaterial, in: Circle())
            }.buttonStyle(.plain).padding(7).accessibilityLabel("Dismiss screenshot preview")
        }
        .onHover { hovering = $0; onHover($0) }
        .padding(4)
    }
}
