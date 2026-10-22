import XCTest
import CoreGraphics
@testable import PanoCore

final class ShortcutDescriptionTests: XCTestCase {
    private let table: [[String: Any]] = [["elements": [
        ["name": "DO_NOT_LOCALIZE: Spotlight", "sybmolichotkey": 64, "key": 49, "modifier": 1048576],
        ["name": "DO_NOT_LOCALIZE: Screenshot", "sybmolichotkey": 30, "key": 21, "modifier": 1179648]
    ]]]

    func testCustomSystemAssignmentKeepsItsRealPurposeInsteadOfGuessingFromKeys() {
        let newKey = KeyboardShortcut(keyCode: 8, flags: [.maskControl, .maskAlternate])
        let oldKey = KeyboardShortcut(keyCode: 49, flags: .maskCommand)
        let overrides: [String: Any] = ["64": ["enabled": true, "value": ["type": "standard", "parameters": [99, 8, 786432]]]]
        XCTAssertEqual(SystemShortcutCatalog.names(for: newKey, table: table, localizations: ["Spotlight": "Show Spotlight search"],
            overrides: overrides, enabled: [newKey, oldKey]), ["Show Spotlight search"])
        XCTAssertEqual(SystemShortcutCatalog.names(for: oldKey, table: table, localizations: [:],
            overrides: overrides, enabled: [newKey, oldKey]), [])
    }

    func testDisabledOrUnassignedShortcutsDoNotClaimToBeActive() {
        let key = KeyboardShortcut.defaultShortcut
        XCTAssertEqual(SystemShortcutCatalog.names(for: key, table: table, localizations: [:],
            overrides: ["30": ["enabled": false]], enabled: [key]), [])
        XCTAssertEqual(SystemShortcutCatalog.names(for: key, table: table, localizations: [:],
            overrides: [:], enabled: []), [])
    }

    func testDescriptionCollapsesDuplicateAppsAndExplainsCommand() {
        let description = ShortcutUsage.description(standard: "Copy", systemNames: [],
            appCommands: ["Copy (Finder)", "Copy (Notes)"], systemMatch: false)
        XCTAssertTrue(description.contains("clipboard"))
        XCTAssertFalse(description.contains("Finder"))
        XCTAssertFalse(description.contains("\n"))
        XCTAssertNotEqual(description, ShortcutUsage.description(standard: "Paste", systemNames: [], appCommands: [], systemMatch: false))
    }

    func testUnknownSystemAndAppCommandsNeverGetAnInventedPurpose() {
        XCTAssertTrue(ShortcutUsage.description(standard: nil, systemNames: [], appCommands: [], systemMatch: true).contains("could not identify"))
        XCTAssertTrue(ShortcutUsage.description(standard: nil, systemNames: [], appCommands: ["Export Layers (Editor)"], systemMatch: false).contains("Export Layers"))
    }
    func testDisabledDefaultDoesNotBorrowAnotherActionsLiveAssignment() {
        let key = KeyboardShortcut(keyCode: 28, flags: [.maskControl, .maskAlternate, .maskCommand])
        let nodes: [[String: Any]] = [
            ["name": "Invert colors", "sybmolichotkey": 21, "key": 28, "modifier": 1835008, "enabled": false],
            ["name": "Spotlight", "sybmolichotkey": 64, "key": 49, "modifier": 1048576]
        ]
        let custom: [String: Any] = ["64": ["enabled": true, "value": ["type": "standard", "parameters": [56, 28, 1835008]]]]
        XCTAssertEqual(SystemShortcutCatalog.names(for: key, table: nodes, localizations: [:], overrides: custom, enabled: [key]), ["Spotlight"])
    }

    func testFnNavigationAssignmentIsExplainedAsConditional() {
        let key = KeyboardShortcut(keyCode: 126, flags: .maskControl)
        let nodes: [[String: Any]] = [
            ["name": "Mission Control", "sybmolichotkey": 32, "key": 126, "modifier": 262144],
            ["name": "Tile Top Half", "sybmolichotkey": 242, "key": 126, "modifier": 8650752]
        ]
        let names = SystemShortcutCatalog.names(for: key, table: nodes, localizations: [:], overrides: [:], enabled: [key])
        XCTAssertEqual(names, ["Mission Control", "Tile Top Half (with Fn)"])
        let description = ShortcutUsage.description(standard: nil, systemNames: names, appCommands: [], systemMatch: true)
        XCTAssertTrue(description.contains("With Fn held"))
        XCTAssertTrue(description.contains("top half of the desktop"))
    }

    func testDifferentAppPurposeIsNotHiddenByCommonCommand() {
        let text = ShortcutUsage.description(standard: "Copy", systemNames: [], appCommands: ["Copy (Finder)", "Export Layers (Editor)"], systemMatch: false)
        XCTAssertTrue(text.contains("clipboard"))
        XCTAssertTrue(text.contains("Export Layers"))
        XCTAssertFalse(text.contains("Finder"))
    }

    func testWindowActionsExplainMeaningInsteadOfRepeatingLabel() {
        let text = ShortcutUsage.description(standard: nil, systemNames: ["Fill", "Center", "Arrange Left and Right"], appCommands: [], systemMatch: true)
        XCTAssertTrue(text.contains("fill the available desktop area"))
        XCTAssertTrue(text.contains("center of the desktop"))
        XCTAssertTrue(text.contains("side by side"))
        XCTAssertFalse(text.contains("Runs the macOS"))
    }

}
