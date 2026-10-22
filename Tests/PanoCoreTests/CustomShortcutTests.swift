import XCTest
import CoreGraphics
@testable import PanoCore

final class CustomShortcutTests: XCTestCase {
    func testCustomCopyShortcutReplacesDefaultAndConsumesReleaseAfterBindingChanges() {
        var filter = ShortcutFilter()
        let copy = KeyboardShortcut(keyCode: 8, flags: .maskCommand)
        XCTAssertEqual(filter.handle(keyCode: 21, down: true, flags: [.maskCommand, .maskShift],
                                     isRepeat: false, enabled: true, shortcut: copy), .pass)
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: .maskCommand,
                                     isRepeat: false, enabled: true, shortcut: copy), .trigger)
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: .maskCommand,
                                     isRepeat: true, enabled: true, shortcut: copy), .suppress)
        XCTAssertEqual(filter.handle(keyCode: 8, down: false, flags: [],
                                     isRepeat: false, enabled: false), .suppress)
    }

    func testRecordingConsumesShortcutsWithoutTriggeringAndDrainsKeyUpAfterStop() {
        var filter = ShortcutFilter()
        XCTAssertEqual(filter.handle(keyCode: 21, down: true, flags: [.maskShift, .maskCommand],
                                     isRepeat: false, enabled: true, recording: true),
                       .record(KeyboardShortcut(keyCode: 21, flags: [.maskShift, .maskCommand])))
        XCTAssertEqual(filter.handle(keyCode: 21, down: false, flags: [],
                                     isRepeat: false, enabled: true), .suppress)
        XCTAssertEqual(filter.handle(keyCode: 9, down: true, flags: [.maskCommand, .maskAlphaShift],
                                     isRepeat: false, enabled: true, recording: true),
                       .record(KeyboardShortcut(keyCode: 9, flags: .maskCommand)))
    }

    func testModifierDifferencesDoNotHijackOtherCommands() {
        var filter = ShortcutFilter()
        let controlC = KeyboardShortcut(keyCode: 8, flags: .maskControl)
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: .maskCommand,
                                     isRepeat: false, enabled: true, shortcut: controlC), .pass)
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: [.maskControl, .maskAlphaShift],
                                     isRepeat: false, enabled: true, shortcut: controlC), .trigger)
    }

    func testRejectedRecordingLeavesSavedShortcutIntactAndAcceptedOneSurvivesRelaunch() throws {
        let name = "PanoTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ShortcutStore(defaults: defaults)
        var draft = ShortcutDraft(current: store.load())
        draft.record(KeyboardShortcut(keyCode: 9, flags: .maskCommand))
        draft.cancel()
        XCTAssertEqual(draft.current, .defaultShortcut)
        XCTAssertEqual(store.load(), .defaultShortcut)
        draft.record(KeyboardShortcut(keyCode: 8, flags: .maskControl))
        try store.save(XCTUnwrap(draft.accept()))
        let restored = ShortcutStore(defaults: UserDefaults(suiteName: name)!).load()
        var filter = ShortcutFilter()
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: .maskControl,
                                     isRepeat: false, enabled: true, shortcut: restored), .trigger)
    }

    func testCorruptSavedShortcutFallsBackAndModifierOnlyCannotBeSaved() {
        let name = "PanoTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("broken".utf8), forKey: "captureShortcut")
        let store = ShortcutStore(defaults: defaults)
        XCTAssertEqual(store.load(), .defaultShortcut)
        XCTAssertThrowsError(try store.save(KeyboardShortcut(keyCode: 55, flags: .maskCommand)))
    }

    func testConflictNamesDistinguishCopyPasteAndControlC() {
        XCTAssertEqual(ShortcutConflict.standard(for: KeyboardShortcut(keyCode: 8, flags: .maskCommand), character: "c")?.task, "Copy")
        XCTAssertEqual(ShortcutConflict.standard(for: KeyboardShortcut(keyCode: 9, flags: .maskCommand), character: "v")?.task, "Paste")
        XCTAssertEqual(ShortcutConflict.standard(for: KeyboardShortcut(keyCode: 8, flags: .maskControl), character: "c")?.task, "Interrupt / Cancel in Terminal")
        XCTAssertNil(ShortcutConflict.standard(for: KeyboardShortcut(keyCode: 8, flags: [.maskControl, .maskCommand, .maskAlternate]), character: "c"))
    }
    func testFnLetterShortcutDoesNotShadowOrdinaryControlLetter() {
        var filter = ShortcutFilter()
        let shortcut = KeyboardShortcut(keyCode: 8, flags: [.maskControl, .maskSecondaryFn])
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: .maskControl,
                                     isRepeat: false, enabled: true, shortcut: shortcut), .pass)
        XCTAssertEqual(filter.handle(keyCode: 8, down: true, flags: [.maskControl, .maskSecondaryFn],
                                     isRepeat: false, enabled: true, shortcut: shortcut), .trigger)
    }

    func testSelectionModeAllowsEscapeAfterShortcutRelease() {
        var filter = ShortcutFilter()
        let escape = KeyboardShortcut(keyCode: 53, flags: [])
        XCTAssertEqual(filter.handle(keyCode: 53, down: true, flags: [], isRepeat: false,
                                     enabled: true, shortcut: escape), .trigger)
        XCTAssertEqual(filter.handle(keyCode: 53, down: false, flags: [], isRepeat: false,
                                     enabled: false, shortcut: escape), .suppress)
        XCTAssertEqual(filter.handle(keyCode: 53, down: true, flags: [], isRepeat: false,
                                     enabled: false, shortcut: escape), .pass)
    }

    func testCharacterOnlyMenuMatchesModifiedPunctuationButNotDifferentModifiers() {
        let shortcut = KeyboardShortcut(keyCode: 44, flags: [.maskCommand, .maskShift])
        XCTAssertTrue(ShortcutConflict.menuMatches(shortcut, virtualKey: nil, character: "?",
            flags: [.maskCommand, .maskShift], candidateCharacters: ["/", "?"]))
        XCTAssertFalse(ShortcutConflict.menuMatches(shortcut, virtualKey: nil, character: "?",
            flags: .maskCommand, candidateCharacters: ["/", "?"]))
        XCTAssertFalse(ShortcutConflict.menuMatches(shortcut, virtualKey: 1, character: "?",
            flags: [.maskCommand, .maskShift], candidateCharacters: ["/", "?"]))
    }

}
