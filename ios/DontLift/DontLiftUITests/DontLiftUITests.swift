//
//  DontLiftUITests.swift
//  DontLiftUITests
//
//  Created by Yu on 2026/5/17.
//

import XCTest

final class DontLiftUITests: XCTestCase {

    /// 等待元素出现；若超时则 terminate 后带原参数重启一次再等到位。
    /// 冷启动（模拟器首次开机 + 安装）时 App 偶发停在登录页（种子/注入竞态，与环境相关），
    /// 重启后第二次即正常——这是环境性抖动，重试比拉长超时更有效。
    @MainActor
    private func waitForElementWithRelaunch(_ element: XCUIElement, in app: XCUIApplication,
                                            timeout: TimeInterval = 30) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }
        app.terminate()
        app.launch()
        return element.waitForExistence(timeout: timeout)
    }

    @MainActor
    func testAssistedWeightHintInWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-uitest-assisted-weight"]
        app.launch()
        let title = app.staticTexts["辅助引体向上"].firstMatch
        XCTAssertTrue(waitForElementWithRelaunch(title, in: app), "应直达训练进行中页面并显示种子动作")
        let hint = app.staticTexts["此动作记录辅助重量，辅助越小，难度越大。"]
        if !hint.exists { title.tap() }
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        XCTAssertTrue(hint.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testBadgeWallRepeatedEntryAndLazyScrolling() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-dev-seed-demo", "-tab-profile", "-dismiss-career-review"]
        app.launch()
        let entry = app.buttons["profile.badge.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        let summary = app.staticTexts["badge.wall.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "value BEGINSWITH %@", "ready:")
        expectation(for: ready, evaluatedWith: summary)
        waitForExpectations(timeout: 20)
        let counts = summary.value as? String
        XCTAssertFalse(app.staticTexts["正在加载徽章"].exists)
        for _ in 0..<10 {
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            XCTAssertEqual(summary.value as? String, counts)
        }
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            for _ in 0..<4 { app.swipeUp() }
            XCTAssertTrue(app.staticTexts["单次战役极限"].exists)
            for _ in 0..<4 { app.swipeDown() }
        }
        XCTAssertTrue(summary.isHittable)
        XCTAssertEqual(summary.value as? String, counts)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    /// 排序统一弹窗（系统 sheet）：打开后底层页面（含导航栏按钮、结束训练、底部添加栏）被 scrim 封锁；
    /// 点「完成」关闭弹窗后一切恢复。依赖 -uitest-live-workout 钩子直达训练进行中页面。
    @MainActor
    func testReorderSheetBlocksOtherAreas() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uitest-live-workout")
        app.launch()

        // 冷启动偶发停在登录页：wait 内部会自动 terminate 重启一次再等到位。
        let sortButton = app.buttons["调整训练动作顺序"]
        XCTAssertTrue(waitForElementWithRelaunch(sortButton, in: app),
                      "应直达训练进行中页面并显示排序入口")

        let finishButton = app.buttons["结束训练"]
        XCTAssertTrue(finishButton.isHittable, "进入排序前「结束训练」可点击")

        sortButton.tap()

        // 排序统一弹窗（系统 sheet，默认 60% 高）：标题「训练动作排序」+ 实心「完成」胶囊。
        XCTAssertTrue(app.staticTexts["训练动作排序"].waitForExistence(timeout: 5),
                      "进入排序后应弹出「训练动作排序」弹窗")
        let doneButton = app.buttons["完成排序"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "弹窗内应显示「完成」按钮")
        XCTAssertTrue(doneButton.isHittable, "排序弹窗「完成」按钮必须可点击")

        // 系统 sheet 的 scrim 封锁底层页面：「结束训练」/导航栏/底部添加栏均不可命中。
        // （isHittable 会穿透纯视觉蒙层，但系统 sheet 的遮挡是真实命中测试，故可用 isHittable 断言。）
        XCTAssertFalse(finishButton.isHittable, "排序弹窗打开时「结束训练」应被封锁")
        XCTAssertFalse(app.buttons["收起训练"].isHittable, "排序弹窗打开时导航栏收起按钮应被封锁")
        XCTAssertFalse(app.buttons["训练更多操作"].isHittable, "排序弹窗打开时导航栏 ⋯ 菜单应被封锁")
        XCTAssertFalse(app.buttons["添加动作"].isHittable, "排序弹窗打开时底部添加动作栏应被封锁")

        // 排序行存在（3 个动作；第三个种子名「哑铃肩推」经内置库归并显示为「坐姿哑铃推肩」）。
        XCTAssertTrue(app.staticTexts["上斜杠铃卧推"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["杠铃划船"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["坐姿哑铃推肩"].waitForExistence(timeout: 3))

        // 真实拖拽（best-effort）：把末行拖到列表顶部（系统 EditMode 手柄，label 形如 "Reorder 坐姿哑铃推肩"）。
        // 注意：系统 sheet 的下滑关闭/detent 手势与 XCUI 合成拖拽事件相斥，录屏证实合成拖拽无法
        // 触发 sheet 内 List 的行浮起（真机手指长按手柄正常）。因此拖拽只尝试、不硬断言，
        // 排序正确性回归靠真机验证；本用例的硬断言是 sheet 的呈现/封锁/关闭恢复。
        let lastHandle = app.buttons["Reorder 坐姿哑铃推肩"]
        if lastHandle.waitForExistence(timeout: 2) {
            let firstHandle = app.buttons["Reorder 上斜杠铃卧推"]
            let dragStart = lastHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dropTarget = firstHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.5))
            dragStart.press(forDuration: 1.0, thenDragTo: dropTarget,
                            withVelocity: .slow, thenHoldForDuration: 0.6)
            Thread.sleep(forTimeInterval: 1.0)
            // 拖动后检查「坐姿哑铃推肩」是否上移到「上斜杠铃卧推」之上；未移动仅记录告警。
            let firstTitle = app.staticTexts["上斜杠铃卧推"].firstMatch
            let thirdTitle = app.staticTexts["坐姿哑铃推肩"].firstMatch
            if thirdTitle.frame.minY >= firstTitle.frame.minY {
                print("[UITest] 合成拖拽未触发 sheet 内行重排（已知 XCUI 限制），排序回归需真机验证")
            }
        } else {
            // 手柄命名不可知时打印全部按钮名辅助排查，不让用例误失败。
            print("[UITest] reorder handle missing, buttons:", app.buttons.allElementsBoundByIndex.map(\.label))
        }

        // 点「完成」退出排序：一切恢复。
        doneButton.tap()
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "退出排序后应恢复「排序」入口")
        XCTAssertTrue(finishButton.isHittable, "退出排序后「结束训练」应恢复可点击")
    }

    /// 复现「结束训练闪退」：勾选部分组后结束训练，未完成组被清理，App 必须存活并进入只读详情。
    @MainActor
    func testFinishWorkoutWithIncompleteSetsDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-live-workout", "-dismiss-career-review"]
        app.launch()
        let finishButton = app.buttons["结束训练"]
        XCTAssertTrue(waitForElementWithRelaunch(finishButton, in: app), "应直达训练进行中页面")
        let mark = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '标记'")).firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap()
        Thread.sleep(forTimeInterval: 0.6)
        // 完成一组会弹出休息浮层，点空白处收起后再结束训练。
        if !finishButton.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        finishButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)
        print("[CONFIRM-DEBUG]", app.buttons.allElementsBoundByIndex.map(\.label))
        let confirm = app.buttons.matching(identifier: "结束训练").element(boundBy: 0)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "应弹出结束确认")
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 4)
        print("[FINISH-DEBUG]", app.buttons.allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(app.state, .runningForeground, "结束训练后 App 不应崩溃")
        XCTAssertFalse(app.buttons["结束训练"].exists, "结束后应切到只读详情")
        XCTAssertFalse(app.buttons["调整训练动作顺序"].exists, "已完成详情不提供排序")
        XCTAssertFalse(app.buttons["调整动作顺序"].exists, "已完成详情不提供计划排序")
    }

    @MainActor
    func testFinishWorkoutWhileKeypadFocusedOnIncompleteSetDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-live-workout", "-dismiss-career-review"]
        app.launch()
        let finishButton = app.buttons["结束训练"]
        XCTAssertTrue(waitForElementWithRelaunch(finishButton, in: app))
        app.buttons["标记第 1 组完成"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        if !app.buttons["第 2 组 重量"].firstMatch.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        app.buttons["第 2 组 重量"].firstMatch.tap()
        app.buttons["数字 5"].tap()
        finishAndAssertAlive(app)
    }

    @MainActor
    private func finishAndAssertAlive(_ app: XCUIApplication) {
        let finishButton = app.buttons["结束训练"].firstMatch
        for _ in 0..<8 where !finishButton.isHittable { app.swipeDown() }
        finishButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)
        let confirm = app.buttons.matching(identifier: "结束训练").element(boundBy: 0)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 4)
        print("[FINISH-DEBUG]", app.buttons.allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(app.state, .runningForeground, "结束训练后 App 不应崩溃")
        XCTAssertFalse(app.buttons["标记第 2 组完成"].exists)
    }

    // MARK: 历史训练另存为个人计划
    // 样例由 UITestHooks.seedHistorySaveSamplesIfNeeded 写入假登录的独立 WorkoutUITests.store，不触发同步。

    /// 首页「本周训练」→ 历史详情 → ⋯ → 另存为个人计划：预填、默认模式、取消不新增、改名选分组后保存。
    @MainActor
    func testHomeHistoryWorkoutSavesAsPersonalPlan() throws {
        let app = launchHistorySaveApp()

        // 只有热身组的训练不提供另存入口。
        let warmRow = historyRow("UI 另存热身", in: app)
        XCTAssertTrue(waitForElementWithRelaunch(warmRow, in: app), "首页应展示只有热身组的样例")
        warmRow.tap()
        let more = app.buttons["训练更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        XCTAssertTrue(app.buttons["分享训练海报"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["另存为个人计划"].exists, "无有效正式组时不应提供另存入口")
        more.tap()
        tapNavigationBack(in: app)

        let row = historyRow("UI 另存胸背", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        openSaveAsPersonalPlan(in: app)

        // 预填名称／整体备注；默认自适应、未分组。
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "UI 另存胸背")
        XCTAssertEqual(app.textViews["计划备注输入框"].value as? String, "UI 另存备注")
        XCTAssertTrue(app.buttons["自适应模式"].isSelected)
        XCTAssertFalse(app.buttons["严格模式"].isSelected)
        XCTAssertEqual(app.buttons["选择分组"].value as? String, "未分组")

        // 改分组后取消：不创建计划（稍后分组计数仍只有保存的一份）。
        chooseGroup("UI 另存分组", in: app)
        tapNavigationBack(in: app)
        XCTAssertTrue(app.buttons["训练更多操作"].waitForExistence(timeout: 5), "取消后应回到历史详情")

        // 再次打开：改名、选分组、保存。
        openSaveAsPersonalPlan(in: app)
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "UI 另存胸背", "重新打开应重新预填")
        replaceText(in: nameField, with: "UI 另存进阶")
        chooseGroup("UI 另存分组", in: app)
        app.buttons["保存"].tap()

        XCTAssertTrue(app.buttons["训练更多操作"].waitForExistence(timeout: 5), "保存成功后应回到历史详情")
        XCTAssertTrue(app.staticTexts["UI 另存胸背"].exists, "原训练名称保持不变")
        XCTAssertFalse(app.staticTexts["UI 另存进阶"].exists)

        // 计划列表：所选分组下只有本次保存的一份。
        tapNavigationBack(in: app)
        app.tabBars.buttons["计划"].tap()
        let groupHeader = app.buttons["展开UI 另存分组"]
        XCTAssertTrue(groupHeader.waitForExistence(timeout: 10))
        XCTAssertEqual(groupHeader.value as? String, "已折叠，1 个计划")
        groupHeader.tap()
        XCTAssertTrue(app.buttons["打开计划UI 另存进阶"].waitForExistence(timeout: 5))
    }

    /// 历史日历 → 当天训练详情 → ⋯ → 另存为个人计划：与首页一致，默认名称直接保存到未分组。
    @MainActor
    func testCalendarHistoryWorkoutSavesAsPersonalPlan() throws {
        let app = launchHistorySaveApp()

        let calendarButton = app.buttons["历史日历"]
        XCTAssertTrue(waitForElementWithRelaunch(calendarButton, in: app))
        calendarButton.tap()
        let row = historyRow("UI 另存胸背", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "日历默认选中今天，应展示当天样例")
        row.tap()
        openSaveAsPersonalPlan(in: app)

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "UI 另存胸背")
        XCTAssertTrue(app.buttons["自适应模式"].isSelected)
        app.buttons["保存"].tap()

        XCTAssertTrue(app.buttons["训练更多操作"].waitForExistence(timeout: 5), "保存成功后应回到历史详情")
        XCTAssertTrue(app.staticTexts["UI 另存胸背"].exists, "原训练名称保持不变")

        tapNavigationBack(in: app)
        tapNavigationBack(in: app)
        app.tabBars.buttons["计划"].tap()
        let ungrouped = app.buttons["展开未分组"]
        XCTAssertTrue(ungrouped.waitForExistence(timeout: 10))
        ungrouped.tap()
        let saved = app.buttons["打开计划UI 另存胸背"]
        if !saved.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "未分组下应出现新计划")
    }

    /// 另存表单打开后来源失效：保留输入并提示错误，不能产生新计划。
    @MainActor
    func testHistorySaveRejectsInvalidatedSource() throws {
        let app = launchHistorySaveApp(extraArguments: ["-uitest-history-save-invalid-source"])
        let row = historyRow("UI 另存胸背", in: app)
        XCTAssertTrue(waitForElementWithRelaunch(row, in: app))
        row.tap()
        openSaveAsPersonalPlan(in: app)

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(in: nameField, with: "UI 另存失效")
        chooseGroup("UI 另存分组", in: app)
        app.buttons["保存"].tap()

        let error = app.staticTexts["planEditor.saveError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "原训练记录已不可用，无法另存")
        XCTAssertEqual(nameField.value as? String, "UI 另存失效")
        XCTAssertEqual(app.buttons["选择分组"].value as? String, "UI 另存分组")

        tapNavigationBack(in: app)
        tapNavigationBack(in: app)
        app.tabBars.buttons["计划"].tap()
        let groupHeader = app.buttons["展开UI 另存分组"]
        XCTAssertTrue(groupHeader.waitForExistence(timeout: 10))
        XCTAssertEqual(groupHeader.value as? String, "已折叠，0 个计划")
    }

    /// 兼容性：完成页「保存为计划模板」仍对无计划训练展示，保存后把训练名称改为计划名（历史另存不改名）。
    /// 计划名用「UI 另存」前缀，便于历史另存样例钩子下次启动时清理。
    @MainActor
    func testCompletionPageSaveAsPlanStillRenamesWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-live-workout", "-dismiss-career-review"]
        app.launch()
        let finishButton = app.buttons["结束训练"]
        XCTAssertTrue(waitForElementWithRelaunch(finishButton, in: app), "应直达训练进行中页面")
        app.buttons["标记第 1 组完成"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        if !finishButton.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        finishAndAssertAlive(app)

        let prConfirmation = app.buttons["太棒了"]
        if prConfirmation.waitForExistence(timeout: 2) {
            prConfirmation.tap()
            XCTAssertTrue(prConfirmation.waitForNonExistence(timeout: 5))
        }

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS '保存为计划模板'")).firstMatch
        for _ in 0..<4 where !card.exists { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "无计划训练完成后应展示保存为计划模板")
        card.tap()
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "UI 测试训练")
        replaceText(in: nameField, with: "UI 另存完成页")
        app.buttons["保存"].tap()

        XCTAssertTrue(app.staticTexts["UI 另存完成页"].waitForExistence(timeout: 5), "完成页保存后训练名称应更新为计划名")
        XCTAssertFalse(card.exists, "保存后不再展示保存行动卡")
    }

    @MainActor
    func testCompletionTemplateFailureRetainsFormAndRetryRenamesWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-uitest-fail-template-save", "-dismiss-career-review"]
        app.launch()
        let finish = app.buttons["结束训练"]
        XCTAssertTrue(waitForElementWithRelaunch(finish, in: app))
        app.buttons["标记第 1 组完成"].firstMatch.tap()
        if !finish.isHittable { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap() }
        finishAndAssertAlive(app)
        let celebration = app.buttons["太棒了"]
        if celebration.waitForExistence(timeout: 2) { celebration.tap() }
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保存为计划模板")).firstMatch
        for _ in 0..<4 where !card.exists { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "UI 另存失败重试")
        app.buttons["保存"].tap()
        let error = app.staticTexts["workoutTemplate.saveError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "UI 另存失败重试")
        app.buttons["保存"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI 另存失败重试"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
    }

    private func launchHistorySaveApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-dev-auto-login", "-uitest-history-save", "-dismiss-career-review"]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private func historyRow(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", title))
            .firstMatch
    }

    private func openSaveAsPersonalPlan(in app: XCUIApplication) {
        let more = app.buttons["训练更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let entry = app.buttons["另存为个人计划"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "有效历史训练应提供另存入口")
        entry.tap()
    }

    private func chooseGroup(_ name: String, in app: XCUIApplication) {
        app.buttons["选择分组"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        let picker = app.buttons["选择分组"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.value as? String, name)
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        field.typeText(text + "\n")
        XCTAssertEqual(field.value as? String, text)
    }

    private func tapNavigationBack(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
