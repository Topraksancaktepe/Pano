import AppKit
import SwiftUI
import PanoCore

@main
struct PanoApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var windowSession = UUID()
    private var captureItem: NSMenuItem!
    private var stateItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private let preview = CapturePreview()
    private var editors: [UUID: EditorWindowController] = [:]
    private var captureScreen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "local.toprak.Pano")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            existing.activate()
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Pano")
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        stateItem = menu.addItem(withTitle: "Pano", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(.separator())
        captureItem = menu.addItem(withTitle: "Select and Copy", action: #selector(capture), keyEquivalent: "")
        captureItem.target = self
        let settings = menu.addItem(withTitle: "Pano Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        loginItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Pano", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
        installApplicationMenu()
        preview.onEdit = { [weak self] screenshot in self?.openEditor(screenshot) }
        model.onCapture = { [weak self] screenshot in
            guard let self else { return }
            self.preview.show(screenshot, on: self.captureScreen)
        }
        model.captureShortcutAllowed = { [weak self] in
            guard let self else { return false }
            return EditorShortcutPolicy.canCapture(self.model.shortcut,
                editorFocused: self.editors.values.contains { $0.window?.isKeyWindow == true },
                sheetFocused: self.editors.values.contains { $0.window?.attachedSheet?.isKeyWindow == true })
        }
        model.prepareWindowForCapture = { [weak self] in
            guard let self else { return {} }
            self.captureScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            let restorePreview = self.preview.hideForCapture()
            let session = self.windowSession
            let settings = self.settingsWindow.flatMap { $0.isVisible && !$0.isMiniaturized ? $0 : nil }
            let visibleEditors = self.editors.filter { $0.value.window?.isVisible == true && $0.value.window?.isMiniaturized == false }
            settings?.orderOut(nil)
            for editor in visibleEditors.values { editor.window?.orderOut(nil) }
            return { [weak self, weak settings] in
                guard let self else { return }
                if self.windowSession == session, settings?.isMiniaturized == false { settings?.orderFront(nil) }
                for (id, editor) in visibleEditors where self.editors[id] != nil {
                    if editor.window?.isMiniaturized == false { editor.window?.orderFront(nil) }
                }
                restorePreview()
            }
        }
        model.stateChanged = { [weak self] in self?.updateMenu() }
        model.start()
        let seen = UserDefaults.standard.bool(forKey: "hasOpened")
        UserDefaults.standard.set(true, forKey: "hasOpened")
        if !seen || !model.ready { showSettings() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) { model.refresh() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) {
        windowSession = UUID()
        model.cancelRecorder()
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }
    func applicationWillResignActive(_ notification: Notification) {
        if model.isRecording { model.cancelRecorder() }
    }
    func applicationWillTerminate(_ notification: Notification) { preview.dismiss(); model.stop() }
    func menuWillOpen(_ menu: NSMenu) { model.refresh() }

    private func updateMenu() {
        guard statusItem != nil else { return }
        let symbol = model.justCopied ? "checkmark.square.fill" : "viewfinder"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Pano")
        statusItem.button?.toolTip = model.lastMessage
        stateItem.title = model.ready ? model.lastMessage : "Open Pano Settings to finish setup"
        captureItem.title = "Select and Copy    \(model.shortcut.display)"
        captureItem.isEnabled = model.ready && !model.busy && !model.recorderPresented
        loginItem.state = model.loginEnabled ? .on : .off
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 610),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Pano"
            window.delegate = self
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        windowSession = UUID()
        model.refresh()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func openEditor(_ screenshot: Screenshot) {
        let controller = EditorWindowController(screenshot: screenshot)
        controller.onClose = { [weak self] id in
            // Defer ownership release until AppKit finishes closing the window.
            DispatchQueue.main.async { [weak self] in
                self?.editors[id] = nil
                self?.updateActivationPolicy()
            }
        }
        editors[controller.id] = controller
        controller.present()
    }

    private func updateActivationPolicy() {
        let hasRegularWindow = settingsWindow?.isVisible == true || settingsWindow?.isMiniaturized == true || !editors.isEmpty
        NSApp.setActivationPolicy(hasRegularWindow ? .regular : .accessory)
    }

    private var activeEditor: EditorWindowController? {
        editors.values.first { $0.window?.isKeyWindow == true && !$0.savePanelOpen }
    }

    @objc private func undoImage() {
        if let editor = activeEditor { editor.model.undo() }
        else { NSApp.keyWindow?.firstResponder?.undoManager?.undo() }
    }
    @objc private func redoImage() {
        if let editor = activeEditor { editor.model.redo() }
        else { NSApp.keyWindow?.firstResponder?.undoManager?.redo() }
    }
    @objc private func copyImage() {
        if let editor = activeEditor { editor.model.copy() }
        else { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
    }
    @objc private func saveImage() { activeEditor?.save() }

    private func installApplicationMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Pano")
        let quitItem = appMenu.addItem(withTitle: "Quit Pano", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let save = fileMenu.addItem(withTitle: "Save Image…", action: #selector(saveImage), keyEquivalent: "s")
        save.target = self
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        let undo = editMenu.addItem(withTitle: "Undo", action: #selector(undoImage), keyEquivalent: "z")
        undo.target = self
        let redo = editMenu.addItem(withTitle: "Redo", action: #selector(redoImage), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        redo.target = self
        editMenu.addItem(.separator())
        // Standard responder-chain copy/cut/paste keep native save-panel text fields usable.
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        let copy = editMenu.addItem(withTitle: "Copy", action: #selector(copyImage), keyEquivalent: "c")
        copy.target = self
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu
    }
    @objc private func capture() {
        // Let the menu finish closing before capture selection starts.
        DispatchQueue.main.async { [weak self] in self?.model.capture() }
    }
    @objc private func toggleLogin() { model.setLoginEnabled(!model.loginEnabled) }
    @objc private func didWake() { model.refresh() }
    @objc private func quit() { NSApp.terminate(nil) }
}
