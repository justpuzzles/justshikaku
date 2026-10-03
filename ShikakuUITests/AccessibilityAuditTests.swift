import XCTest

/// Xcode's automated accessibility audit, one screen at a time
/// (docs/ACCESSIBILITY.md). Every screen is reached the way a VoiceOver user
/// would: by its labels. Audits see only what is on screen, so each test
/// navigates first.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    private lazy var app: XCUIApplication = {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState", "-ShikakuScreenshotUnlock"]
        return app
    }()

    /// Set on screens that are system Lists (see `audit`).
    private var acceptListFalsePositives = false
    /// Set on the new-room sheet (see `audit`).
    private var acceptUnattributedText = false

    private func launch(free: Bool = false) {
        if free { app.launchArguments = ["-uiTestResetState"] }
        app.launch()
    }

    private func audit(_ file: StaticString = #filePath, _ line: UInt = #line) throws {
        try app.performAccessibilityAudit { issue in
            // One line per issue in the test log, so findings can be traced
            // to the element without opening the result bundle.
            print("AUDIT | \(issue.compactDescription) | \(issue.element?.elementType.rawValue ?? 0) | \(issue.element?.label ?? "-") | \(issue.element.map { "\($0.frame)" } ?? "") | \(issue.detailedDescription)")
            // Accepted, documented in docs/ACCESSIBILITY.md.
            // The wordmark and the kanji seals are fixed-size drawings,
            // hidden from VoiceOver (the card text carries the meaning).
            let fixedGlyphs: Set<String> = ["Just", "Shikaku", "Just Shikaku", "学", "段", "今", "済", "週"]
            if issue.auditType == .dynamicType, fixedGlyphs.contains(issue.element?.label ?? "") { return true }
            // System List screens (Settings, Statistics, Learn) are flagged
            // although their rows scale and wrap; checked at AX5 by hand.
            if self.acceptListFalsePositives, [.dynamicType, .textClipped].contains(issue.auditType) { return true }
            // The new-room sheet reports one "potentially inaccessible text"
            // with no element; every visible string there is in the tree.
            if self.acceptUnattributedText, issue.element == nil, issue.auditType == .elementDetection { return true }
            return false
        }
    }

    private func startRoom(_ size: String = "5×5") {
        app.buttons["Lay out a room"].firstMatch.tap()
        app.buttons[size].tap()
        app.buttons["Lay out a room"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["Row 1, column 1"].firstMatch.waitForExistence(timeout: 5)
                      || app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Row 1, column 1'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testHome() throws {
        launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        try audit()
    }

    func testNewRoomSheet() throws {
        launch()
        app.buttons["Lay out a room"].tap()
        XCTAssertTrue(app.buttons["5×5"].waitForExistence(timeout: 5))
        acceptUnattributedText = true
        try audit()
    }

    func testBoard() throws {
        launch()
        startRoom()
        let cells = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Row '"))
        XCTAssertEqual(cells.count, 25, "every cell of a 5×5 board is a VoiceOver element")
        try audit()
    }

    func testHint() throws {
        launch()
        startRoom()
        app.buttons["Hint"].tap()
        XCTAssertTrue(app.buttons["Dismiss hint"].waitForExistence(timeout: 5))
        try audit()
    }

    func testLearnMenu() throws {
        launch()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'New here?'")).firstMatch.tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit()
    }

    func testStatistics() throws {
        launch()
        app.buttons["Statistics"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit()
    }

    func testSettings() throws {
        launch()
        app.buttons["Settings"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit()
    }

    func testPaywall() throws {
        launch(free: true)
        app.buttons["Lay out a room"].tap()
        app.buttons["12×12, locked"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        try audit()
    }

    /// The largest accessibility text size: the audit's Dynamic Type and
    /// clipping checks bite here.
    func testHomeAtLargestTextSize() throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        try audit()
    }
}
