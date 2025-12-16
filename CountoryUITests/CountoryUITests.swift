import XCTest

final class CountoryUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests to run. The desired UIs are sometimes broken into smaller functional areas.
        // Use the strategy to pass the test from other files, setting the initial state of the UI when your test methods are called.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppLaunchesAndDisplaysMainScreen() throws {
        let app = XCUIApplication()
        app.launch()

        // Assert that the navigation title "Countory" exists
        XCTAssertTrue(app.navigationBars["Countory"].exists)

        // Assert that the "Add Item" button exists
        XCTAssertTrue(app.buttons["Add Item"].exists)
    }

    // You can add more UI tests here, for example:
    // func testAddItem() throws {
    //     let app = XCUIApplication()
    //     app.launch()
    //
    //     app.buttons["Add Item"].tap()
    //     app.textFields["Item Name"].tap()
    //     app.textFields["Item Name"].typeText("New Test Item")
    //     app.steppers["Quantity: 1"].buttons["Increment"].tap() // Tap increment
    //     app.buttons["Save"].tap()
    //
    //     // Assert that the new item appears in the list
    //     XCTAssertTrue(app.staticTexts["New Test Item"].exists)
    // }
}
