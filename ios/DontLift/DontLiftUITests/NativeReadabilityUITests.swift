import XCTest

/// 使用本 App scene 的原生字号 trait；仅假登录隔离库，不改设备字号或请求真实账号。
final class NativeReadabilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testCommonControlsAtDefaultReadingSize() throws {
        try checkCommonControls(size: "large")
    }

    @MainActor func testCommonControlsAtXXXLReadingSize() throws {
        try checkCommonControls(size: "xxxLarge")
    }

    @MainActor func testCommonControlsAtLargestReadingSize() throws {
        try checkCommonControls(size: "accessibility5")
    }

    @MainActor func testProfileSettingsHaveNamesAndActionsAtDefaultReadingSize() throws {
        try checkProfileSettings(size: "large")
    }

    @MainActor func testProfileSettingsHaveNamesAndActionsAtXXXLReadingSize() throws {
        try checkProfileSettings(size: "xxxLarge")
    }

    @MainActor func testProfileSettingsHaveNamesAndActionsAtLargestReadingSize() throws {
        try checkProfileSettings(size: "accessibility5")
    }

    @MainActor func testSyncStatesAtLargestReadingSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-sync-recovery", "-tab-profile",
                               "-clear-active-workout", "-dismiss-career-review",
                               "-uitest-typography-size", "accessibility5"]
        app.launch()
        XCTAssertTrue(waitForIsolatedUITestScene(app.buttons["profile.badge.entry"], in: app))
        let row = app.buttons["profile.sync"]
        func revealSyncRow() {
            revealUITestElement(row, in: app)
        }
        revealSyncRow()
        XCTAssertTrue(fullyVisible(row, in: app))
        for state in ["上次部分失败", "上次同步成功"] {
            row.tap()
            let result = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", state), object: row)
            XCTAssertEqual(XCTWaiter.wait(for: [result], timeout: 10), .completed)
            XCTAssertTrue(row.isEnabled)
            revealSyncRow()
            capture("同步结果与可读状态色：\(state)", app: app)
        }
    }

    @MainActor private func checkProfileSettings(size: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-tab-profile", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        XCTAssertTrue(waitForIsolatedUITestScene(app.buttons["profile.badge.entry"], in: app))
        capture("个人资料与徽章入口：\(size)", app: app)
        let estimate = app.switches["profile.calorieEstimate"]
        for _ in 0..<16 where !fullyVisible(estimate, in: app) { app.swipeUp() }
        XCTAssertTrue(estimate.isHittable)
        XCTAssertEqual(estimate.label, "消耗估算")
        for (identifier, name) in [("profile.haptics", "震动"), ("profile.sound", "声音")] {
            let control = app.switches[identifier]
            for _ in 0..<8 where !fullyVisible(control, in: app) { app.swipeUp() }
            XCTAssertTrue(control.isHittable)
            XCTAssertEqual(control.label, name)
            let previous = try XCTUnwrap(control.value as? String)
            control.tap()
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", previous), object: control)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
            capture("设置开关状态 \(name)：\(size)", app: app)
            control.tap()
            XCTAssertEqual(control.value as? String, previous)
        }
        let rest = app.buttons["profile.defaultRest"]
        for _ in 0..<12 where !fullyVisible(rest, in: app) { app.swipeDown() }
        XCTAssertTrue(rest.isHittable)
        let previous = rest.value as? String
        rest.tap()
        let cancel = app.buttons["取消"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable && app.buttons["完成"].isHittable)
        XCTAssertTrue(app.textFields["分钟"].isHittable)
        capture("默认休息编辑与取消：\(size)", app: app)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(rest.value as? String, previous)
    }

    @MainActor private func fullyVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let tab = app.tabBars.firstMatch
        let visibleTab = tab.exists && tab.isHittable
        let top = visibleTab && tab.frame.midY < app.frame.midY ? max(64, tab.frame.maxY + 8) : 64
        let bottom = visibleTab && tab.frame.midY > app.frame.midY ? tab.frame.minY - 8 : app.frame.maxY - 20
        return element.frame.minY >= top && element.frame.maxY <= bottom
    }

    @MainActor private func checkCommonControls(size: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-history-save", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["计划"].waitForExistence(timeout: 15))
        app.tabBars.buttons["计划"].tap()
        let add = app.buttons["添加计划或分组"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(add.frame.width, 44)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
        add.tap()
        let createPlan = app.buttons["新建计划"]
        let createGroup = app.buttons["新建分组"]
        XCTAssertTrue(createGroup.waitForExistence(timeout: 5))
        for item in [createPlan, createGroup] {
            XCTAssertTrue(item.isHittable)
            XCTAssertGreaterThanOrEqual(item.frame.height, 44)
            XCTAssertTrue(app.frame.contains(item.frame))
        }
        XCTAssertLessThanOrEqual(createPlan.frame.maxY, createGroup.frame.minY)
        capture("公共菜单：\(size)", app: app)
        createGroup.tap()
        let cancel = app.buttons["取消"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable)
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
        if size == "accessibility5" {
            let title = app.staticTexts["新建分组"]
            XCTAssertLessThanOrEqual(title.frame.maxY, cancel.frame.minY)
        }
        capture("公共 Sheet：\(size)", app: app)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launchArguments.append("-uitest-native-controls")
        app.launch()
        try checkIsolatedCommonControls(app: app, size: size)
    }

    @MainActor private func checkIsolatedCommonControls(app: XCUIApplication, size: String) throws {
        let plus = app.buttons["增加示例值"]
        let minus = app.buttons["减少示例值"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        for button in [plus, minus] {
            XCTAssertGreaterThanOrEqual(button.frame.width + 0.001, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height + 0.001, 44)
        }
        XCTAssertFalse(plus.frame.intersects(minus.frame))
        plus.tap()
        XCTAssertEqual(app.staticTexts["fixture.count"].label, "1")
        minus.tap()
        XCTAssertEqual(app.staticTexts["fixture.count"].label, "0")
        let chest = app.buttons["胸"]
        let back = app.buttons["背"]
        XCTAssertGreaterThanOrEqual(chest.frame.width, 44)
        XCTAssertGreaterThanOrEqual(chest.frame.height, 44)
        chest.tap()
        XCTAssertTrue(chest.isSelected)
        XCTAssertFalse(back.isSelected)
        XCTAssertFalse(chest.frame.intersects(back.frame))
        capture("公共圆钮与 Chip：\(size)", app: app)

        let menuButton = app.buttons["展开长操作菜单"]
        menuButton.tap()
        let first = app.buttons["为这次实际训练另存第1份个人计划"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        capture("长菜单：\(size)", app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5)).tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 5))
        menuButton.tap()
        let last = app.buttons["为这次实际训练另存第8份个人计划"]
        let menu = app.scrollViews["paper.actionMenu"]
        for _ in 0..<8 where !last.isHittable || !menu.frame.contains(last.frame) { menu.swipeUp() }
        XCTAssertTrue(last.isHittable)
        XCTAssertTrue(menu.frame.contains(last.frame))
        last.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "已选择第8项"),
                                                object: app.staticTexts["fixture.result"])
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)

        let openSheet = app.buttons["打开长标题表单"]
        openSheet.tap()
        let cancel = app.buttons["取消"]
        let confirm = app.buttons["确认保存个人计划"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable && confirm.isHittable)
        XCTAssertTrue(app.frame.contains(confirm.frame))
        capture("长标题与长操作 Sheet：\(size)", app: app)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["fixture.result"].label, "已选择第8项")
        openSheet.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["fixture.result"].label, "已确认长标题表单")
    }

    @MainActor func testPosterCanvasKeepsLayoutAndActionsWorkAtLargestReadingSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow", "-uitest-history-save", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", "accessibility5"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["训练"].waitForExistence(timeout: 15))
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "UI 另存胸背")).firstMatch
        let visibleRow = revealUITestElement(row, in: app, allowPartial: true)
        capture("小屏大字海报入口的可视区域", app: app)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: visibleRow.midX - app.frame.minX, dy: visibleRow.midY - app.frame.minY)).tap()
        let more = app.buttons["训练更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["分享训练海报"].tap()

        let preview = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "训练海报预览")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue((preview.value as? String)?.contains("UI 另存胸背") == true)
        let save = app.buttons["保存图片"]
        let share = app.buttons["分享"]
        XCTAssertTrue(save.isHittable && share.isHittable)
        capture("最大阅读字号：海报画布与页面操作", app: app)
        XCTAssertGreaterThan(share.frame.height, 48)
        XCTAssertGreaterThan(share.frame.width, app.frame.width / 2)
        let pageIndex = try XCTUnwrap((1...5).first {
            app.staticTexts["第 \($0) 个版式，共 5 个"].exists
        })
        let caption = app.staticTexts["第 \(pageIndex) 个版式，共 5 个"]
        XCTAssertLessThanOrEqual(caption.frame.maxY, save.frame.minY)
        let next = app.buttons["下一个海报版式"]
        let forward = next.isEnabled
        let adjacent = forward ? next : app.buttons["上一个海报版式"]
        XCTAssertTrue(adjacent.isEnabled)
        adjacent.tap()
        let targetIndex = pageIndex + (forward ? 1 : -1)
        XCTAssertTrue(app.staticTexts["第 \(targetIndex) 个版式，共 5 个"].waitForExistence(timeout: 5))
        share.tap()
        let copy = app.cells.matching(NSPredicate(format: "label == 'Copy' OR label == '拷贝' OR label == '复制'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "分享应打开系统图片分享面板；不选择任何外部目标")
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
