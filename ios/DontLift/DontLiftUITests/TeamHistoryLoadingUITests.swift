import XCTest

final class TeamHistoryLoadingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSlowMonthDoesNotClaimZeroOrEmptyDates() throws {
        let app = launch(flags: ["-uitest-team-history-slow"])
        let summary = app.staticTexts["calendar.month.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("尚未就绪"))
        assertNoEmptyClaim(in: app)
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("尚未就绪"))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "没有训练")).firstMatch.exists)
        capture("Team 慢月的月摘要日期及日抽屉保持未知", in: app)
        expectCount(1, summary: summary, timeout: 15)
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("1 次训练"))
    }

    @MainActor func testFailedMonthRetriesAtLargestSize() throws {
        let app = launch(size: "accessibility5", flags: ["-uitest-team-history-offline-once"])
        let retry = app.buttons["calendar.history.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        assertNoEmptyClaim(in: app)
        XCTAssertTrue(app.staticTexts["calendar.month.summary"].label.contains("尚未就绪"))
        reveal(retry, in: app)
        XCTAssertGreaterThanOrEqual(retry.frame.height + 0.001, 44)
        capture("Team 首次月读取失败与原位重试：最大字号", in: app)
        retry.tap()
        expectCount(1, summary: app.staticTexts["calendar.month.summary"])
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
    }

    @MainActor func testRefreshFailureKeepsMonthAndSelectedDay() throws {
        let app = launch(flags: ["-uitest-team-history-refresh-failure"])
        let summary = app.staticTexts["calendar.month.summary"]
        expectCount(1, summary: summary)
        let scroll = app.scrollViews["calendar.history.scroll"]
        XCTAssertTrue(scroll.isHittable)
        let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 12, dy: 180))
        let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 12, dy: app.frame.maxY - 120))
        from.press(forDuration: 0.05, thenDragTo: to)
        let retry = app.buttons["calendar.history.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("1 次训练"))
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("1 次训练"))
        XCTAssertTrue(app.staticTexts["calendar.history.status"].label.contains("已保留本月记录"))
        assertNoEmptyClaim(in: app)
        capture("Team 月刷新失败保留统计和选中日记录", in: app)
        retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        expectCount(1, summary: summary)
    }

    @MainActor func testSuccessfulEmptyMonthUsesConfirmedEmptyState() throws {
        let app = launch(flags: ["-uitest-team-history-empty"])
        XCTAssertTrue(app.staticTexts["本月没有 Team 训练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("这天没有 Team 训练"))
        XCTAssertFalse(app.buttons["calendar.history.retry"].exists)
        capture("Team 成功空月后才显示无训练", in: app)
    }

    @MainActor func testEarlierMonthResponseCannotReplaceCurrentMonth() throws {
        let app = launch(flags: ["-uitest-team-history-race"])
        let summary = app.staticTexts["calendar.month.summary"]
        XCTAssertTrue(summary.label.contains("尚未就绪"))
        app.buttons["上个月"].tap()
        expectCount(2, summary: summary)
        let wrongMonth = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "1 次训练"), object: summary)
        wrongMonth.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [wrongMonth], timeout: 12), .completed)
        XCTAssertTrue(app.staticTexts["calendar.day.summary"].label.contains("2 次训练"))
        capture("较早请求迟到仍保留当前月份与日抽屉", in: app)
        app.buttons["下个月"].tap()
        expectCount(1, summary: summary)
        app.buttons["上个月"].tap()
        expectCount(2, summary: summary)
    }

    @MainActor func testMonthPickerRefreshesLoadedMonthSummaries() throws {
        let app = launch(flags: [])
        let summary = app.staticTexts["calendar.month.summary"]
        expectCount(1, summary: summary)
        let calendar = Calendar.current
        let now = Date.now
        let previousDate = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: now))
        let currentPrefix = "\(calendar.component(.year, from: now))年\(calendar.component(.month, from: now))月，"
        let previousPrefix = "\(calendar.component(.year, from: previousDate))年\(calendar.component(.month, from: previousDate))月，"
        app.buttons["选择月份"].tap()
        let currentMonth = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", currentPrefix)).firstMatch
        let previousMonth = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", previousPrefix)).firstMatch
        XCTAssertTrue(currentMonth.waitForExistence(timeout: 5))
        XCTAssertTrue(currentMonth.label.contains("1次训练"))
        XCTAssertTrue(app.staticTexts[String(calendar.component(.year, from: now))].exists,
                      "年份应显示连续数字，不能使用千位分隔符")
        reveal(previousMonth, in: app)
        XCTAssertTrue(previousMonth.label.contains("尚未加载"))
        capture("月份选择器保留已加载摘要与未加载状态", in: app)
        previousMonth.tap()
        XCTAssertTrue(app.staticTexts["选择月份"].waitForNonExistence(timeout: 5))
        expectCount(2, summary: summary)
        app.buttons["选择月份"].tap()
        XCTAssertTrue(previousMonth.waitForExistence(timeout: 5))
        XCTAssertTrue(previousMonth.label.contains("2次训练"))
        XCTAssertTrue(currentMonth.label.contains("1次训练"))
        capture("再次打开选择器读取新月份摘要", in: app)
        previousMonth.tap()
        XCTAssertTrue(app.staticTexts["选择月份"].waitForNonExistence(timeout: 5))
    }

    @MainActor private func launch(size: String = "large", flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-uitest-team-readability",
                               "-uitest-team-history-loading", "-dismiss-career-review", "-uitest-typography-size", size] + flags
        app.launch()
        let tab = app.tabBars.buttons["Team"]
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        let team = app.buttons.containing(.staticText, identifier: "UI 大字 Team · 长期力量与稳定控制").firstMatch
        XCTAssertTrue(team.waitForExistence(timeout: 5))
        team.tap()
        let history = app.buttons["历史训练"]
        reveal(history, in: app)
        history.tap()
        XCTAssertTrue(app.staticTexts["calendar.month.summary"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func expectCount(_ count: Int, summary: XCUIElement, timeout: TimeInterval = 5) {
        let value = NSPredicate(format: "label BEGINSWITH %@", "\(count) 次训练")
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(value.evaluate(with: summary) || XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: value, object: summary)], timeout: timeout) == .completed)
    }

    @MainActor private func assertNoEmptyClaim(in app: XCUIApplication) {
        XCTAssertFalse(app.staticTexts["本月没有 Team 训练"].exists)
        XCTAssertFalse(app.staticTexts["这天没有 Team 训练"].exists)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists && element.isHittable && element.frame.minY >= 120 && element.frame.maxY <= app.frame.maxY - 34 { return }
            let down = element.exists && element.frame.minY < 120
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 280 : 550))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 450 : 380))
            from.press(forDuration: 0.01, thenDragTo: to)
        }
        XCTFail("Team 历史控件未滚入可用区域")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
