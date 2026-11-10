import XCTest

/// 使用既有隔离场景操作真实控件；横竖屏分别运行，不创建或清空模拟器。
final class DeviceLayoutUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private var textSize: String { ProcessInfo.processInfo.environment["DONTLIFT_UI_TEXT_SIZE"] ?? "large" }

    @MainActor
    func testStartsStructuredPlanWithPresetValues() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow",
                               "-uitest-plan-readability", "-uitest-plan-alternatives", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", "large"]
        app.launch()
        let plans = mainTab("计划", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(plans, in: app))
        plans.tap()
        let group = app.buttons["展开UI 大字分组 · 长期力量与稳定控制"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        let plan = app.buttons["打开计划UI 大字计划 · 胸背力量与训练复盘"]
        revealUITestElement(plan, in: app, allowPartial: true)
        plan.tap()
        let start = app.buttons["开始这次训练"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(app.frame.contains(start.frame), "固定开始按钮需完整显示，不滚动正文定位")
        capture("从结构计划开始前的固定操作入口")
        start.tap()

        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 8))
        XCTAssertEqual(weight.value as? String, "60 公斤")
        let reps = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 次数")).firstMatch
        XCTAssertEqual(reps.value as? String, "8 次")
        for (name, expectedWeight) in [("哑铃卧推", "未填写"),
                                       ("UI 大字坐姿器械胸部推举与稳定控制训练", "60 公斤")] {
            let picker = app.buttons["选择备选动作，共 1 个"].firstMatch
            revealUITestElement(picker, in: app)
            picker.tap()
            let option = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            let confirm = app.buttons["更换动作"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            confirm.tap()
            XCTAssertTrue(weight.waitForExistence(timeout: 5))
            XCTAssertEqual(weight.value as? String, expectedWeight)
            XCTAssertEqual(reps.value as? String, "8 次")
        }
        revealUITestElement(weight, in: app)
        weight.tap()
        for name in ["数字 7", "数字 5", "小数点", "数字 2", "数字 5"] { app.buttons[name].tap() }
        XCTAssertEqual(weight.value as? String, "75.25 公斤")
        app.buttons["收起键盘"].tap()
        app.buttons["收起训练"].tap()
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 大字计划")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        capsule.tap()
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "75.25 公斤")
        XCTAssertEqual(reps.value as? String, "8 次")
        capture("从结构计划开始后预填与继续输入保留")
    }

    @MainActor
    func testFocusedInputSurvivesIPadWindowResizeAtDefaultReadingSize() throws {
        checkFocusedInputAcrossWindowResize(size: "large")
    }

    @MainActor
    func testFocusedInputSurvivesIPadWindowResizeAtLargestReadingSize() throws {
        checkFocusedInputAcrossWindowResize(size: "accessibility5")
    }

    @MainActor private func checkFocusedInputAcrossWindowResize(size: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(weight, in: app))
        let window = app.windows.firstMatch
        XCTAssertEqual(window.frame.width, 744, accuracy: 1, "需在既有iPad mini全屏竖屏中执行")
        XCTAssertEqual(window.frame.height, 1133, accuracy: 1)
        defer { if window.exists && window.frame.width < 700 { restoreIPadFullscreen(window) } }

        revealUITestElement(weight, in: app)
        weight.tap()
        for name in ["数字 7", "数字 3", "小数点", "数字 5"] { app.buttons[name].tap() }
        app.buttons["下一项"].tap()
        app.buttons["数字 1"].tap()
        app.buttons["数字 1"].tap()
        let reps = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 次数")).firstMatch
        XCTAssertEqual(weight.value as? String, "73.5 公斤")
        XCTAssertEqual(reps.value as? String, "11 次")
        capture("窗口缩放前保留焦点与输入：\(size)")

        let origin = window.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: window.frame.width - 6, dy: window.frame.height - 9))
        let end = origin.withOffset(CGVector(dx: window.frame.width - 190, dy: window.frame.height - 218))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        let narrow = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.width <= 400 && window.frame.height < 1000
        }, object: window)
        XCTAssertEqual(XCTWaiter.wait(for: [narrow], timeout: 5), .completed, "必须实际缩窄窗口")
        XCTAssertEqual(weight.value as? String, "73.5 公斤")
        XCTAssertEqual(reps.value as? String, "11 次")
        let firstKey = app.buttons["数字 1"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            reps.isHittable && firstKey.exists && reps.frame.maxY <= firstKey.frame.minY
                && reps.frame.minY >= window.frame.minY + 44
        }, object: reps)
        let visibleResult = XCTWaiter.wait(for: [visible], timeout: 5)
        print("[S5-window-focus] window=\(window.frame) reps=\(reps.frame) keypad=\(firstKey.frame) hittable=\(reps.isHittable)")
        capture("窗口缩窄后聚焦字段与数字键盘：\(size)")
        XCTAssertEqual(visibleResult, .completed, "窗口变化后聚焦字段需自动进入键盘上方")
        app.buttons["数字 2"].tap()
        XCTAssertEqual(reps.value as? String, "112 次", "缩窄后继续编辑同一单元")
        app.buttons["删除"].tap()
        XCTAssertEqual(reps.value as? String, "11 次")

        restoreIPadFullscreen(window)
        let full = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(window.frame.width - 744) <= 1 && abs(window.frame.height - 1133) <= 1
        }, object: window)
        XCTAssertEqual(XCTWaiter.wait(for: [full], timeout: 5), .completed)
        XCTAssertEqual(weight.value as? String, "73.5 公斤")
        XCTAssertEqual(reps.value as? String, "11 次")
        capture("恢复全屏后输入保持：\(size)")
    }

    @MainActor private func restoreIPadFullscreen(_ window: XCUIElement) {
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 52, dy: 32)).tap()
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 104, dy: 32)).tap()
    }

    @MainActor
    func testWorkoutInputAndRestAtSupportedOrientation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-dismiss-career-review", "-uitest-typography-size", textSize]
        app.launch()
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(weight, in: app))
        orient(app)
        defer { XCUIDevice.shared.orientation = .portrait }
        revealUITestElement(weight, in: app)
        weight.tap()
        XCTAssertTrue(app.buttons["数字 7"].waitForExistence(timeout: 5))
        for label in ["数字 7", "数字 3", "小数点", "数字 5"] { app.buttons[label].tap() }
        XCTAssertEqual(weight.value as? String, "73.5 公斤")
        XCTAssertLessThanOrEqual(weight.frame.maxY, app.buttons["数字 1"].frame.minY)
        app.buttons["下一项"].tap()
        for _ in 0..<2 { app.buttons["数字 1"].tap() }
        let reps = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 次数")).firstMatch
        XCTAssertEqual(reps.value as? String, "11 次")
        XCTAssertLessThanOrEqual(reps.frame.maxY, app.buttons["数字 1"].frame.minY)
        capture("当前设备数字输入与焦点")
        app.buttons["收起键盘"].tap()

        let complete = app.buttons["workout.set.complete.0"].firstMatch
        revealUITestElement(complete, in: app)
        complete.tap()
        XCTAssertTrue(complete.label.contains("已完成"))
        let rest = app.buttons["休息计时，点按展开"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        rest.tap()
        let plus = app.buttons["增加10秒"]
        revealUITestElement(plus, in: app)
        let original = Int(app.staticTexts["rest.total"].value as? String ?? "")
        XCTAssertNotNil(original)
        plus.tap()
        XCTAssertEqual(Int(app.staticTexts["rest.total"].value as? String ?? ""), original.map { $0 + 10 })
        capture("当前设备展开休息与调时")
        let done = app.buttons["完成休息"]
        revealUITestElement(done, in: app)
        done.tap()
        XCTAssertTrue(rest.waitForNonExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "73.5 公斤")
        XCTAssertEqual(reps.value as? String, "11 次")
    }

    @MainActor
    func testPlanAndExerciseSearchAtSupportedOrientation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow", "-clear-active-workout",
                               "-uitest-plan-readability", "-dismiss-career-review", "-uitest-typography-size", textSize]
        app.launch()
        let plans = mainTab("计划", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(plans, in: app))
        orient(app)
        defer { XCUIDevice.shared.orientation = .portrait }
        plans.tap()
        let group = app.buttons["展开UI 大字分组 · 长期力量与稳定控制"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        let count = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                                         "plan.group.count.", "1")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(count.frame.width, 4, "长分组名称不得把数量压成不可读的细条")
        XCTAssertTrue(group.frame.contains(count.frame))
        group.tap()
        let plan = app.buttons["打开计划UI 大字计划 · 胸背力量与训练复盘"]
        revealUITestElement(plan, in: app, allowPartial: true)
        plan.tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        let reorder = app.buttons["调整动作顺序"]
        revealUITestElement(reorder, in: app)
        print("[S5-plan-reorder] frame=\(reorder.frame)")
        capture("当前设备排序短操作布局")
        reorder.tap()
        let cancelReorder = app.buttons["取消排序"]
        XCTAssertTrue(cancelReorder.waitForExistence(timeout: 5))
        capture("当前设备排序面板与取消")
        cancelReorder.tap()
        XCTAssertTrue(cancelReorder.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.item.")).firstMatch
        let visibleRow = revealUITestElement(row, in: app, allowPartial: true)
        let selectedRow = app.buttons[row.identifier]
        print("[S5-plan-row] id=\(selectedRow.identifier) value=\(selectedRow.value ?? "无状态") visible=\(visibleRow)")
        XCTAssertEqual(selectedRow.value as? String, "已收起", "滚动不应触发动作展开")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: visibleRow.midX - app.frame.minX, dy: visibleRow.midY - app.frame.minY)).tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "已展开"), object: selectedRow)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)
        capture("当前设备计划详情与处方")
        app.buttons["返回"].firstMatch.tap()

        mainTab("动作", in: app).tap()
        let search = app.textFields["exercise.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("杠铃卧推")
        let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN {'Search', 'search', '搜索'}")).firstMatch
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "杠铃卧推，")).firstMatch
        revealUITestElement(result, in: app)
        print("[S5-exercise-card] frame=\(result.frame)")
        capture("当前设备动作搜索结果")
        result.tap()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 5))
        capture("当前设备动作搜索与详情")
        app.buttons["返回"].tap()
        app.buttons["清除搜索"].tap()
        XCTAssertTrue(app.buttons["清除搜索"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testQuickIndexAtSupportedOrientation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", textSize]
        app.launch()
        let exercises = mainTab("动作", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(exercises, in: app))
        orient(app)
        defer { XCUIDevice.shared.orientation = .portrait }
        exercises.tap()
        let barbell = app.buttons["筛选杠铃"]
        let dumbbell = app.buttons["筛选哑铃"]
        XCTAssertTrue(barbell.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(barbell.frame.width + 0.001, 44)
        XCTAssertGreaterThanOrEqual(barbell.frame.height + 0.001, 44)
        XCTAssertFalse(barbell.frame.intersects(dumbbell.frame))
        barbell.tap()
        XCTAssertTrue(barbell.isSelected)
        barbell.press(forDuration: 0.25, thenDragTo: dumbbell)
        XCTAssertTrue(dumbbell.isSelected && !barbell.isSelected)

        let index = app.scrollViews["exercise.quickIndex"]
        let other = app.buttons["筛选其他"]
        for _ in 0..<8 where !indexItemVisible(other, in: index, app: app) { index.swipeUp(velocity: .fast) }
        XCTAssertTrue(indexItemVisible(other, in: index, app: app))
        XCTAssertTrue(dumbbell.isSelected, "浏览索引不得意外改变筛选")
        capture("当前设备索引末项与添加钮")
        other.tap()
        XCTAssertTrue(other.isSelected)
        let all = app.buttons["筛选全部"]
        for _ in 0..<8 where !indexItemVisible(all, in: index, app: app) { index.swipeDown(velocity: .fast) }
        XCTAssertTrue(indexItemVisible(all, in: index, app: app))
        XCTAssertTrue(other.isSelected)
        all.tap()
        XCTAssertTrue(all.isSelected)
        XCTAssertFalse(app.buttons["返回"].exists, "索引操作不得误打开动作详情")
        capture("当前设备索引恢复全部")
    }

    @MainActor private func indexItemVisible(_ item: XCUIElement, in index: XCUIElement, app: XCUIApplication) -> Bool {
        item.exists && item.isHittable && index.frame.contains(item.frame)
            && !app.buttons["添加自定义动作"].frame.intersects(item.frame)
    }

    @MainActor private func orient(_ app: XCUIApplication) {
        let landscape = ProcessInfo.processInfo.environment["DONTLIFT_UI_ORIENTATION"] != "portrait"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        print("[S5-orientation] device=\(XCUIDevice.shared.orientation.rawValue) app=\(app.frame) window=\(app.windows.firstMatch.frame)")
        capture("旋转指令后的实际界面")
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        if ProcessInfo.processInfo.environment["DONTLIFT_UI_WINDOW_MODE"] == "narrow" {
            XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width, 400, "窄窗口验收必须在实际窄窗口内执行")
        }
        print("[S5-layout] orientation=\(landscape ? "landscape" : "portrait") frame=\(app.frame)")
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
