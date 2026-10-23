import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Immutable pixels, retained independently of both the temporary file and pasteboard.
public struct Screenshot {
    public let image: CGImage
    public var size: CGSize { CGSize(width: image.width, height: image.height) }
    public init(image: CGImage) { self.image = image }

    public func pngData() throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw CaptureError.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CaptureError.invalidImage }
        return data as Data
    }

    public func copy(to board: NSPasteboard) throws {
        let png = try pngData()
        guard let tiff = NSBitmapImageRep(cgImage: image).representation(using: .tiff, properties: [:])
        else { throw CaptureError.invalidImage }
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setData(tiff, forType: .tiff)
        board.clearContents()
        guard board.writeObjects([item]) else { throw CaptureError.clipboardUnavailable }
    }
}
