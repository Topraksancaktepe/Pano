import AppKit
import ImageIO

public enum CaptureResult: Equatable {
    case cancelled
    case copied(width: Int, height: Int)
}

public enum CaptureError: LocalizedError {
    case processFailed, invalidImage, clipboardUnavailable
    public var errorDescription: String? {
        switch self {
        case .processFailed: return "Could not capture the screen. Check Screen Recording permission."
        case .invalidImage: return "Could not read the screenshot. Try again."
        case .clipboardUnavailable: return "Could not write to the clipboard. Try again."
        }
    }
}

public enum CaptureOutput {
    /// Validate everything before touching the existing clipboard.
    public static func copy(file: URL, exitStatus: Int32, to board: NSPasteboard) throws -> CaptureResult {
        guard let screenshot = try read(file: file, exitStatus: exitStatus) else { return .cancelled }
        try screenshot.copy(to: board)
        return .copied(width: screenshot.image.width, height: screenshot.image.height)
    }

    public static func read(file: URL, exitStatus: Int32) throws -> Screenshot? {
        guard FileManager.default.fileExists(atPath: file.path) else {
            if exitStatus == 0 || exitStatus == 1 { return nil }
            throw CaptureError.processFailed
        }
        guard exitStatus == 0 else { throw CaptureError.processFailed }
        let png = try Data(contentsOf: file)
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
              cgImage.width > 0, cgImage.height > 0
        else { throw CaptureError.invalidImage }
        return Screenshot(image: cgImage)
    }
}
