import AppKit
import SwiftUI
import ApplicationServices
import ServiceManagement
import OSLog
import PanoCore

@MainActor
final class AppModel: ObservableObject {
    @Published var accessibility = false
    @Published var screenAccess = false
    @Published var shortcutActive = false
    @Published var busy = false
    @Published var lastMessage = "Select an area to copy it to your clipboard."
    @Published var errorMessage: String?
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    @Published var justCopied = false
    @Published private var shortcutDraft = ShortcutDraft(current: ShortcutStore().load())
    @Published var recorderPresented = false
    @Published private(set) var isRecording = false
    @Published private(set) var checkingConflict = false
    @Published private(set) var conflictReport: ConflictReport?
    @Published private(set) var recorderMessage: String?
    private let shortcutStore = ShortcutStore()
    private var recordingSession = UUID()
    var shortcut: CaptureShortcut { shortcutDraft.current }
    var candidate: CaptureShortcut? { shortcutDraft.candidate }
    let tap = ShortcutTap()
    private let captureService = CaptureService()
    private let logger = Logger(subsystem: "local.toprak.Pano", category: "app")
    private var permissionTimer: Timer?
    private var feedbackTimer: Timer?
    // Returns the matching restoration action for this capture session.
    var prepareWindowForCapture: () -> (() -> Void) = { {} }
    var stateChanged: () -> Void = {}

    var ready: Bool { accessibility && screenAccess && shortcutActive }

    func start() {
        tap.canCapture = { [weak self] in
            guard let self else { return false }
            return self.ready && !self.busy && !self.recorderPresented
        }
        tap.shortcut = shortcut
        tap.onRecorded = { [weak self] value in
            guard let self, self.isRecording else { return }
            self.shortcutDraft.record(value)
            self.recorderMessage = nil
        }
        tap.onShortcut = { [weak self] in self?.capture() }
        refresh()
        if !UserDefaults.standard.bool(forKey: "loginRegistrationAttempted") {
            UserDefaults.standard.set(true, forKey: "loginRegistrationAttempted")
            setLoginEnabled(true)
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        logger.info("Pano started")
    }

    func refresh() {
        accessibility = AXIsProcessTrusted()
        screenAccess = CGPreflightScreenCaptureAccess()
        if accessibility {
            shortcutActive = tap.start()
        } else {
            cancelRecorder()
            tap.stop()
            shortcutActive = false
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
        stateChanged()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }

    func requestScreenAccess() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        openPrivacy("Privacy_ScreenCapture")
        refresh()
    }

    private func openPrivacy(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = "Could not update launch at login: \(error.localizedDescription)"
            logger.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    func capture() {
        guard !busy, !recorderPresented else { return }
        refresh()
        guard ready else {
            errorMessage = "Allow both permissions to start using Pano."
            return
        }
        busy = true
        errorMessage = nil
        justCopied = false
        lastMessage = "Select an area. Press Esc to cancel."
        let restoreWindow = prepareWindowForCapture()
        stateChanged()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self else { return }
            self.captureService.capture { [weak self] result in
                guard let self else { return }
                self.busy = false
                defer { restoreWindow() }
                switch result {
                case .success(.cancelled):
                    self.lastMessage = "Selection cancelled."
                    self.logger.info("Capture cancelled")
                case .success(.copied(let width, let height)):
                    self.lastMessage = "Copied to clipboard · \(width) × \(height)"
                    self.justCopied = true
                    self.logger.info("Capture copied: \(width)x\(height)")
                    self.feedbackTimer?.invalidate()
                    self.feedbackTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            self?.justCopied = false
                            self?.stateChanged()
                        }
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.lastMessage = "Could not copy. Open Pano Settings."
                    NSSound.beep()
                    self.logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                }
                self.stateChanged()
            }
        }
    }

    func beginRecording() {
        refresh()
        guard accessibility, shortcutActive, !busy else {
            errorMessage = "Allow Accessibility first to record a shortcut."
            return
        }
        recordingSession = UUID()
        shortcutDraft.cancel()
        conflictReport = nil
        recorderMessage = nil
        checkingConflict = false
        recorderPresented = true
        isRecording = true
        tap.beginRecording()
        stateChanged()
    }

    func stopRecording() {
        guard isRecording else { return }
        tap.endRecording()
        isRecording = false
        guard let candidate, candidate.isValid else {
            recorderMessage = "No shortcut recorded. Press a key with any modifiers you want, then click Stop Recording."
            return
        }
        guard !candidate.reserved else {
            recorderMessage = "macOS reserves this shortcut for a protected system action. Choose another shortcut."
            return
        }
        checkingConflict = true
        let session = recordingSession
        Task {
            let report = await ShortcutConflictDetector.inspect(candidate)
            guard recordingSession == session, recorderPresented else { return }
            checkingConflict = false
            if !report.tasks.isEmpty || report.incomplete {
                conflictReport = report
            } else {
                saveRecordedShortcut()
            }
        }
    }

    func saveRecordedShortcut() {
        guard let candidate, candidate.isValid, !candidate.reserved else { return }
        do {
            try shortcutStore.save(candidate)
            _ = shortcutDraft.accept()
            tap.shortcut = shortcut
            lastMessage = "Shortcut updated · \(shortcut.display)"
            cancelRecorder()
            errorMessage = nil
            stateChanged()
        } catch { recorderMessage = error.localizedDescription }
    }

    func cancelRecorder() {
        recordingSession = UUID()
        tap.endRecording()
        isRecording = false
        checkingConflict = false
        conflictReport = nil
        recorderMessage = nil
        shortcutDraft.cancel()
        recorderPresented = false
        stateChanged()
    }

    func stop() {
        cancelRecorder()
        permissionTimer?.invalidate()
        feedbackTimer?.invalidate()
        tap.stop()
        captureService.stop()
    }
}
