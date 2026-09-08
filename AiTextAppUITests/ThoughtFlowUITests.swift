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
        XCTAssertFalse(post.exists, "空文字では投稿ボタンを表示しない")
        composer.tap()
        composer.typeText(body)
        XCTAssertTrue(post.waitForExistence(timeout: 2))
        XCTAssertTrue(post.isEnabled)
        post.tap()

        XCTAssertEqual(composer.value as? String, "", "投稿後にComposerが空になる")
        XCTAssertFalse(post.exists, "投稿後は投稿ボタンを再び隠す")
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

    func testHistoryReviewShowsTodayOldestFirstAndOpensDetail() {
        let composer = app.textViews["thoughtComposer"]
        let post = app.buttons["postButton"]
        let oldest = "Review first"
        let newest = "Review second"
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        for body in [oldest, newest] {
            composer.tap()
            composer.typeText(body)
            post.tap()
        }

        let review = app.buttons["historyReviewButton"]
        XCTAssertTrue(review.waitForExistence(timeout: 2))
        review.tap()
        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["historyReviewCount"].label, "2 Thoughts")

        let oldestText = app.staticTexts[oldest]
        let newestText = app.staticTexts[newest]
        XCTAssertTrue(oldestText.waitForExistence(timeout: 2))
        XCTAssertTrue(newestText.waitForExistence(timeout: 2))
        XCTAssertLessThan(oldestText.frame.minY, newestText.frame.minY, "Reviewは古いThoughtから表示する")

        let reviewThoughts = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "historyReviewThought_")
        )
        XCTAssertEqual(reviewThoughts.count, 2)
        reviewThoughts.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["writeContinuationButton"].waitForExistence(timeout: 2))
        app.navigationBars["Thought"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))
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
