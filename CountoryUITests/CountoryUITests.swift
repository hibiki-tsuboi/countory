import XCTest

final class CountoryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndDisplaysMainScreen() throws {
        // Given / When
        let app = XCUIApplication()
        app.launch()

        // Then
        XCTAssertTrue(app.buttons["addItem"].exists)
        XCTAssertTrue(app.buttons["dataTransfer"].exists)
    }

    func testBackupScreenCanBeOpenedAndDismissed() throws {
        // Given
        let app = XCUIApplication()
        app.launch()

        // When
        app.buttons["dataTransfer"].tap()

        // Then
        XCTAssertTrue(app.navigationBars["データ移行"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportBackup"].exists)
        XCTAssertTrue(app.buttons["selectBackup"].exists)
        XCTAssertFalse(app.buttons["confirmImport"].exists)
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["addItem"].waitForExistence(timeout: 5))
    }

    func testBackupFileCanBeExportedAndImportedWithConfirmation() throws {
        // Given
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let itemName = "Backup test \(UUID().uuidString.prefix(8))"
        app.buttons["addItem"].tap()
        app.textFields["商品"].tap()
        app.textFields["商品"].typeText(itemName)
        app.buttons["saveItem"].tap()
        XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: 5))
        app.buttons["dataTransfer"].tap()
        attachScreenshot(app, name: "データ移行画面")

        // When / Then
        app.buttons["exportBackup"].tap()
        let save = app.buttons.matching(NSPredicate(format: "label IN %@", ["Save", "保存"])).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let filename = try XCTUnwrap(app.textFields.firstMatch.value as? String)
        XCTAssertTrue(filename.hasPrefix("Countory-"))
        save.tap()
        XCTAssertTrue(app.alerts["書き出し完了"].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].tap()
        app.buttons["閉じる"].tap()
        deleteItem(named: itemName, in: app)
        app.buttons["dataTransfer"].tap()
        app.buttons["selectBackup"].tap()
        let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", filename)).firstMatch
        if !file.waitForExistence(timeout: 2) {
            let browse = app.tabBars.buttons
                .matching(NSPredicate(format: "label IN %@", ["Browse", "ブラウズ"])).firstMatch
            XCTAssertTrue(browse.waitForExistence(timeout: 5))
            browse.tap()
            if !file.exists {
                let localStorage = app.staticTexts
                    .matching(NSPredicate(format: "label IN %@", ["On My iPhone", "このiPhone内"])).firstMatch
                XCTAssertTrue(localStorage.waitForExistence(timeout: 5))
                localStorage.tap()
            }
        }
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        file.tap()
        let confirm = app.buttons["confirmImport"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        for _ in 0..<3 where !confirm.isHittable { app.swipeUp() }
        attachScreenshot(app, name: "取り込み内容の確認")
        confirm.tap()
        XCTAssertTrue(app.alerts["取り込み完了"].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(confirm.exists)
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: itemName).count, 1)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: 5))
        deleteItem(named: itemName, in: app)
    }

    private func deleteItem(named name: String, in app: XCUIApplication) {
        app.staticTexts[name].swipeLeft()
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "削除"])).firstMatch.tap()
        XCTAssertFalse(app.staticTexts[name].exists)
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

}
