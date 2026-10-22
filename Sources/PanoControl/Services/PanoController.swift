import AppKit
import SwiftUI

/// Controls the already installed capture app without changing its signature or permissions.
@MainActor
final class PanoController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isChanging = false
    @Published private(set) var errorMessage: String?
    private let captureAppID = "local.toprak.Pano"
    private let captureAppURL = URL(fileURLWithPath: "/Applications/Pano.app")

    init() { refresh() }

    private var runningApps: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: captureAppID)
            .filter { !$0.isTerminated }
    }

    func refresh() { isRunning = !runningApps.isEmpty }

    func toggle() {
        guard !isChanging else { return }
        refresh()
        errorMessage = nil
        isChanging = true
        let shouldStart = !isRunning
        Task {
            defer {
                refresh()
                isChanging = false
            }
            do {
                if shouldStart {
                    try await launch(activate: false)
                } else {
                    for app in runningApps {
                        guard app.terminate() else { throw ControlError.cannotStop }
                    }
                }
                // Confirm the requested state rather than changing the label optimistically.
                for _ in 0..<40 {
                    refresh()
                    if isRunning == shouldStart { return }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw shouldStart ? ControlError.cannotStart : ControlError.cannotStop
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func openSettings() {
        refresh()
        guard !isChanging, isRunning else { return }
        errorMessage = nil
        isChanging = true
        Task {
            defer {
                refresh()
                isChanging = false
            }
            do { try await launch(activate: true) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func launch(activate: Bool) async throws {
        guard FileManager.default.fileExists(atPath: captureAppURL.path) else {
            throw ControlError.notInstalled
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        _ = try await NSWorkspace.shared.openApplication(at: captureAppURL, configuration: configuration)
    }
}

private enum ControlError: LocalizedError {
    case notInstalled, cannotStart, cannotStop
    var errorDescription: String? {
        switch self {
        case .notInstalled: return "Pano was not found in Applications."
        case .cannotStart: return "Could not start Pano. Try opening it from Applications."
        case .cannotStop: return "Could not stop Pano. Press Esc to cancel any active selection, then try again."
        }
    }
}
