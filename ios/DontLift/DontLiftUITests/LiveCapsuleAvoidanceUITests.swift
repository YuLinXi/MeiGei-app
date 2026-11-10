import XCTest

final class LiveCapsuleAvoidanceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testCapsuleAvoidsActionsAndResumesAtDefaultSize() throws { check(size: "large") }
    @MainActor func testCapsuleAvoidsActionsAndResumesAtLargestSize() throws { check(size: "accessibility5") }
    @MainActor func testCapsuleAvoidsProfileSyncAtDefaultSize() throws { checkProfileSync(size: "large") }
    @MainActor func testCapsuleAvoidsProfileSyncAtLargestSize() throws { checkProfileSync(size: "accessibility5") }
    @MainActor func testFullCapsuleElapsedSemanticsAdvanceWhileIdle() { checkIdleElapsed(size: "large", profile: false) }
    @MainActor func testCompactCapsuleElapsedSemanticsAdvanceWhileIdle() { checkIdleElapsed(size: "accessibility5", profile: false) }
    @MainActor func testProfileCapsuleElapsedSemanticsAdvanceWhileIdle() { checkIdleElapsed(size: "large", profile: true) }

    @MainActor private func checkIdleElapsed(size: String, profile: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-history-loading",
                               "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let minimize = app.buttons["收起训练"]
        XCTAssertTrue(waitForIsolatedUITestScene(minimize, in: app))
        minimize.tap()
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        if profile { app.tabBars.buttons["我的"].tap() }
        let reads = app.staticTexts["uitest.history.readCount"]
        XCTAssertTrue(reads.waitForExistence(timeout: 5))
        let originalReads = reads.value as? String
        for _ in 0..<2 {
            let before = elapsed(from: capsule.label)
            let advancing = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.elapsed(from: capsule.label) >= before + 2
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [advancing], timeout: 6), .completed,
                           "静置时计时语义应前进：size=\(size), profile=\(profile), label=\(capsule.label)")
        }
        XCTAssertEqual(reads.value as? String, originalReads, "局部计时不新增全量历史读取")
        XCTAssertTrue(capsule.label.contains("下一组 上斜杠铃卧推"))
    }

    @MainActor private func checkProfileSync(size: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-history-loading",
                               "-uitest-sync-recovery", "-dismiss-career-review",
                               "-uitest-typography-size", size]
        app.launch()
        let minimize = app.buttons["收起训练"]
        XCTAssertTrue(waitForIsolatedUITestScene(minimize, in: app))
        minimize.tap()
        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        app.tabBars.buttons["我的"].tap()
        let row = app.buttons["profile.sync"]
        revealUITestElement(row, in: app)
        assertProfileAvoidance(capsule, action: row, in: app, name: "我的同步默认位置：\(size)")
        let reads = app.staticTexts["uitest.history.readCount"]
        XCTAssertTrue(reads.waitForExistence(timeout: 5))
        let originalReads = reads.value as? String
        let destination = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.minX + 24, dy: row.frame.midY))
        capsule.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: destination)
        XCTAssertFalse(minimize.exists)
        assertProfileAvoidance(capsule, action: row, in: app, name: "拖向同步行后避让：\(size)")
        XCTAssertEqual(reads.value as? String, originalReads, "布局避让不新增历史读取")

        for result in ["上次部分失败", "上次同步成功"] {
            row.tap()
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", result), object: row)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 15), .completed)
            revealUITestElement(row, in: app)
            assertProfileAvoidance(capsule, action: row, in: app, name: "同步结果\(result)：\(size)")
        }
        capsule.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["我的"].isSelected)
        app.tabBars.buttons["训练"].tap()
        assertAvoidance(capsule, action: app.buttons["开始训练"].firstMatch, in: app,
                        name: "资料页返回训练页：\(size)")
    }

    @MainActor private func assertProfileAvoidance(_ capsule: XCUIElement, action: XCUIElement,
                                                  in app: XCUIApplication, name: String) {
        assertAvoidance(capsule, action: action, in: app, name: name)
        XCTAssertTrue(capsule.label.contains("下一组 上斜杠铃卧推"))
        XCTAssertGreaterThanOrEqual(elapsed(from: capsule.label), 0)
        let sexCaption = app.staticTexts["性别"]
        if sexCaption.exists {
            XCTAssertFalse(capsule.frame.intersects(sexCaption.frame), "胶囊遮挡性别标签")
        }
        for button in app.buttons.allElementsBoundByIndex {
            guard !button.label.hasPrefix("继续训练 ") else { continue }
            let frame = button.frame
            guard frame.intersects(app.frame) else { continue }
            XCTAssertFalse(capsule.frame.intersects(frame), "胶囊遮挡\(button.label)：\(frame)")
        }
    }

    @MainActor private func check(size: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-history-loading",
                               "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        let minimize = app.buttons["收起训练"]
        XCTAssertTrue(waitForIsolatedUITestScene(minimize, in: app))
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
        reveal(weight, in: app)
        weight.tap()
        XCTAssertTrue(app.buttons["数字 6"].waitForExistence(timeout: 5))
        for key in ["数字 6", "数字 3", "小数点", "数字 7", "数字 5"] { app.buttons[key].tap() }
        app.buttons["收起键盘"].tap()
        let complete = app.buttons["workout.set.complete.0"].firstMatch
        reveal(complete, in: app)
        complete.tap()
        let rest = app.buttons["休息计时，点按展开"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        let reads = app.staticTexts["uitest.history.readCount"]
        XCTAssertTrue(reads.waitForExistence(timeout: 5))
        let originalReads = reads.value as? String
        minimize.tap()

        let capsule = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        let start = app.buttons["开始训练"].firstMatch
        assertAvoidance(capsule, action: start, in: app, name: "默认位置：\(size)")
        let elapsedBefore = elapsed(from: capsule.label)
        let destination = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.maxX - 20, dy: start.frame.midY))
        capsule.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: destination)
        XCTAssertFalse(minimize.exists, "拖动不能误开训练")
        assertAvoidance(capsule, action: start, in: app, name: "拖动至主操作后吸附：\(size)")
        XCTAssertLessThanOrEqual(abs(capsule.frame.maxX - (app.frame.maxX - 14)), 3)

        app.tabBars.buttons["计划"].tap()
        let add = app.buttons["添加计划或分组"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        assertAvoidance(capsule, action: add, in: app, name: "切换页面重新约束：\(size)")
        app.tabBars.buttons["训练"].tap()
        assertAvoidance(capsule, action: start, in: app, name: "回首页重新约束：\(size)")
        XCTAssertEqual(reads.value as? String, originalReads)
        capsule.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        reveal(weight, in: app)
        XCTAssertEqual(weight.value as? String, "63.75 公斤")
        XCTAssertTrue(complete.label.contains("已完成"))
        XCTAssertTrue(rest.exists)
        XCTAssertEqual(reads.value as? String, originalReads, "胶囊布局与继续训练不新增全量历史读取")
        minimize.tap()
        XCTAssertTrue(capsule.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(elapsed(from: capsule.label), elapsedBefore)
        XCTAssertTrue(app.tabBars.buttons["训练"].isSelected)
    }

    @MainActor private func assertAvoidance(_ capsule: XCUIElement, action: XCUIElement,
                                           in app: XCUIApplication, name: String) {
        XCTAssertTrue(action.isHittable)
        XCTAssertFalse(capsule.frame.intersects(action.frame), "胶囊\(capsule.frame) 主操作\(action.frame)")
        XCTAssertFalse(capsule.frame.intersects(app.tabBars.firstMatch.frame))
        XCTAssertTrue(app.frame.contains(capsule.frame))
        XCTAssertGreaterThanOrEqual(capsule.frame.height + 0.001, 44)
        XCTAssertGreaterThanOrEqual(capsule.frame.width + 0.001, 44)
        print("[S3-capsule-geometry] \(name) capsule=\(capsule.frame) action=\(action.frame) tab=\(app.tabBars.firstMatch.frame)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func elapsed(from label: String) -> Int {
        let pattern = #"已进行 (\d+:\d+(?::\d+)?)"#
        let expression = try! NSRegularExpression(pattern: pattern)
        guard let match = expression.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
              let range = Range(match.range(at: 1), in: label) else { XCTFail("计时语义缺失：\(label)"); return -1 }
        return label[range].split(separator: ":").reduce(0) { $0 * 60 + (Int($1) ?? 0) }
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            let add = app.buttons["添加动作"].firstMatch
            let bottom = add.exists && add.isHittable ? add.frame.minY - 8 : app.frame.maxY - 100
            if element.exists && element.isHittable && element.frame.minY >= 125 && element.frame.maxY <= bottom { return }
            let down = element.exists && element.frame.minY < 125
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 240 : bottom - 20))
                .press(forDuration: 0, thenDragTo: origin.withOffset(CGVector(dx: app.frame.maxX - 9,
                                                                           dy: down ? 420 : bottom - 200)))
        }
        XCTFail("录入控件未完整显示")
    }
}
