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
        guard FileManager.default.fileExists(atPath: file.path) else {
            if exitStatus == 0 || exitStatus == 1 { return .cancelled }
            throw CaptureError.processFailed
        }
        guard exitStatus == 0 else { throw CaptureError.processFailed }
        let png = try Data(contentsOf: file)
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
              cgImage.width > 0, cgImage.height > 0,
              let tiff = NSBitmapImageRep(cgImage: cgImage).representation(using: .tiff, properties: [:])
        else { throw CaptureError.invalidImage }
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setData(tiff, forType: .tiff)
        board.clearContents()
        guard board.writeObjects([item]) else { throw CaptureError.clipboardUnavailable }
        return .copied(width: cgImage.width, height: cgImage.height)
    }
}
