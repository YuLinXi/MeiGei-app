import XCTest

/// 假登录隔离库：验证真实索引、搜索与创建表单，不请求真实账号或后端。
final class ExerciseLibraryReadabilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testLibraryAtDefaultReadingSize() throws { try checkLibrary(size: "large") }
    @MainActor func testLibraryAtXXXLReadingSize() throws { try checkLibrary(size: "xxxLarge") }
    @MainActor func testLibraryAtLargestReadingSize() throws { try checkLibrary(size: "accessibility5") }

    @MainActor private func checkLibrary(size: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-dismiss-career-review",
                               "-uitest-fail-exercise-save", "-uitest-typography-size", size]
        app.launch()
        let exercises = mainTab("动作", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(exercises, in: app))
        exercises.tap()
        let barbell = app.buttons["筛选杠铃"]
        let dumbbell = app.buttons["筛选哑铃"]
        XCTAssertTrue(barbell.waitForExistence(timeout: 10))
        capture("动作库索引：\(size)", app: app)
        XCTAssertGreaterThanOrEqual(barbell.frame.width + 0.001, 44)
        XCTAssertGreaterThanOrEqual(barbell.frame.height + 0.001, 44)
        XCTAssertFalse(barbell.frame.intersects(dumbbell.frame))
        barbell.tap()
        capture("索引点按后：\(size)", app: app)
        XCTAssertTrue(barbell.isSelected && !dumbbell.isSelected)
        barbell.press(forDuration: 0.25, thenDragTo: dumbbell)
        capture("索引拖选后：\(size)", app: app)
        XCTAssertTrue(dumbbell.isSelected && !barbell.isSelected)
        XCTAssertFalse(app.buttons["返回"].exists, "索引拖选不得误打开动作详情")
        let index = app.scrollViews["exercise.quickIndex"]
        let other = app.buttons["筛选其他"]
        for _ in 0..<8 where !fullyVisible(other, in: app) { scrollIndex(index, up: true, app: app) }
        XCTAssertTrue(fullyVisible(other, in: app), "other=\(other.frame), index=\(index.frame), add=\(app.buttons["添加自定义动作"].frame), tab=\(app.tabBars.firstMatch.frame)")
        XCTAssertTrue(dumbbell.isSelected, "短滑浏览索引不得意外改变筛选")
        other.tap()
        XCTAssertTrue(other.isSelected)
        let all = app.buttons["筛选全部"]
        for _ in 0..<8 where !fullyVisible(all, in: app) { scrollIndex(index, up: false, app: app) }
        XCTAssertTrue(fullyVisible(all, in: app))
        all.tap()
        XCTAssertTrue(all.isSelected)

        let search = app.textFields.firstMatch
        search.tap()
        search.typeText("杠铃卧推")
        let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN {'Search', 'search', '搜索'}")).firstMatch
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "杠铃卧推，")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.isHittable)
        result.tap()
        let back = app.buttons["返回"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        let lastSet = app.staticTexts["exercise.data.最近一组"]
        let pr = app.staticTexts["exercise.data.PR"]
        if size == "accessibility5" {
            for _ in 0..<5 where !pr.isHittable { app.swipeUp() }
            XCTAssertTrue(pr.isHittable)
            XCTAssertGreaterThan(pr.frame.minY, lastSet.frame.minY, "大字统计纵排，避免数值与单位拆列")
            XCTAssertLessThan(pr.frame.height, 90, "当前70kg样例应完整位于一行")
        }
        capture("动作检索与详情：\(size)", app: app)
        let muscles = app.staticTexts["目标肌群"]
        for _ in 0..<8 where !muscles.isHittable { app.swipeUp() }
        XCTAssertTrue(muscles.isHittable)
        capture("动作要点与肌群：\(size)", app: app)
        back.tap()
        let clear = app.buttons["清除搜索"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(clear.frame.height + 0.001, 44)
        clear.tap()

        app.buttons["添加自定义动作"].tap()
        let name = "大字保存\(UUID().uuidString.prefix(6))"
        let field = app.textFields["输入名称（必填）"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        let save = app.buttons["保存"]
        XCTAssertTrue(save.isHittable)
        save.tap()
        let error = app.staticTexts["localSave.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
        XCTAssertTrue(save.isHittable)
        capture("大字动作保存失败：\(size)", app: app)
        save.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        app.buttons["自定义"].tap()
        let created = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 5))
        capture("大字动作重试成功：\(size)", app: app)
    }

    @MainActor private func fullyVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let index = app.scrollViews["exercise.quickIndex"]
        return index.frame.intersection(app.frame).contains(element.frame)
            && !app.buttons["添加自定义动作"].frame.intersects(element.frame)
    }

    @MainActor private func scrollIndex(_ index: XCUIElement, up: Bool, app: XCUIApplication) {
        // 从实际可见区域拖动，避开底部添加钮与 Tab Bar。
        let top = max(64, index.frame.minY) + 12
        let bottom = min(index.frame.maxY, app.buttons["添加自定义动作"].frame.minY) - 12
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: index.frame.midX, dy: up ? bottom : top))
        let end = origin.withOffset(CGVector(dx: index.frame.midX, dy: up ? top : bottom))
        start.press(forDuration: 0, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
