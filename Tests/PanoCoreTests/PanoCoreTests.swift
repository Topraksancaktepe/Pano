import XCTest
import AppKit
import CoreGraphics
@testable import PanoCore

final class PanoCoreTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }
    func makePNG() throws -> URL {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 12, bitsPerPixel: 32)!
        bitmap.setColor(NSColor(deviceRed: 0.1, green: 0.5, blue: 0.3, alpha: 1), atX: 1, y: 1)
        let url = directory.appendingPathComponent("capture.png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }
    func testCancelledCapturePreservesClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("keep this", forType: .string)
        let result = try CaptureOutput.copy(file: directory.appendingPathComponent("missing.png"),
                                          exitStatus: 1, to: board)
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(board.string(forType: .string), "keep this")
    }
    func testValidCapturePutsAnActualImageWithOriginalDimensionsOnClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let result = try CaptureOutput.copy(file: makePNG(), exitStatus: 0, to: board)
        XCTAssertEqual(result, .copied(width: 3, height: 2))
        let png = try XCTUnwrap(board.data(forType: .png))
        let image = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(image.pixelsWide, 3)
        XCTAssertEqual(image.pixelsHigh, 2)
        XCTAssertNotNil(board.data(forType: .tiff))
        XCTAssertTrue(board.canReadObject(forClasses: [NSImage.self], options: nil))
    }
    func testCorruptImageDoesNotClearClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("keep this", forType: .string)
        let url = directory.appendingPathComponent("corrupt.png")
        try Data("not an image".utf8).write(to: url)
        XCTAssertThrowsError(try CaptureOutput.copy(file: url, exitStatus: 0, to: board))
        XCTAssertEqual(board.string(forType: .string), "keep this")
    }
    func testFailedProcessNeverCopiesPartialOutput() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("keep this", forType: .string)
        XCTAssertThrowsError(try CaptureOutput.copy(file: makePNG(), exitStatus: 2, to: board))
        XCTAssertEqual(board.string(forType: .string), "keep this")
    }
    func testShortcutConsumesRepeatAndKeyUpButTriggersOnlyOnce() {
        var filter = ShortcutFilter()
        XCTAssertEqual(filter.handle(keyCode: 21, down: true, flags: [.maskCommand, .maskShift],
                                     isRepeat: false, enabled: true), .trigger)
        XCTAssertEqual(filter.handle(keyCode: 21, down: true, flags: [.maskCommand, .maskShift],
                                     isRepeat: true, enabled: true), .suppress)
        XCTAssertEqual(filter.handle(keyCode: 21, down: false, flags: [],
                                     isRepeat: false, enabled: false), .suppress)
        XCTAssertEqual(filter.handle(keyCode: 21, down: false, flags: [],
                                     isRepeat: false, enabled: true), .pass)
    }
    func testOtherShortcutsAndUnreadyStateKeepNativeBehavior() {
        let cases: [(Int64, CGEventFlags, Bool)] = [
            (21, [.maskCommand, .maskShift], false),
            (21, [.maskCommand, .maskShift, .maskControl], true),
            (21, [.maskCommand, .maskShift, .maskAlternate], true),
            (20, [.maskCommand, .maskShift], true), (21, [.maskCommand], true)
        ]
        for (code, flags, enabled) in cases {
            var filter = ShortcutFilter()
            XCTAssertEqual(filter.handle(keyCode: code, down: true, flags: flags,
                                         isRepeat: false, enabled: enabled), .pass)
        }
    }
}
