import XCTest

/// 使用真实排序手柄移动后验证提交边界，数据仅在隔离 UI 测试库中。
final class ReorderDraftUITests: XCTestCase {
    private enum Host { case groups, plans, planItems, live }
    private let planName = "UI 大字计划 · 胸背力量与训练复盘"
    private let groupName = "UI 大字分组 · 长期力量与稳定控制"
    private let exerciseName = "UI 大字坐姿器械胸部推举与稳定控制训练"

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testGroupsCancelCommitAndRetryAtDefaultSize() throws { check(.groups, size: "large", failingSave: true) }
    @MainActor func testGroupsCancelAndCommitAtLargestSize() throws { check(.groups, size: "accessibility5") }
    @MainActor func testPlansCancelCommitAndRetryAtDefaultSize() throws { check(.plans, size: "large", failingSave: true) }
    @MainActor func testPlansCancelAndCommitAtLargestSize() throws { check(.plans, size: "accessibility5") }
    @MainActor func testPlanItemsCancelCommitAndRetryAtDefaultSize() throws { check(.planItems, size: "large", failingSave: true) }
    @MainActor func testPlanItemsCancelAndCommitAtLargestSize() throws { check(.planItems, size: "accessibility5") }
    @MainActor func testLiveCancelCommitAndRetryAtDefaultSize() throws { check(.live, size: "large", failingSave: true) }
    @MainActor func testLiveCancelAndCommitAtLargestSize() throws { check(.live, size: "accessibility5") }

    @MainActor func testPlanItemMoveThenCancelKeepsOriginalOrder() throws {
        let app = launch()
        openPlan(in: app)
        reveal(app.buttons["调整动作顺序"], in: app)
        app.buttons["调整动作顺序"].tap()
        moveSecondBeforeFirst(in: app)
        let cancel = app.buttons["取消排序"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "移动后的草稿必须有显式取消入口")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.item."))
        XCTAssertTrue(rows.element(boundBy: 0).label.hasPrefix(exerciseName + "，"))
    }

    @MainActor private func launch(size: String = "large", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-plan-readability", "-uitest-reorder-draft", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size] + extra
        app.launch()
        let tab = app.tabBars.buttons["计划"]
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        return app
    }

    @MainActor private func check(_ host: Host, size: String, failingSave: Bool = false) {
        let app = launch(size: size, extra: failingSave ? ["-uitest-fail-reorder-save"] : [])
        var weight: XCUIElement?
        if host == .planItems || host == .live { openPlan(in: app) }
        if host == .live {
            let start = app.buttons["开始这次训练"]
            reveal(start, in: app)
            start.tap()
            XCTAssertTrue(app.buttons["收起训练"].waitForExistence(timeout: 5))
            let field = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "组 重量")).firstMatch
            reveal(field, in: app, avoidAddBar: true)
            field.tap()
            XCTAssertTrue(app.buttons["数字 6"].waitForExistence(timeout: 5))
            for key in ["数字 6", "数字 3", "小数点", "数字 7", "数字 5"] { app.buttons[key].tap() }
            XCTAssertEqual(field.value as? String, "63.75 公斤")
            app.buttons["收起键盘"].tap()
            weight = field
        }

        openSort(host, in: app)
        let original = handleLabels(in: app)
        let expectedTitles: [String]
        switch host {
        case .groups: expectedTitles = [groupName, "UI 大字分组 · 排序对照"]
        case .plans: expectedTitles = [planName, "UI 大字计划 · 排序对照"]
        case .planItems, .live: expectedTitles = [exerciseName, "杠铃卧推"]
        }
        for index in 0..<2 {
            XCTAssertTrue(original[index].contains(expectedTitles[index]), "原生移动控件必须读出具体对象：\(original)")
        }
        moveSecondBeforeFirst(in: app)
        let moved = handleLabels(in: app)
        XCTAssertEqual(moved, [original[1], original[0]] + Array(original.dropFirst(2)))
        capture("\(host) 实际移动后可取消：\(size)", in: app)
        app.buttons["取消排序"].tap()
        XCTAssertTrue(app.buttons["完成排序"].waitForNonExistence(timeout: 5))

        openSort(host, in: app)
        XCTAssertEqual(handleLabels(in: app), original, "取消必须保持模型原顺序")
        moveSecondBeforeFirst(in: app)
        trySwipeDismiss(in: app)
        XCTAssertEqual(handleLabels(in: app), moved, "下滑不退出或隐式提交草稿")
        let done = app.buttons["完成排序"]
        done.tap()
        if failingSave {
            let error = app.staticTexts["localSave.error"]
            XCTAssertTrue(error.waitForExistence(timeout: 5))
            XCTAssertTrue(error.label.contains("草稿仍保留"))
            XCTAssertEqual(handleLabels(in: app), moved)
            XCTAssertTrue(done.isHittable)
            capture("\(host) 保存失败保留排序草稿", in: app)
            done.tap()
        }
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        openSort(host, in: app)
        XCTAssertEqual(handleLabels(in: app), moved, "完成后再次打开仍是新顺序")
        capture("\(host) 排序已可靠保存：\(size)", in: app)
        app.buttons["取消排序"].tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))

        if let weight {
            let expand = app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "展开动作", exerciseName)).firstMatch
            if expand.exists {
                reveal(expand, in: app, avoidAddBar: true)
                expand.tap()
            }
            reveal(weight, in: app, avoidAddBar: true)
            XCTAssertEqual(weight.value as? String, "63.75 公斤")
            app.buttons["收起训练"].tap()
            XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5), "收起后回到原计划详情")
            openSort(.planItems, in: app)
            XCTAssertTrue(handleLabels(in: app).first?.contains(exerciseName) == true, "训练排序不改来源计划")
            app.buttons["取消排序"].tap()
        }
    }

    @MainActor private func openSort(_ host: Host, in app: XCUIApplication) {
        switch host {
        case .groups:
            let menu = app.buttons["添加计划或分组"]
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            menu.tap()
            app.buttons["调整分组顺序"].tap()
        case .plans:
            let menu = app.buttons[groupName + "更多操作"]
            reveal(menu, in: app)
            menu.tap()
            app.buttons["调整计划顺序"].tap()
        case .planItems:
            let sort = app.buttons["调整动作顺序"]
            reveal(sort, in: app)
            sort.tap()
        case .live:
            let sort = app.buttons["调整训练动作顺序"]
            reveal(sort, in: app)
            sort.tap()
        }
        let done = app.buttons["完成排序"]
        let cancel = app.buttons["取消排序"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.exists)
        for button in [done, cancel] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height + 0.001, 44)
            XCTAssertTrue(app.frame.contains(button.frame))
        }
    }

    @MainActor private func handleLabels(in app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder ")).allElementsBoundByIndex.map(\.label)
    }

    @MainActor private func trySwipeDismiss(in app: XCUIApplication) {
        let grabber = app.buttons["Sheet Grabber"]
        XCTAssertTrue(grabber.exists)
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)),
                   withVelocity: .fast, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["取消排序"].isHittable, "下滑不能关闭排序面板")
    }

    @MainActor private func openPlan(in app: XCUIApplication) {
        let group = app.buttons["展开" + groupName]
        reveal(group, in: app)
        group.tap()
        let plan = app.buttons["打开计划" + planName]
        reveal(plan, in: app)
        plan.tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
    }

    @MainActor private func moveSecondBeforeFirst(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["完成排序"].waitForExistence(timeout: 5))
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder "))
        XCTAssertGreaterThanOrEqual(handles.count, 2)
        let from = app.buttons[handles.element(boundBy: 1).label]
        let to = app.buttons[handles.element(boundBy: 0).label]
        XCTAssertTrue(from.waitForExistence(timeout: 3))
        XCTAssertTrue(to.waitForExistence(timeout: 5))
        reveal(from, in: app)
        from.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: to.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)),
                   withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertLessThan(from.frame.minY, to.frame.minY, "必须确实移动草稿顺序")
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, avoidAddBar: Bool = false) {
        for _ in 0..<20 {
            let done = app.buttons["完成排序"]
            let top = done.exists ? done.frame.maxY + 8 : 114
            let tab = app.tabBars.firstMatch
            var bottom = !done.exists && tab.exists && tab.isHittable ? tab.frame.minY - 8 : app.frame.maxY - 34
            let add = app.buttons["添加动作"].firstMatch
            if (avoidAddBar || app.buttons["收起训练"].exists) && !done.exists && add.exists && add.isHittable {
                bottom = min(bottom, add.frame.minY - 8)
            }
            let isFooter = element.exists && ["开始这次训练", "复制"].contains(element.label)
            if !done.exists && !app.buttons["收起训练"].exists && !isFooter {
                for name in ["复制", "开始这次训练"] {
                    let button = app.buttons[name]
                    if button.exists && button.isHittable { bottom = min(bottom, button.frame.minY - 8) }
                }
            }
            if element.exists && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let down = element.exists && element.frame.minY < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? top + 30 : bottom - 30))
                .press(forDuration: 0, thenDragTo: origin.withOffset(CGVector(dx: app.frame.maxX - 9,
                                                                           dy: down ? top + 190 : bottom - 190)))
        }
        XCTFail("排序目标未完整滚入可见区域：\(element)，frame=\(element.frame)，hittable=\(element.isHittable)")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
