import XCTest

final class ActiveWorkoutConflictUITests: XCTestCase {
    private enum Route { case home, plan, team }
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testHomeAtDefaultSize() throws { checkConflict(route: .home, size: "large") }
    @MainActor func testHomeAtLargestSize() throws { checkConflict(route: .home, size: "accessibility5") }
    @MainActor func testPlanAtDefaultSize() throws { checkConflict(route: .plan, size: "large") }
    @MainActor func testPlanAtLargestSize() throws { checkConflict(route: .plan, size: "accessibility5") }
    @MainActor func testTeamAtDefaultSize() throws { checkConflict(route: .team, size: "large") }
    @MainActor func testTeamAtLargestSize() throws { checkConflict(route: .team, size: "accessibility5") }

    @MainActor func testReplacementFailurePreservesInputsAndRetryStartsOnce() throws {
        let app = prepareActiveWorkout(size: "large", additionalArguments: ["-uitest-fail-start-save"])
        let start = app.buttons["开始训练"].firstMatch
        reveal(start, in: app)
        start.tap()
        let discard = app.buttons["丢弃并开始新训练"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "原训练仍保留")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        capsule.tap()
        assertOriginalInputs(in: app)
        capture("替换保存失败保留原训练与休息", in: app)

        app.buttons["收起训练"].tap()
        start.tap()
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.buttons["收起训练"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["workout.set.complete.0"].exists)
        XCTAssertFalse(app.buttons["休息计时，点按展开"].exists)
        capture("替换重试进入空白新训练且已停止旧休息", in: app)
        app.buttons["收起训练"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 训练")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(capsule.exists)
    }

    @MainActor private func prepareActiveWorkout(size: String, additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-plan-readability",
                               "-uitest-team-readability", "-dismiss-career-review", "-uitest-typography-size", size] + additionalArguments
        app.launch()
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(weight, in: app))
        reveal(weight, in: app, avoidAddBar: true)
        weight.tap()
        XCTAssertTrue(app.buttons["数字 6"].waitForExistence(timeout: 5))
        for digit in [6, 3] { app.buttons["数字 \(digit)"].tap() }
        app.buttons["小数点"].tap()
        for digit in [7, 5] { app.buttons["数字 \(digit)"].tap() }
        XCTAssertEqual(weight.value as? String, "63.75 公斤")
        app.buttons["收起键盘"].tap()
        let complete = app.buttons["workout.set.complete.0"].firstMatch
        reveal(complete, in: app, avoidAddBar: true)
        complete.tap()
        XCTAssertTrue(complete.label.contains("已完成"))
        let rest = app.buttons["休息计时，点按展开"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        app.buttons["收起训练"].tap()
        return app
    }

    @MainActor private func checkConflict(route: Route, size: String) {
        let app = prepareActiveWorkout(size: size)
        switch route {
        case .home: break
        case .plan:
            app.tabBars.buttons["计划"].tap()
            let expand = app.buttons["展开UI 大字分组 · 长期力量与稳定控制"]
            if expand.exists { expand.tap() }
            let plan = app.buttons["打开计划UI 大字计划 · 胸背力量与训练复盘"]
            XCTAssertTrue(plan.waitForExistence(timeout: 5))
            reveal(plan, in: app)
            plan.tap()
        case .team:
            app.tabBars.buttons["Team"].tap()
            let team = app.buttons.containing(.staticText, identifier: "UI 大字 Team · 长期力量与稳定控制").firstMatch
            XCTAssertTrue(team.waitForExistence(timeout: 5))
            team.tap()
            let plans = app.buttons["Team 计划"]
            reveal(plans, in: app)
            plans.tap()
        }
        let start = app.buttons[route == .plan ? "开始这次训练" : "开始训练"].firstMatch
        reveal(start, in: app)
        start.tap()
        let title = app.staticTexts["已有进行中的训练"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        capture("训练冲突动作顺序与取消：\(route) \(size)", in: app)
        let cancel = app.buttons["取消"]
        let keep = app.buttons["继续训练"]
        let discard = app.buttons["丢弃并开始新训练"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        for button in [keep, discard, cancel] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height + 0.001, 44)
            XCTAssertTrue(app.frame.contains(button.frame))
        }
        XCTAssertLessThan(keep.frame.minY, discard.frame.minY)
        XCTAssertLessThan(discard.frame.minY, cancel.frame.minY)
        cancel.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()
        assertOriginalInputs(in: app)
        capture("继续原训练保留输入完成与休息：\(route) \(size)", in: app)
    }

    @MainActor private func assertOriginalInputs(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["收起训练"].waitForExistence(timeout: 5))
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        XCTAssertEqual(weight.value as? String, "63.75 公斤")
        let complete = app.buttons["workout.set.complete.0"].firstMatch
        XCTAssertTrue(complete.label.contains("已完成"))
        XCTAssertTrue(app.buttons["休息计时，点按展开"].exists)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, avoidAddBar: Bool = false) {
        for _ in 0..<20 {
            let tab = app.tabBars.firstMatch
            let add = app.buttons["添加动作"]
            let bottom = avoidAddBar && add.exists && add.isHittable
                ? add.frame.minY - 8
                : (tab.exists && tab.isHittable ? tab.frame.minY - 8 : app.frame.maxY - 34)
            if element.exists && element.isHittable && element.frame.minY >= 120 && element.frame.maxY <= bottom { return }
            let down = element.exists && element.frame.minY < 120
            let x = app.frame.maxX - 9
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: down ? 280 : 550))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: down ? 450 : 380))
            from.press(forDuration: 0.01, thenDragTo: to)
        }
        XCTFail("冲突入口未滚入可用区域：\(element)")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
