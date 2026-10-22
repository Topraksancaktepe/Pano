import AppKit
import SwiftUI

@main
struct PanoControlApp: App {
    @NSApplicationDelegateAdaptor(ControlDelegate.self) private var delegate
    @StateObject private var controller = PanoController()

    var body: some Scene {
        WindowGroup("Pano") {
            ControlView(controller: controller)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

@MainActor
final class ControlDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
