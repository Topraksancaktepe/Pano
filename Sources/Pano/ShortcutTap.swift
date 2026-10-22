import AppKit
import ApplicationServices
import PanoCore

@MainActor
final class ShortcutTap {
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var filter = ShortcutFilter()
    var canCapture: () -> Bool = { false }
    var onShortcut: () -> Void = {}
    var shortcut = CaptureShortcut.defaultShortcut
    var isRecording = false
    var onRecorded: (CaptureShortcut) -> Void = { _ in }
    private var localMonitor: Any?

    func beginRecording() {
        isRecording = true
        // Also handle app-local events (including accessibility-generated key events).
        // Global events consumed by the tap never reach this monitor.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.type == .keyDown, !event.isARepeat {
                self.onRecorded(CaptureShortcut(keyCode: Int64(event.keyCode),
                    flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))))
            }
            return nil
        }
    }

    func endRecording() {
        isRecording = false
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
    }

    var isRunning: Bool { port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        if let port {
            CGEvent.tapEnable(tap: port, enable: true)
            return true
        }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
                 | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let newPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                return MainActor.assumeIsolated {
                    let owner = Unmanaged<ShortcutTap>.fromOpaque(info).takeUnretainedValue()
                    return owner.receive(type: type, event: event)
                }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        port = newPort
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newPort, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newPort, enable: true)
        return true
    }

    func stop() {
        endRecording()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMachPortInvalidate(port) }
        port = nil
        source = nil
        filter = ShortcutFilter()
    }

    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            filter = ShortcutFilter()
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
        let decision = filter.handle(keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                                     down: type == .keyDown, flags: event.flags,
                                     isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                                     enabled: canCapture(), shortcut: shortcut, recording: isRecording && NSApp.isActive)
        switch decision {
        case .pass: return Unmanaged.passUnretained(event)
        case .suppress: return nil
        case .record(let shortcut):
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRecording else { return }
                self.onRecorded(shortcut)
            }
            return nil
        case .trigger:
            // Never block the event-tap callback with capture, UI or disk work.
            DispatchQueue.main.async { [weak self] in self?.onShortcut() }
            return nil
        }
    }
}
