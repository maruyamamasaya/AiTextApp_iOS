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

    func testReviewSummaryHistoryKeepsRegeneratedResultsNewestFirst() {
        let composer = app.textViews["thoughtComposer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("AI summary history")
        app.buttons["postButton"].tap()
        app.buttons["historyReviewButton"].tap()
        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))

        createReviewSummary()
        XCTAssertTrue(app.buttons["reviewAISummaryHistoryButton"].waitForExistence(timeout: 2))
        createReviewSummary()

        let historyButton = app.buttons["reviewAISummaryHistoryButton"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 2))
        XCTAssertEqual(historyButton.label, "履歴 2件")
        historyButton.tap()

        XCTAssertTrue(app.navigationBars["AI要約履歴"].waitForExistence(timeout: 2))
        let items = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "reviewAISummaryHistoryItem_")
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(app.staticTexts["reviewAISummaryLatest"].count, 1)

        let exportMenus = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "exportReviewSummary_")
        )
        XCTAssertEqual(exportMenus.count, 2)
        exportMenus.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Markdownを共有"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["JSONを共有"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()

        let deleteButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "deleteReviewSummary_")
        )
        deleteButtons.element(boundBy: 0).tap()
        let deletionAlert = app.alerts["AI要約を削除しますか？"]
        XCTAssertTrue(deletionAlert.waitForExistence(timeout: 2))
        deletionAlert.buttons["キャンセル"].tap()
        XCTAssertEqual(deleteButtons.count, 2, "キャンセル時は何も削除しない")

        deleteButtons.element(boundBy: 0).tap()
        XCTAssertTrue(deletionAlert.waitForExistence(timeout: 2))
        deletionAlert.buttons["削除"].tap()
        XCTAssertEqual(deleteButtons.count, 1)
        XCTAssertEqual(app.staticTexts["reviewAISummaryLatest"].count, 1, "残った最新要約へ表示を切り替える")

        deleteButtons.element(boundBy: 0).tap()
        XCTAssertTrue(deletionAlert.waitForExistence(timeout: 2))
        deletionAlert.buttons["削除"].tap()
        XCTAssertTrue(app.staticTexts["AI要約履歴はありません"].waitForExistence(timeout: 2))
    }

    func testReviewSummaryPreviewShowsCurrentThoughtAndCanCancelWithoutGenerating() {
        let composer = app.textViews["thoughtComposer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Preview only Thought")
        app.buttons["postButton"].tap()
        app.buttons["historyReviewButton"].tap()
        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))

        app.buttons["reviewAISummaryButton"].tap()
        XCTAssertTrue(app.navigationBars["AI要約プレビュー"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Preview only Thought"].exists)
        XCTAssertTrue(app.otherElements["reviewSummaryPreviewMetadata"].exists)
        XCTAssertTrue(app.buttons["confirmReviewSummarySubmission"].exists)
        app.buttons["cancelReviewSummarySubmission"].tap()

        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["reviewAISummaryHistoryButton"].waitForExistence(timeout: 1))
    }

    private func createReviewSummary() {
        let summaryButton = app.buttons["reviewAISummaryButton"]
        XCTAssertTrue(summaryButton.waitForExistence(timeout: 2))
        summaryButton.tap()
        XCTAssertTrue(app.navigationBars["AI要約プレビュー"].waitForExistence(timeout: 2))
        let confirm = app.buttons["confirmReviewSummarySubmission"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()
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
