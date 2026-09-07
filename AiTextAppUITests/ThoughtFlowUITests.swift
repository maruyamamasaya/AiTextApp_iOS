import XCTest

final class ThoughtFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
    }

    func testPostCancelDeleteThenConfirmDelete() {
        let composer = app.textViews["thoughtComposer"]
        let post = app.buttons["postButton"]
        let body = "UIテスト Thought 🚀"

        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertFalse(post.isEnabled, "空文字では投稿できない")
        composer.tap()
        composer.typeText(body)
        XCTAssertTrue(post.isEnabled)
        post.tap()

        XCTAssertEqual(composer.value as? String, "", "投稿後にComposerが空になる")
        let postedThought = app.staticTexts[body]
        XCTAssertTrue(postedThought.waitForExistence(timeout: 2), "投稿がTimeline先頭に表示される")

        openThoughtMenuAndChooseDelete()
        let cancel = app.buttons["cancelDeleteButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        cancel.tap()
        XCTAssertTrue(postedThought.exists, "キャンセル時はThoughtが残る")

        openThoughtMenuAndChooseDelete()
        let confirm = app.buttons["confirmDeleteButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()
        XCTAssertFalse(postedThought.waitForExistence(timeout: 1), "削除確定後はTimelineから消える")
    }

    func testCreateContinuationAndShowItInHistoryAndTimeline() {
        let composer = app.textViews["thoughtComposer"]
        let parent = "History A"
        let child = "History B"
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText(parent)
        app.buttons["postButton"].tap()

        let parentText = app.staticTexts[parent]
        XCTAssertTrue(parentText.waitForExistence(timeout: 2))
        parentText.tap()
        let writeContinuation = app.buttons["writeContinuationButton"]
        XCTAssertTrue(writeContinuation.waitForExistence(timeout: 2))
        writeContinuation.tap()

        let continuationComposer = app.textViews["continuationComposer"]
        XCTAssertTrue(continuationComposer.waitForExistence(timeout: 2))
        continuationComposer.tap()
        continuationComposer.typeText(child)
        app.buttons["postContinuationButton"].tap()

        XCTAssertTrue(app.staticTexts[parent].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[child].waitForExistence(timeout: 2))
        app.navigationBars["Thought"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts[child].waitForExistence(timeout: 2), "Continuationが通常Timelineにも表示される")
    }

    private func openThoughtMenuAndChooseDelete() {
        let menu = app.buttons.matching(identifier: "thoughtMenu").firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 2))
        menu.tap()
        let delete = app.buttons["削除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        delete.tap()
    }
}
