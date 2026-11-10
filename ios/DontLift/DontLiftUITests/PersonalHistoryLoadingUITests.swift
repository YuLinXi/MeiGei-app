import XCTest

final class PersonalHistoryLoadingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSlowHomeCanOpenCalendarWithoutExtraHistoryReads() throws {
        let app = launch(flags: ["-uitest-history-slow"])
        expectReads(1, in: app)
        XCTAssertFalse(app.staticTexts["本周还没有训练记录"].exists)
        capture("个人历史慢读时的首页中性状态", in: app)
        let calendar = app.buttons["历史日历"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 5), "历史尚未读完时仍可进入日历")
        calendar.tap()
        let summary = app.staticTexts["calendar.month.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("尚未就绪"))
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("尚未就绪"))
        expectReads(1, in: app)
        capture("个人日历未知不显示零且未追加读取", in: app)
        let available = NSPredicate(format: "NOT (label CONTAINS %@)", "尚未就绪")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: available, object: summary)], timeout: 25), .completed)
        expectReads(1, in: app)
    }

    @MainActor func testFirstFailureAndCalendarRetryAtLargestSize() throws {
        let app = launch(size: "accessibility5", flags: ["-uitest-history-first-failure"])
        let retry = app.buttons["home.history.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        expectReads(1, in: app)
        XCTAssertTrue(app.buttons["开始训练"].isHittable)
        app.buttons["历史日历"].tap()
        let calendarRetry = app.buttons["calendar.history.retry"]
        XCTAssertTrue(calendarRetry.waitForExistence(timeout: 5))
        expectReads(1, in: app)
        XCTAssertTrue(app.staticTexts["calendar.month.summary"].label.contains("尚未就绪"))
        reveal(calendarRetry, in: app)
        capture("个人日历首次失败仍可重试：最大字号", in: app)
        calendarRetry.tap()
        expectReads(2, in: app)
        XCTAssertTrue(calendarRetry.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["calendar.month.summary"].label.contains("尚未就绪"))
        app.buttons["返回"].tap()
        XCTAssertFalse(retry.exists)
        expectReads(2, in: app)
    }

    @MainActor func testUnknownMonthPickerDoesNotClaimEmptyHistory() throws {
        let app = launch(flags: ["-uitest-history-slow"])
        app.buttons["历史日历"].tap()
        XCTAssertTrue(app.buttons["选择月份"].waitForExistence(timeout: 5))
        app.buttons["选择月份"].tap()
        let state = app.staticTexts["calendar.archive.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        XCTAssertTrue(state.label.contains("尚未就绪"))
        expectReads(1, in: app)
        capture("月份选择未知状态与实际空历史分开表达", in: app)
    }

    @MainActor func testCachedReadFailureKeepsHomeSummaryAndRetries() throws {
        let app = launch(flags: ["-uitest-history-refresh-failure"])
        let muscle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "本周肌群负荷，共")).firstMatch
        XCTAssertTrue(muscle.waitForExistence(timeout: 10))
        let original = muscle.label
        expectReads(1, in: app)
        app.buttons["开始训练"].tap()
        XCTAssertTrue(app.buttons["收起训练"].waitForExistence(timeout: 5))
        app.buttons["收起训练"].tap()
        let retry = app.buttons["home.history.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 6))
        XCTAssertEqual(muscle.label, original)
        expectReads(2, in: app)
        capture("个人历史刷新失败保留首页快照", in: app)
        retry.tap()
        expectReads(3, in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.history.loading").firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(muscle.label, original)
    }

    @MainActor func testBlankStartDoesNotWaitForSlowHistory() throws {
        let app = launch(flags: ["-uitest-history-slow"])
        expectReads(1, in: app)
        app.buttons["开始训练"].tap()
        XCTAssertTrue(app.buttons["收起训练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["添加动作"].exists)
        app.buttons["收起训练"].tap()
        expectReads(1, in: app)
        XCTAssertFalse(app.staticTexts["本周还没有训练记录"].exists)
        capture("慢历史不阻塞空白开始与返回", in: app)
    }

    @MainActor func testLiveInputDoesNotWaitOrReadHistoryAgain() throws {
        let app = launch(flags: ["-uitest-history-slow", "-uitest-live-workout"])
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        XCTAssertTrue(app.buttons["数字 6"].waitForExistence(timeout: 5))
        for key in ["数字 6", "数字 3", "小数点", "数字 7", "数字 5"] { app.buttons[key].tap() }
        XCTAssertEqual(weight.value as? String, "63.75 公斤")
        app.buttons["收起键盘"].tap()
        app.buttons["收起训练"].tap()
        expectReads(1, in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.history.loading").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.history.loading").firstMatch.waitForNonExistence(timeout: 25))
        expectReads(1, in: app)
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        capsule.tap()
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "63.75 公斤")
        capture("慢读期间完成录入且导航后仍只读取一次历史", in: app)
    }

    @MainActor func testSuccessfulEmptyHistoryUsesConfirmedEmptyState() throws {
        let app = launch(flags: ["-uitest-history-empty"])
        XCTAssertTrue(app.staticTexts["本周还没有训练记录"].waitForExistence(timeout: 5))
        expectReads(1, in: app)
        let calendar = app.buttons["历史日历"]
        reveal(calendar, in: app)
        calendar.tap()
        XCTAssertTrue(app.staticTexts["calendar.month.summary"].label.contains("0 次训练"))
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("没有训练记录"))
        expectReads(1, in: app)
        capture("成功读取空历史后才显示零与空态", in: app)
    }

    @MainActor private func launch(size: String = "large", flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-history-loading",
                               "-dismiss-career-review", "-uitest-typography-size", size] + flags
        if !flags.contains("-uitest-live-workout") {
            app.launchArguments += ["-uitest-history-save", "-clear-active-workout"]
        }
        app.launch()
        let ready = flags.contains("-uitest-live-workout")
            ? app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
            : app.staticTexts["uitest.history.readCount"]
        XCTAssertTrue(waitForIsolatedUITestScene(ready, in: app))
        return app
    }

    @MainActor private func expectReads(_ count: Int, in app: XCUIApplication) {
        let counter = app.staticTexts["uitest.history.readCount"]
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value == %@", String(count))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: counter)], timeout: 5), .completed)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists && element.isHittable && element.frame.minY >= 120 && element.frame.maxY <= app.frame.maxY - 34 { return }
            let down = element.exists && element.frame.minY < 120
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 280 : 550))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 450 : 380))
            from.press(forDuration: 0.01, thenDragTo: to)
        }
        XCTFail("个人历史控件未滚入可用区域")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
