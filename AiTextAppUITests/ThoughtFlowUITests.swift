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
        XCTAssertEqual(app.staticTexts["historyReviewActiveDays"].label, "1日")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "historyReviewDayCount_")).firstMatch.label, "2 Thoughts")

        let reviewThoughts = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "historyReviewThought_")
        )
        XCTAssertEqual(reviewThoughts.count, 2)
        reviewThoughts.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["writeContinuationButton"].waitForExistence(timeout: 2))
        app.navigationBars["Thought"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))
    }

    func testTimelineOpensLocalAnalyticsAndShowsSummary() {
        let composer = app.textViews["thoughtComposer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("分析対象Thought")
        app.buttons["postButton"].tap()

        let analyticsButton = app.buttons["thoughtAnalyticsButton"]
        XCTAssertTrue(analyticsButton.waitForExistence(timeout: 2))
        analyticsButton.tap()

        XCTAssertTrue(app.navigationBars["ローカル分析"].waitForExistence(timeout: 2))
        let elements = app.descendants(matching: .any)
        XCTAssertEqual(elements["analyticsTodayCount"].label, "今日、1件")
        XCTAssertEqual(elements["analyticsSevenDayCount"].label, "過去7日、1件")
        XCTAssertEqual(elements["analyticsThirtyDayCount"].label, "過去30日、1件")
        XCTAssertEqual(elements["analyticsActiveDayCount"].label, "過去30日の活動日、1日")
        XCTAssertEqual(elements["analyticsAveragePerActiveDay"].label, "1活動日あたり平均、1.0件")
    }

    func testQuickCapturePostsTrimmedThoughtOnceAndReturnsToTimeline() {
        let quickCapture = app.buttons["quickCaptureButton"]
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))
        quickCapture.tap()

        XCTAssertTrue(app.navigationBars["Quick Capture"].waitForExistence(timeout: 2))
        let editor = app.textViews["quickCaptureEditor"]
        let post = app.buttons["quickCapturePostButton"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        XCTAssertEqual(editor.value as? String, "")
        XCTAssertFalse(post.isEnabled)
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 2), "表示時に入力へfocusする")

        editor.typeText("  Quick Capture Thought  ")
        XCTAssertTrue(post.isEnabled)
        post.tap()

        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["Quick Capture Thought"].count, 1)
    }

    func testExternalQuickCaptureRouteFromColdLaunchPostsOnceAndReturnsToTimeline() {
        app.terminate()
        app.open(URL(string: "aitextapp://quick-capture")!)

        XCTAssertTrue(app.navigationBars["Quick Capture"].waitForExistence(timeout: 5))
        let editor = app.textViews["quickCaptureEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 2), "外部routeでも入力へfocusする")
        editor.typeText("Widget route Thought")
        app.buttons["quickCapturePostButton"].tap()

        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["Widget route Thought"].count, 1)
        XCTAssertFalse(app.navigationBars["Quick Capture"].exists, "投稿後にrouteを消費してTimelineへ戻る")
    }

    func testExternalQuickCaptureRouteWhileForegroundCanBeDismissedAndConsumed() {
        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Quick Capture"].exists, "通常起動ではQuick Captureを開かない")

        app.open(URL(string: "aitextapp://quick-capture")!)
        XCTAssertTrue(app.navigationBars["Quick Capture"].waitForExistence(timeout: 2))
        app.buttons["quickCaptureCancelButton"].tap()

        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars["Quick Capture"].exists)
    }

    func testMalformedExternalRouteDoesNotOpenQuickCapture() {
        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 5))

        app.open(URL(string: "aitextapp://quick-capture?body=should-not-be-accepted")!)

        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars["Quick Capture"].exists)
    }

    func testQuickCaptureRejectsEmptyAndOverLimitDraft() {
        app.buttons["quickCaptureButton"].tap()
        let editor = app.textViews["quickCaptureEditor"]
        let post = app.buttons["quickCapturePostButton"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("   ")
        XCTAssertFalse(post.isEnabled, "空白だけのThoughtは投稿できない")
        app.buttons["quickCaptureCancelButton"].tap()
        app.alerts["入力中のThoughtを破棄しますか？"].buttons["破棄"].tap()
        app.buttons["quickCaptureButton"].tap()
        let reopenedEditor = app.textViews["quickCaptureEditor"]
        let reopenedPost = app.buttons["quickCapturePostButton"]
        XCTAssertTrue(reopenedEditor.waitForExistence(timeout: 2))
        reopenedEditor.typeText(String(repeating: "あ", count: 141))
        XCTAssertEqual(app.staticTexts["quickCaptureCharacterCount"].label, "文字数 141、上限 140")
        XCTAssertFalse(reopenedPost.isEnabled, "141文字を超えるThoughtは投稿できない")
    }

    func testQuickCapturePostsExactly140Characters() {
        let body = String(repeating: "a", count: 140)
        app.buttons["quickCaptureButton"].tap()
        let editor = app.textViews["quickCaptureEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText(body)
        XCTAssertEqual(app.staticTexts["quickCaptureCharacterCount"].label, "文字数 140、上限 140")
        XCTAssertTrue(app.buttons["quickCapturePostButton"].isEnabled)
        app.buttons["quickCapturePostButton"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timelineThought_")).count, 1)
    }

    func testQuickCaptureConfirmsDiscardAndKeepsDraftWhenContinuing() {
        app.buttons["quickCaptureButton"].tap()
        let editor = app.textViews["quickCaptureEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("破棄確認する入力")
        app.buttons["quickCaptureCancelButton"].tap()

        let alert = app.alerts["入力中のThoughtを破棄しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["続ける"].tap()
        XCTAssertEqual(editor.value as? String, "破棄確認する入力")

        app.buttons["quickCaptureCancelButton"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["破棄"].tap()
        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["破棄確認する入力"].exists)
    }

    func testQuickCaptureCancelWithEmptyDraftClosesImmediately() {
        app.buttons["quickCaptureButton"].tap()
        XCTAssertTrue(app.navigationBars["Quick Capture"].waitForExistence(timeout: 2))
        app.buttons["quickCaptureCancelButton"].tap()
        XCTAssertTrue(app.navigationBars["Thoughts"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.alerts["入力中のThoughtを破棄しますか？"].exists)
    }

    func testQuickCaptureFailureKeepsDraftAndScreenOpen() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing-fail-posts"]
        app.launch()
        app.buttons["quickCaptureButton"].tap()
        let editor = app.textViews["quickCaptureEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("失敗しても保持")
        app.buttons["quickCapturePostButton"].tap()

        let alert = app.alerts["投稿できませんでした"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.navigationBars["Quick Capture"].exists)
        XCTAssertEqual(editor.value as? String, "失敗しても保持")
    }

    func testHistoryReviewFiltersCurrentMonthByTagAndOpensDetail() {
        let taggedBody = "今月の仕事Thought"
        let otherBody = "今月の個人Thought"
        let tagName = "仕事"
        let composer = app.textViews["thoughtComposer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText(taggedBody)
        app.buttons["postButton"].tap()
        app.staticTexts[taggedBody].tap()
        app.buttons["editThoughtTagsButton"].tap()
        let tagField = app.textFields["newThoughtTagField"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 2))
        tagField.tap()
        tagField.typeText(tagName)
        app.buttons["addThoughtTagButton"].tap()
        app.buttons["closeThoughtTagEditor"].tap()
        app.navigationBars["Thought"].buttons.element(boundBy: 0).tap()

        composer.tap()
        composer.typeText(otherBody)
        app.buttons["postButton"].tap()
        app.buttons["historyReviewButton"].tap()
        XCTAssertTrue(app.navigationBars["History Review"].waitForExistence(timeout: 2))

        app.buttons["historyReviewFilter"].tap()
        app.buttons["今月"].tap()
        app.buttons["historyReviewTagFilter"].tap()
        app.buttons[tagName].tap()

        XCTAssertEqual(app.staticTexts["historyReviewCount"].label, "1 Thoughts")
        XCTAssertEqual(app.staticTexts["historyReviewTagStatus"].label, tagName)
        XCTAssertTrue(app.staticTexts[taggedBody].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts[otherBody].exists)
        XCTAssertTrue(app.staticTexts["historyReviewAIScopeNotice"].exists)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "historyReviewThought_")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Thought"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[taggedBody].exists)
    }

    func testSearchOpensResultAndNavigatesToThoughtDetail() {
        let composer = app.textViews["thoughtComposer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        for body in ["検索対象のThought", "別のメモ"] {
            composer.tap()
            composer.typeText(body)
            app.buttons["postButton"].tap()
        }

        app.buttons["thoughtSearchButton"].tap()
        XCTAssertTrue(app.navigationBars["Thought検索"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["thoughtSearchInitialState"].exists)

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("検索対象")

        let results = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "searchResult_")
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(app.staticTexts["検索対象のThought"].exists)
        XCTAssertFalse(app.staticTexts["別のメモ"].exists)
        results.element(boundBy: 0).tap()

        XCTAssertTrue(app.navigationBars["Thought"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["writeContinuationButton"].exists)
    }

    func testAddsTagShowsItOnTimelineAndOpensTaggedThoughtDetail() {
        let body = "タグUIフロー"
        let tagName = "仕事"
        let composer = app.textViews["thoughtComposer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText(body)
        app.buttons["postButton"].tap()

        app.staticTexts[body].tap()
        XCTAssertTrue(app.buttons["editThoughtTagsButton"].waitForExistence(timeout: 2))
        app.buttons["editThoughtTagsButton"].tap()
        let tagField = app.textFields["newThoughtTagField"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 2))
        tagField.tap()
        tagField.typeText(tagName)
        app.buttons["addThoughtTagButton"].tap()
        XCTAssertTrue(app.staticTexts[tagName].waitForExistence(timeout: 2))
        app.buttons["closeThoughtTagEditor"].tap()

        app.navigationBars["Thought"].buttons.element(boundBy: 0).tap()
        let tagButton = app.buttons.matching(NSPredicate(format: "label == %@", "タグ \(tagName)")).firstMatch
        XCTAssertTrue(tagButton.waitForExistence(timeout: 2), "Timelineにタグが表示される")
        tagButton.tap()

        XCTAssertTrue(app.navigationBars[tagName].waitForExistence(timeout: 2))
        let taggedThought = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "taggedThought_")
        ).firstMatch
        XCTAssertTrue(taggedThought.waitForExistence(timeout: 2))
        taggedThought.tap()
        XCTAssertTrue(app.navigationBars["Thought"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[body].exists)
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
