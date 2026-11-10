import XCTest

final class WorkoutFinishFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testMultipleResultsFinishAndReturnBaseline() throws {
        let app = launch()
        finishAndCloseResults(in: app)
        let back = app.buttons["关闭"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["结束训练"].exists)
        back.tap()
        XCTAssertTrue(app.buttons["开始训练"].firstMatch.waitForExistence(timeout: 5))
        print("[S3-finish-flow] finish=2 taps; result dismissals=3 taps; return=1 tap; optional sharing=0 taps")
        capture("关闭全部结果后可直接回首页", in: app)
    }

    @MainActor func testPlanUpdateReceiptCanReopenAfterResults() throws {
        checkReopen(extra: [])
    }

    @MainActor func testPlanUpdateReceiptAtLargestSize() throws {
        checkReopen(extra: ["-uitest-typography-size", "accessibility5"])
    }

    @MainActor func testSlowResultsStaySingleAndReceiptCanReopen() throws {
        checkReopen(extra: ["-uitest-finish-slow-history"])
    }

    @MainActor func testReopenedReceiptUndoAtDefaultSize() throws { checkUndo(size: "large") }
    @MainActor func testReopenedReceiptUndoAtLargestSize() throws { checkUndo(size: "accessibility5") }

    @MainActor func testStrictCompletionKeepsOriginalPrescription() throws {
        let app = launch(extra: ["-uitest-finish-strict"])
        finishAndCloseResults(in: app, expectsReceipt: false)
        XCTAssertFalse(app.buttons["查看计划更新"].exists)
        app.buttons["关闭"].firstMatch.tap()
        assertOriginalPlan(name: "UI 收尾严格计划", in: app)
    }

    @MainActor private func checkUndo(size: String) {
        let app = launch(extra: ["-uitest-typography-size", size])
        finishAndCloseResults(in: app)
        let entry = app.buttons["查看计划更新"]
        reveal(entry, in: app)
        entry.tap()
        let undo = app.buttons["撤销此次更新"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(undo.isHittable)
        XCTAssertGreaterThanOrEqual(undo.frame.height + 0.001, 44)
        undo.tap()
        XCTAssertTrue(app.staticTexts["已更新计划"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(entry.exists, "撤销成功后不再提供旧回执入口")
        app.buttons["关闭"].firstMatch.tap()
        assertOriginalPlan(name: "UI 收尾自适应计划", in: app)
    }

    @MainActor private func assertOriginalPlan(name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons["计划"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        let group = app.buttons["展开未分组"]
        if group.exists { reveal(group, in: app); group.tap() }
        let plan = app.buttons["打开计划" + name].firstMatch
        reveal(plan, in: app)
        plan.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.item.")).firstMatch
        reveal(row, in: app)
        XCTAssertTrue(row.label.contains("15 组") && row.label.contains("8 次"), "计划保持原处方：\(row.label)")
        capture("原计划处方仍为15组×8次", in: app)
    }

    @MainActor private func checkReopen(extra: [String]) {
        let app = launch(extra: extra)
        finishAndCloseResults(in: app)
        let receipt = app.buttons["查看计划更新"]
        XCTAssertTrue(receipt.waitForExistence(timeout: 5), "关闭即时反馈后仍能查看回执并决定是否撤销")
        reveal(receipt, in: app)
        XCTAssertGreaterThanOrEqual(receipt.frame.height + 0.001, 44)
        receipt.tap()
        XCTAssertTrue(app.staticTexts["已更新计划"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["撤销此次更新"].exists)
        assertSingleResult(in: app)
        capture("关闭奖励后重新查看计划回执", in: app)
        let details = app.scrollViews["planWriteback.details"]
        XCTAssertTrue(details.exists)
        details.swipeUp()
        XCTAssertTrue(app.buttons["撤销此次更新"].isHittable)
        capture("回执详情可滚动，操作区保持可达", in: app)
        app.buttons["好"].tap()
        XCTAssertTrue(app.staticTexts["已更新计划"].waitForNonExistence(timeout: 5))
        app.buttons["关闭"].firstMatch.tap()
        XCTAssertTrue(app.buttons["开始训练"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow",
                               "-uitest-history-loading", "-uitest-team-readability", "-dismiss-career-review"] + extra
        app.launch()
        XCTAssertTrue(waitForIsolatedUITestScene(app.buttons["结束训练"], in: app))
        return app
    }

    @MainActor private func finishAndCloseResults(in app: XCUIApplication, expectsReceipt: Bool = true) {
        app.buttons["结束训练"].tap()
        XCTAssertTrue(app.staticTexts["结束训练?"].waitForExistence(timeout: 5))
        app.buttons["结束训练"].firstMatch.tap()
        let receipt = app.staticTexts["已更新计划"]
        var sequence: [String] = []
        if expectsReceipt {
            XCTAssertTrue(receipt.waitForExistence(timeout: 10))
            assertSingleResult(in: app)
            sequence.append("计划回写")
            capture("完成后的第一项反馈：计划回写", in: app)
            app.buttons["好"].tap()
        }
        var seen = Set<String>()
        for _ in 0..<2 {
            let pr = app.buttons["太棒了"]
            let badge = app.buttons["收下荣誉"]
            let next = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in pr.exists || badge.exists }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [next], timeout: 20), .completed)
            if !expectsReceipt { XCTAssertFalse(receipt.exists) }
            assertSingleResult(in: app)
            let name = pr.exists ? "PR" : "徽章"
            XCTAssertTrue(seen.insert(name).inserted, "同一反馈不能重复弹出")
            sequence.append(name)
            capture("实际收尾顺序第\(sequence.count)项：\(name)", in: app)
            let close = pr.exists ? pr : badge
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        }
        XCTAssertEqual(seen, ["PR", "徽章"])
        XCTAssertTrue(app.buttons["收下荣誉"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["太棒了"].waitForNonExistence(timeout: 5))
        print("[S3-finish-flow] sequence=" + sequence.joined(separator: " -> "))
    }

    @MainActor private func assertSingleResult(in app: XCUIApplication) {
        let visible = ["好", "太棒了", "收下荣誉"].filter {
            let button = app.buttons[$0]
            return button.exists && button.isHittable
        }
        XCTAssertEqual(visible.count, 1, "同一时刻仅有一个可操作结果模态：\(visible)")
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<14 {
            var bottom = app.frame.maxY - 34
            let tab = app.tabBars.firstMatch
            if tab.exists && tab.isHittable { bottom = min(bottom, tab.frame.minY - 8) }
            for name in ["复制", "开始这次训练", "添加计划或分组"] {
                let footer = app.buttons[name].firstMatch
                if footer.exists && footer.isHittable { bottom = min(bottom, footer.frame.minY - 8) }
            }
            if element.exists && element.isHittable && element.frame.minY >= 114 && element.frame.maxY <= bottom { return }
            let down = element.exists && element.frame.minY < 114
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 250 : bottom - 20))
                .press(forDuration: 0, thenDragTo: origin.withOffset(CGVector(dx: app.frame.maxX - 9,
                                                                           dy: down ? 430 : bottom - 200)))
        }
        XCTFail("完成页操作未完整滚入可用区域：\(element.frame)")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
