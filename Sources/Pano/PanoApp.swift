import AppKit
import SwiftUI

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
        model.prepareWindowForCapture = { [weak self] in
            guard let self, let window = self.settingsWindow,
                  window.isVisible, !window.isMiniaturized else { return {} }
            let session = self.windowSession
            window.orderOut(nil)
            return { [weak self, weak window] in
                guard let self, let window, self.windowSession == session,
                      !window.isMiniaturized else { return }
                // Return after success, cancellation, or failure without taking
                // keyboard focus away from the user's destination app.
                window.orderFront(nil)
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
        NSApp.setActivationPolicy(.accessory)
    }
    func applicationWillResignActive(_ notification: Notification) {
        if model.isRecording { model.cancelRecorder() }
    }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
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
    private func installApplicationMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Pano")
        let quitItem = appMenu.addItem(withTitle: "Quit Pano", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appItem.submenu = appMenu
        menu.addItem(appItem)
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
