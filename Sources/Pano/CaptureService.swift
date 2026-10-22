import AppKit
import PanoCore

@MainActor
final class CaptureService {
    private var process: Process?
    private var directory: URL?
    var isRunning: Bool { process != nil }

    func capture(completion: @escaping (Result<CaptureResult, Error>) -> Void) {
        guard process == nil else { return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Pano-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
                                                   attributes: [.posixPermissions: 0o700])
            directory = folder
            let file = folder.appendingPathComponent("capture.png")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-s", "-x", "-t", "png", file.path]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { [weak self] ended in
                DispatchQueue.main.async {
                    defer {
                        try? FileManager.default.removeItem(at: folder)
                        self?.process = nil
                        self?.directory = nil
                    }
                    completion(Result {
                        try CaptureOutput.copy(file: file, exitStatus: ended.terminationStatus, to: .general)
                    })
                }
            }
            process = task
            try task.run()
        } catch {
            process = nil
            directory = nil
            try? FileManager.default.removeItem(at: folder)
            completion(.failure(error))
        }
    }

    func stop() {
        process?.terminationHandler = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }
}
