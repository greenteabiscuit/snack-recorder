import XCTest

final class SnackRecorderUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(seed: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + (seed ? ["--seed-data"] : []) + extra
        app.launch()
        if !app.buttons["unlock"].waitForExistence(timeout: 10) { print(app.debugDescription) }
        XCTAssertTrue(app.buttons["unlock"].exists)
        app.buttons["unlock"].tap()
        if !extra.contains("--authentication-fails") { XCTAssertTrue(app.buttons["day-add"].waitForExistence(timeout: 10)) }
        return app
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        if let value = field.value as? String, !value.isEmpty, value != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
    }

    @MainActor func testCreateEditDeleteAndPersist() {
        let app = launch()
        app.buttons["day-add"].tap()
        XCTAssertFalse(app.buttons["save-snack"].isEnabled)
        app.textFields["snack-name"].tap(); app.textFields["snack-name"].typeText("Rice crackers")
        app.textFields["snack-maker"].tap(); app.textFields["snack-maker"].typeText("Market")
        app.buttons["add-other"].tap()
        app.textFields["other-snack-0"].tap(); app.textFields["other-snack-0"].typeText("Tea")
        app.buttons["save-snack"].tap()
        XCTAssertTrue(app.buttons["edit-2026-10-31-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Other: Tea"].exists)
        capture(app, name: "Daily logging")
        app.buttons["edit-2026-10-31-0"].tap()
        replace(app.textFields["snack-name"], with: "Cookie")
        app.buttons["save-snack"].tap()
        XCTAssertTrue(app.staticTexts["Cookie"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-data" }
        app.launch(); app.buttons["unlock"].tap()
        XCTAssertTrue(app.staticTexts["Cookie"].waitForExistence(timeout: 5))
        app.buttons["delete-2026-10-31-0"].tap()
        XCTAssertTrue(app.staticTexts["No snacks recorded for this day."].waitForExistence(timeout: 5))
    }

    @MainActor func testMonthlyEmptyDaysFixedDateAddAndSummary() {
        let app = launch(seed: true)
        app.tabBars.buttons["Month"].tap()
        XCTAssertTrue(app.staticTexts["month-summary"].label.contains("3 snack events · 2 snack days"))
        app.buttons["month-add-2026-10-01"].tap()
        XCTAssertEqual(app.staticTexts["fixed-entry-date"].label, "2026-10-01")
        XCTAssertFalse(app.datePickers["entry-date"].exists)
        app.textFields["snack-name"].tap(); app.textFields["snack-name"].typeText("Banana")
        app.buttons["save-snack"].tap()
        XCTAssertTrue(app.buttons["edit-2026-10-01-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit-2026-10-01-0"].label.contains("Banana"))
        XCTAssertTrue(app.staticTexts["month-summary"].label.contains("4 snack events · 3 snack days"))
        capture(app, name: "Monthly records")
        app.buttons["month-add"].tap()
        XCTAssertTrue(app.datePickers["entry-date"].exists)
        app.buttons["cancel-snack"].tap()
    }

    @MainActor func testCalendarCountsMonthYearControlsAndSelection() {
        let app = launch(seed: true)
        app.buttons["show-calendar"].tap()
        XCTAssertTrue(app.buttons["calendar-day-2026-10-31"].label.contains("2 snacks"))
        capture(app, name: "Calendar counts")
        app.buttons["Next month"].tap()
        XCTAssertEqual(app.staticTexts["visible-month"].label, "November 2026")
        app.buttons["Previous year"].tap()
        XCTAssertEqual(app.staticTexts["visible-month"].label, "November 2025")
        app.buttons["Next year"].tap()
        app.buttons["month-picker"].tap(); app.buttons["February"].tap()
        XCTAssertEqual(app.staticTexts["visible-month"].label, "February 2026")
        app.buttons["year-picker"].tap(); app.buttons["2024"].tap()
        XCTAssertTrue(app.buttons["calendar-day-2024-02-29"].exists)
        app.buttons["calendar-day-2024-02-29"].tap()
        XCTAssertEqual(app.staticTexts["selected-day"].label, "2024-02-29")
        app.buttons["go-today"].tap()
        XCTAssertEqual(app.staticTexts["selected-day"].label, "2026-10-31")
    }

    @MainActor func testSearchAcrossNamesMakersOtherSnacksAndDatesAndEdit() {
        let app = launch(seed: true)
        app.tabBars.buttons["Search"].tap()
        let field = app.textFields["search-field"]
        field.tap(); field.typeText("CHIPS")
        XCTAssertTrue(app.buttons["edit-2026-10-30-0"].waitForExistence(timeout: 5))
        replace(field, with: "Tea House")
        XCTAssertTrue(app.buttons["edit-2026-10-31-0"].exists)
        replace(field, with: "2025-12-31")
        app.buttons["edit-2025-12-31-0"].tap()
        replace(app.textFields["snack-name"], with: "Brownie")
        app.buttons["save-snack"].tap()
        XCTAssertTrue(app.staticTexts["Brownie"].waitForExistence(timeout: 5))
        replace(field, with: "no-such-snack")
        XCTAssertTrue(app.staticTexts["No matching snack events."].exists)
    }

    @MainActor func testRankingsAndAutocomplete() {
        let app = launch(seed: true)
        app.tabBars.buttons["Rankings"].tap()
        app.buttons["all-time-rankings"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "3 times")).firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "All-time rankings")
        app.swipeUp()
        app.buttons["yearly-rankings"].tap()
        XCTAssertTrue(app.staticTexts["Most eaten snack names in 2026"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Day"].tap()
        app.buttons["day-add"].tap()
        app.textFields["snack-name"].tap(); app.textFields["snack-name"].typeText("c")
        XCTAssertTrue(app.buttons["suggestion-Cookie"].waitForExistence(timeout: 5))
        app.buttons["suggestion-Cookie"].tap()
        XCTAssertEqual(app.textFields["snack-name"].value as? String, "Cookie")
        app.buttons["cancel-snack"].tap()
    }

    @MainActor func testSwipeNavigationTodayAndBackgroundLock() {
        let app = launch(seed: true)
        app.collectionViews["day-content"].swipeLeft()
        XCTAssertEqual(app.staticTexts["selected-day"].label, "2026-11-01")
        app.tabBars.buttons["Month"].tap()
        app.collectionViews["month-content"].swipeLeft()
        XCTAssertEqual(app.staticTexts["visible-month"].label, "December 2026")
        app.buttons["go-today"].tap()
        XCTAssertEqual(app.staticTexts["visible-month"].label, "October 2026")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["month-add"].exists)
        app.buttons["unlock"].tap()
        XCTAssertTrue(app.buttons["month-add"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["visible-month"].label, "October 2026")
    }

    @MainActor func testAuthenticationFailureKeepsRecordsHidden() {
        let app = launch(seed: true, extra: ["--authentication-fails"])
        XCTAssertTrue(app.staticTexts["Authentication was cancelled. Your records remain locked."].exists)
        XCTAssertFalse(app.buttons["day-add"].exists)
        XCTAssertFalse(app.staticTexts["Cookie"].exists)
    }

    @MainActor func testImportPreviewMergeAndRepeat() {
        let app = launch(extra: ["--preview-test-import"])
        app.buttons["files-menu"].tap(); app.buttons["import-records"].tap()
        XCTAssertTrue(app.staticTexts["import-counts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["import-counts"].label.contains("2 new events"))
        capture(app, name: "Android import preview")
        app.buttons["confirm-import"].tap()
        XCTAssertTrue(app.staticTexts["import-success"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["files-menu"].tap(); app.buttons["import-records"].tap()
        XCTAssertTrue(app.staticTexts["import-counts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["import-counts"].label.contains("0 new events · 2 existing events skipped"))
        XCTAssertFalse(app.buttons["confirm-import"].isEnabled)
        app.buttons["Close"].tap()
    }
    @MainActor func testSystemCSVExporterOpensAndDismisses() {
        let app = launch(seed: true)
        app.buttons["files-menu"].tap(); app.buttons["export-csv"].tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        XCTAssertEqual(filename.value as? String, "snack-recorder")
        capture(app, name: "System CSV exporter")
        // The iOS 26 exporter is a dismissible sheet, with no visible Cancel button.
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        top.press(forDuration: 0.1, thenDragTo: bottom)
        XCTAssertTrue(filename.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["day-add"].isHittable)
    }

    @MainActor func testBackgroundDismissesEditorAndRelocks() {
        let app = launch()
        app.buttons["day-add"].tap()
        app.textFields["snack-name"].tap(); app.textFields["snack-name"].typeText("Unsaved snack")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["snack-name"].exists)
        app.buttons["unlock"].tap()
        XCTAssertTrue(app.staticTexts["No snacks recorded for this day."].waitForExistence(timeout: 5))
    }

}
