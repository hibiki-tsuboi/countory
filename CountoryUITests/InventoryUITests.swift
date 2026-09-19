import XCTest

final class InventoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testItemEditingCategoryAndSearchPreserveDataAfterRelaunch() throws {
        // Given
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let suffix = String(UUID().uuidString.prefix(8))
        let itemName = "Inventory \(suffix)"
        let categoryName = "Category \(suffix)"
        let notes = "Memo \(suffix)"
        app.buttons["addItem"].tap()
        app.textFields["商品"].tap()
        app.textFields["商品"].typeText(itemName)
        app.buttons["saveItem"].tap()
        XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: 5))

        // When
        app.staticTexts[itemName].tap()
        XCTAssertEqual(app.textFields["商品"].value as? String, itemName)
        app.steppers.firstMatch.buttons["Increment"].tap()
        app.textViews.firstMatch.tap()
        app.textViews.firstMatch.typeText(notes)
        app.buttons["新規カテゴリ"].tap()
        app.alerts.textFields.firstMatch.typeText(categoryName)
        app.alerts.buttons["追加"].tap()
        app.buttons["saveItem"].tap()

        // Then
        XCTAssertTrue(app.staticTexts[notes].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[categoryName].exists)
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText(suffix)
        XCTAssertTrue(app.staticTexts[itemName].exists)
        app.searchFields.firstMatch.typeText("-missing")
        XCTAssertTrue(app.staticTexts["検索結果がありません"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[itemName].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[notes].exists)
        XCTAssertTrue(app.staticTexts[categoryName].exists)
        let row = app.buttons.containing(.staticText, identifier: itemName).firstMatch
        XCTAssertTrue(row.staticTexts["2"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "編集・カテゴリ・再起動後の商品一覧"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.staticTexts[itemName].swipeLeft()
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "削除"])).firstMatch.tap()
        XCTAssertFalse(app.staticTexts[itemName].exists)
        app.terminate()
        app.launch()
        XCTAssertFalse(app.staticTexts[itemName].exists)
    }
}
