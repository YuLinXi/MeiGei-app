import XCTest

/// 假登录隔离训练库；验证真实录入、完成与休息，不改变日常训练数据或系统字号。
final class WorkoutReadabilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testWorkoutAtDefaultReadingSize() throws { try checkWorkout(size: "large") }
    @MainActor func testWorkoutAtXXXLReadingSize() throws { try checkWorkout(size: "xxxLarge") }
    @MainActor func testWorkoutAtLargestReadingSize() throws { try checkWorkout(size: "accessibility5") }

    @MainActor func testSetMenuNearBottomAtDefaultReadingSize() throws { checkSetMenuNearBottom(size: "large") }
    @MainActor func testSetMenuNearBottomAtLargestReadingSize() throws { checkSetMenuNearBottom(size: "accessibility5") }

    @MainActor private func checkSetMenuNearBottom(size: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let more = app.buttons["第 3 组更多操作"].firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(more, in: app))
        revealUITestElement(more, in: app)
        XCTAssertTrue(more.isHittable)
        let allSetMenus = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "第 [0-9]+ 组更多操作"))
        let initialSetCount = allSetMenus.count
        XCTAssertGreaterThan(more.frame.midY, app.frame.midY, "从屏幕下半部的组打开菜单")
        print("[S6-set-menu] size=\(size) window=\(app.frame) anchor=\(more.frame)")
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "屏幕下方训练组菜单入口：\(size)"
        before.lifetime = .keepAlways
        add(before)
        more.tap()
        let remove = app.buttons["删除组"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        let menu = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        menu.name = "屏幕下方训练组菜单：\(size)"
        menu.lifetime = .keepAlways
        add(menu)
        XCTAssertTrue(remove.isHittable, "末项必须可点击")
        XCTAssertGreaterThanOrEqual(remove.frame.minY, app.frame.minY + 12)
        XCTAssertLessThanOrEqual(remove.frame.maxY, app.frame.maxY - 12, "末项不得超出屏幕")
        remove.tap()
        let deleted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            allSetMenus.count == initialSetCount - 1
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [deleted], timeout: 5), .completed, "应实际删除一组")
        XCTAssertTrue(remove.waitForNonExistence(timeout: 5))
    }

    @MainActor func testCapsuleAtDefaultReadingSize() throws { checkCapsule(size: "large") }
    @MainActor func testCapsuleAtLargestReadingSize() throws { checkCapsule(size: "accessibility5") }

    @MainActor private func checkCapsule(size: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let minimize = app.buttons["收起训练"]
        XCTAssertTrue(waitForIsolatedUITestScene(minimize, in: app))
        minimize.tap()
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        capture("进行中胶囊：\(size)", app: app)
        XCTAssertGreaterThanOrEqual(capsule.frame.width + 0.001, 44)
        XCTAssertGreaterThanOrEqual(capsule.frame.height + 0.001, 44)
        let original = capsule.frame
        let destination = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.maxX - 40, dy: original.midY - 80))
        capsule.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: destination)
        XCTAssertFalse(minimize.exists)
        XCTAssertGreaterThan(capsule.frame.minX, original.minX + 30)
        XCTAssertLessThanOrEqual(capsule.frame.maxX, app.frame.maxX - 10)
        capture("拖动吸附后胶囊：\(size)", app: app)
        capsule.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
    }

    @MainActor func testStructuredWorkoutAtLargestReadingSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-uitest-structured-workout", "-dismiss-career-review",
                               "-uitest-typography-size", "accessibility5"]
        app.launch()
        let thirdWeight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "第 3 组重量")).firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(thirdWeight, in: app))
        revealUITestElement(thirdWeight, in: app)
        XCTAssertTrue(fullyVisible(thirdWeight, app: app, avoidAddBar: true))
        thirdWeight.tap()
        XCTAssertTrue(app.buttons["数字 7"].waitForExistence(timeout: 5))
        XCTAssertLessThan(thirdWeight.frame.maxY, app.buttons["数字 1"].frame.minY)
        app.buttons["数字 7"].tap()
        app.buttons["小数点"].tap()
        app.buttons["数字 5"].tap()
        XCTAssertEqual(thirdWeight.value as? String, "7.5 公斤")
        app.buttons["下一项"].tap()
        app.buttons["数字 9"].tap()
        let thirdReps = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "第 3 组次数")).firstMatch
        XCTAssertEqual(thirdReps.value as? String, "9 次")
        capture("递减末组录入：accessibility5", app: app)
        XCTAssertLessThan(thirdReps.frame.maxY, app.buttons["数字 1"].frame.minY)
        app.buttons["收起键盘"].tap()
        let dropComplete = app.buttons["workout.set.complete.0"].firstMatch
        revealUITestElement(dropComplete, in: app)
        dropComplete.tap()
        XCTAssertTrue(dropComplete.label.contains("已完成"))
        try endRest(app)
        let expand = app.buttons["展开超级组"]
        revealUITestElement(expand, in: app)
        XCTAssertTrue(expand.isHittable)
        expand.tap()
        let firstWeight = app.buttons["杠铃划船第 1 组 重量"]
        revealUITestElement(firstWeight, in: app)
        XCTAssertTrue(firstWeight.isHittable)
        firstWeight.tap()
        XCTAssertTrue(app.buttons["数字 8"].waitForExistence(timeout: 5))
        app.buttons["数字 8"].tap()
        app.buttons["数字 2"].tap()
        app.buttons["小数点"].tap()
        app.buttons["数字 5"].tap()
        app.buttons["下一项"].tap()
        app.buttons["数字 1"].tap()
        app.buttons["数字 2"].tap()
        let firstReps = app.buttons["杠铃划船第 1 组 次数"]
        XCTAssertEqual(firstWeight.value as? String, "82.5 公斤")
        XCTAssertEqual(firstReps.value as? String, "12 次")
        capture("超级组成员录入：accessibility5", app: app)
        XCTAssertLessThan(firstReps.frame.maxY, app.buttons["数字 1"].frame.minY)
        app.buttons["收起键盘"].tap()
        let roundComplete = app.buttons["workout.superset.complete.0"]
        revealUITestElement(roundComplete, in: app)
        XCTAssertTrue(roundComplete.isHittable)
        roundComplete.tap()
        XCTAssertTrue(roundComplete.label.contains("已完成"))
        try endRest(app)
        XCTAssertTrue(app.buttons["workout.superset.complete.1"].label.contains("标记"))
        XCTAssertEqual(app.buttons["坐姿哑铃推肩第 1 组 次数"].value as? String, "10 次")
        capture("超级组按轮完成保留成员值：accessibility5", app: app)
    }

    @MainActor private func endRest(_ app: XCUIApplication) throws {
        let floating = app.buttons["休息计时，点按展开"]
        XCTAssertTrue(floating.waitForExistence(timeout: 5))
        floating.tap()
        let done = app.buttons["完成休息"]
        revealUITestElement(done, in: app)
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(floating.waitForNonExistence(timeout: 5))
    }

    @MainActor private func checkWorkout(size: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        guard waitForIsolatedUITestScene(weight, in: app) else {
            capture("隔离训练未进入：\(size)", app: app)
            XCTFail("未出现隔离训练录入；当前按钮：\(app.buttons.allElementsBoundByIndex.map(\.label))")
            return
        }
        capture("训练录入初始：\(size)", app: app)
        XCTAssertGreaterThanOrEqual(weight.frame.height + 0.001, 44)
        for _ in 0..<8 where !fullyVisible(weight, app: app, avoidAddBar: true) { app.swipeUp() }
        XCTAssertTrue(fullyVisible(weight, app: app, avoidAddBar: true))
        weight.tap()
        XCTAssertTrue(app.buttons["数字 9"].waitForExistence(timeout: 5))
        for digit in [9, 9, 9, 9] { app.buttons["数字 \(digit)"].tap() }
        app.buttons["小数点"].tap()
        app.buttons["数字 7"].tap()
        app.buttons["数字 5"].tap()
        XCTAssertEqual(weight.value as? String, "9999.75 公斤")
        XCTAssertLessThan(weight.frame.maxY, app.buttons["数字 1"].frame.minY)
        capture("长数值与数字键盘：\(size)", app: app)
        app.buttons["下一项"].tap()
        app.buttons["数字 2"].tap()
        app.buttons["数字 7"].tap()
        let reps = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 次数")).firstMatch
        XCTAssertEqual(reps.value as? String, "27 次")
        app.buttons["上一项"].tap()
        XCTAssertEqual(weight.value as? String, "9999.75 公斤")
        app.buttons["收起键盘"].tap()
        let complete = app.buttons["workout.set.complete.0"].firstMatch
        for _ in 0..<6 where !fullyVisible(complete, app: app, avoidAddBar: true) { app.swipeDown() }
        XCTAssertTrue(complete.isHittable)
        complete.tap()
        XCTAssertTrue(complete.label.contains("已完成"))
        let floatingRest = app.buttons["休息计时，点按展开"].firstMatch
        XCTAssertTrue(floatingRest.waitForExistence(timeout: 5))
        capture("完成组与休息入口：\(size)", app: app)
        floatingRest.tap()
        let plus = app.buttons["增加10秒"]
        let minus = app.buttons["减少10秒"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        capture("展开休息计时：\(size)", app: app)
        for _ in 0..<6 where !plus.isHittable { app.swipeUp() }
        XCTAssertTrue(plus.isHittable)
        plus.tap()
        XCTAssertEqual(app.staticTexts["rest.total"].value as? String, "310")
        XCTAssertTrue(minus.isHittable)
        minus.tap()
        XCTAssertEqual(app.staticTexts["rest.total"].value as? String, "300")
        for label in ["休息震动", "休息声音"] {
            let toggle = app.buttons[label]
            for _ in 0..<6 where !fullyVisible(toggle, app: app) { app.swipeUp() }
            XCTAssertTrue(toggle.isHittable)
            XCTAssertGreaterThanOrEqual(toggle.frame.height + 0.001, 44)
            let original = toggle.value as? String
            toggle.tap()
            XCTAssertNotEqual(toggle.value as? String, original)
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, original)
        }
        capture("休息调时与设置：\(size)", app: app)
        let minimize = app.buttons["最小化休息计时"]
        for _ in 0..<6 where !minimize.isHittable { app.swipeDown() }
        XCTAssertTrue(minimize.isHittable)
        minimize.tap()
        XCTAssertTrue(floatingRest.waitForExistence(timeout: 5))
        XCTAssertTrue(complete.label.contains("已完成"))
        floatingRest.tap()
        let done = app.buttons["完成休息"]
        for _ in 0..<6 where !done.isHittable { app.swipeUp() }
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(floatingRest.waitForNonExistence(timeout: 5))
        XCTAssertTrue(complete.label.contains("已完成"))
        XCTAssertEqual(weight.value as? String, "9999.75 公斤")
        XCTAssertEqual(reps.value as? String, "27 次")
        capture("休息完成保留录入：\(size)", app: app)
        for _ in 0..<6 where !fullyVisible(weight, app: app, avoidAddBar: true) { app.swipeUp() }
        weight.tap()
        XCTAssertTrue(app.buttons["数字 9"].waitForExistence(timeout: 5))
        capture("已完成字段聚焦：\(size)", app: app)
        app.buttons["收起键盘"].tap()
        XCTAssertEqual(weight.value as? String, "9999.75 公斤")
    }

    @MainActor private func fullyVisible(_ element: XCUIElement, app: XCUIApplication, avoidAddBar: Bool = false) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let add = app.buttons["添加动作"]
        let bottom = avoidAddBar && add.exists ? add.frame.minY - 8 : app.frame.maxY - 34
        return element.frame.minY >= 62 && element.frame.maxY <= bottom
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
