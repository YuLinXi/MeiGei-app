import XCTest

/// 读取隔离训练样例，验证首页、选日/选月及历史详情的真实导航。
final class HomeCalendarReadabilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testHomeCalendarAtDefaultReadingSize() throws { try checkHistory(size: "large") }
    @MainActor func testHomeCalendarAtXXXLReadingSize() throws { try checkHistory(size: "xxxLarge") }
    @MainActor func testHomeCalendarAtLargestReadingSize() throws { try checkHistory(size: "accessibility5") }

    @MainActor private func checkHistory(size: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-history-save", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let calendarEntry = app.buttons["历史日历"]
        XCTAssertTrue(waitForIsolatedUITestScene(calendarEntry, in: app))
        capture("首页阅读：\(size)", app: app)
        let start = app.buttons["开始训练"].firstMatch
        XCTAssertGreaterThanOrEqual(start.frame.height + 0.001, 44)
        for _ in 0..<12 where !fullyVisible(calendarEntry, app: app, bottom: start.frame.minY - 8) { app.swipeUp() }
        XCTAssertTrue(fullyVisible(calendarEntry, app: app, bottom: start.frame.minY - 8))
        capture("首页历史入口：\(size)", app: app)
        calendarEntry.tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        let today = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", formatter.string(from: .now) + "，")).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        capture("训练月历：\(size)", app: app)
        let grid = app.scrollViews["calendar.grid"]
        for _ in 0..<8 where today.frame.maxY > app.frame.maxY - 34 { app.swipeUp() }
        for _ in 0..<8 where today.frame.minY < 114 { app.swipeDown() }
        for _ in 0..<6 where today.frame.maxX > app.frame.maxX - 22 { scrollGrid(grid, left: true, app: app) }
        for _ in 0..<6 where today.frame.minX < 22 { scrollGrid(grid, left: false, app: app) }
        capture("日历选日可见区域：\(size)", app: app)
        XCTAssertTrue(fullyVisible(today, app: app), "day=\(today.frame), grid=\(grid.frame)")
        today.tap()
        XCTAssertTrue(today.isSelected)
        XCTAssertGreaterThanOrEqual(today.frame.width + 0.001, 44)
        XCTAssertGreaterThanOrEqual(today.frame.height + 0.001, 44)
        let picker = app.buttons["选择月份"]
        for _ in 0..<10 where !fullyVisible(picker, app: app) { app.swipeDown() }
        picker.tap()
        XCTAssertTrue(app.staticTexts["选择月份"].waitForExistence(timeout: 5))
        let now = Date.now
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        let month = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(components.year!)年\(components.month!)月，")).firstMatch
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        for _ in 0..<6 where !fullyVisible(month, app: app) { app.swipeUp() }
        XCTAssertTrue(month.isHittable)
        capture("月份选择：\(size)", app: app)
        month.tap()
        XCTAssertTrue(app.staticTexts["选择月份"].waitForNonExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "UI 另存胸背", "动作")).firstMatch
        for _ in 0..<14 where !fullyVisible(row, app: app) { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        capture("选日训练抽屉：\(size)", app: app)
        row.tap()
        let back = app.buttons["返回"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        capture("历史详情阅读：\(size)", app: app)
        let log = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "杠铃卧推，")).firstMatch
        for _ in 0..<10 where !fullyVisible(log, app: app) { app.swipeUp() }
        XCTAssertTrue(log.isHittable)
        log.tap()
        XCTAssertTrue(log.label.contains("已收起"))
        log.tap()
        XCTAssertTrue(log.label.contains("已展开"))
        capture("历史动作展开与逐组：\(size)", app: app)
        let firstSet = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 组，60 公斤，10 次")).firstMatch
        for _ in 0..<8 where !fullyVisible(firstSet, app: app) { app.swipeUp() }
        XCTAssertTrue(fullyVisible(firstSet, app: app))
        capture("历史逐组完整数值：\(size)", app: app)
        back.tap()
        XCTAssertTrue(today.waitForExistence(timeout: 5))
    }

    @MainActor private func scrollGrid(_ grid: XCUIElement, left: Bool, app: XCUIApplication) {
        let top = max(114, grid.frame.minY)
        let bottom = min(app.frame.maxY - 34, grid.frame.maxY)
        let y = (top + bottom) / 2
        let minX = max(22, grid.frame.minX) + 12
        let maxX = min(app.frame.maxX - 22, grid.frame.maxX) - 12
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: left ? maxX : minX, dy: y))
        let end = origin.withOffset(CGVector(dx: left ? minX : maxX, dy: y))
        start.press(forDuration: 0, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
    }

    @MainActor private func fullyVisible(_ element: XCUIElement, app: XCUIApplication, bottom: CGFloat? = nil) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let tab = app.tabBars.firstMatch
        let visibleTab = tab.exists && tab.isHittable
        let limit = bottom ?? (visibleTab && tab.frame.midY > app.frame.midY ? tab.frame.minY - 8 : app.frame.maxY - 34)
        let top = visibleTab && tab.frame.midY < app.frame.midY ? max(114, tab.frame.maxY + 8) : 114
        return element.frame.minY >= top && element.frame.maxY <= limit
            && element.frame.minX >= 16 && element.frame.maxX <= app.frame.maxX - 16
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
