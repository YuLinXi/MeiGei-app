import XCTest

/// 仅使用假登录选择的隔离测试库；首次故障后，重试执行真实本地保存。
final class PersistenceRecoveryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testProfileNameSaveFailureRetainsInputAndRetryCommits() throws {
        let app = launchProfile(extra: ["-uitest-fail-profile-save"])
        let edit = app.buttons["编辑称呼"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        let field = app.textFields["profile.name.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        replaceText(in: field, with: "保存重试的称呼")
        app.buttons["profile.name.save"].tap()
        let retry = app.buttons["localSave.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "保存重试的称呼")
        XCTAssertTrue(app.buttons["profile.name.save"].exists)
        capture("称呼保存失败，输入保留", app: app)
        retry.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(edit.value as? String, "保存重试的称呼")
    }

    @MainActor func testProfileSexSaveFailureRestoresSelectionAndRetryCommits() throws {
        let app = launchProfile(extra: ["-uitest-fail-profile-save"])
        let female = app.buttons["性别：女"]
        let male = app.buttons["性别：男"]
        XCTAssertTrue(female.waitForExistence(timeout: 10))
        XCTAssertTrue(male.isSelected)
        female.tap()
        let retry = app.buttons["localSave.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(male.isSelected && !female.isSelected)
        capture("性别保存失败，原选择保留", app: app)
        retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        XCTAssertTrue(female.isSelected && !male.isSelected)
    }

    @MainActor func testCustomExerciseSaveFailureKeepsFormAndRetryCreatesOne() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-uitest-fail-exercise-save",
                               "-dismiss-career-review"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["动作"].waitForExistence(timeout: 15))
        app.tabBars.buttons["动作"].tap()
        app.buttons["添加自定义动作"].tap()
        let field = app.textFields["输入名称（必填）"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let name = "保存重试动作\(UUID().uuidString.prefix(6))"
        field.tap()
        field.typeText(name)
        app.buttons["保存"].tap()
        let error = app.staticTexts["localSave.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
        capture("动作保存失败，草稿保留", app: app)
        app.buttons["保存"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertFalse(error.exists)
        let custom = app.buttons["自定义"]
        if custom.exists { custom.tap() }
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: name).count, 1)
    }

    @MainActor private func launchProfile(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-tab-profile", "-clear-active-workout",
                               "-dismiss-career-review"] + extra
        app.launch()
        return app
    }

    @MainActor func testWritebackUndoFailureKeepsReceiptAndRetryClosesIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-uitest-writeback-recovery",
                               "-uitest-fail-writeback-save", "-dismiss-career-review"]
        app.launch()
        let undo = app.buttons["撤销此次更新"]
        XCTAssertTrue(undo.waitForExistence(timeout: 15))
        undo.tap()
        let error = app.staticTexts["localSave.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(undo.isHittable)
        capture("回写撤销失败，回执保留", app: app)
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5))
        XCTAssertFalse(error.exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testNewWorkoutSaveFailureStaysHomeAndRetryStarts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-uitest-fail-start-save",
                               "-dismiss-career-review"]
        app.launch()
        let start = app.buttons["开始训练"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "开始失败")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["收起训练"].exists)
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.buttons["收起训练"].waitForExistence(timeout: 10))
        let timer = app.buttons["workout.timer.start"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        timer.tap()
        XCTAssertTrue(app.buttons["结束训练"].waitForExistence(timeout: 10))
    }

    @MainActor func testPlanModeFailureRetainsDraftAndRetryApplies() throws {
        let app = launchPlanFixture()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "自适应模式")).firstMatch.tap()
        let strict = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "严格模式")).firstMatch
        XCTAssertTrue(strict.waitForExistence(timeout: 5))
        strict.tap()
        app.buttons["确定"].tap()
        app.buttons["确认切换"].tap()
        let error = app.staticTexts["localSave.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["确定"].exists)
        app.buttons["确定"].tap()
        app.buttons["确认切换"].tap()
        XCTAssertTrue(app.buttons["确定"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(error.exists)
        XCTAssertTrue(strict.exists)
    }

    @MainActor func testMoveGroupFailureKeepsPickerAndRetryMoves() throws {
        let app = launchPlanFixture()
        app.buttons["计划更多操作"].tap()
        app.buttons["移动到分组"].tap()
        let target = app.buttons["移动到UI 保存目标分组"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        let error = app.staticTexts["localSave.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(target.isHittable)
        target.tap()
        XCTAssertTrue(target.waitForNonExistence(timeout: 5))
        XCTAssertFalse(error.exists)
        XCTAssertTrue(app.buttons["计划更多操作"].exists)
    }

    @MainActor func testCreatePlanFailureKeepsNameAndRetryCreatesSinglePlan() throws {
        let app = launchPlanFixture(inDetail: false)
        app.buttons["添加计划或分组"].tap()
        app.buttons["新建计划"].tap()
        let name = app.textFields["计划名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UI 保存计划 · 新建\n")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["保存失败，请重试"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "UI 保存计划 · 新建")
        app.buttons["保存"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["添加计划或分组"].waitForExistence(timeout: 5))
        let group = app.buttons["展开未分组"]
        if group.exists { group.tap() }
        let plan = app.buttons["打开计划UI 保存计划 · 新建"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "打开计划UI 保存计划 · 新建").count, 1)
        plan.tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
    }

    @MainActor func testCopyPlanFailureLeavesNoCopyAndRetryCreatesSingleCopy() throws {
        let app = launchPlanFixture()
        func showList() {
            app.buttons["返回"].tap()
            XCTAssertTrue(app.buttons["添加计划或分组"].waitForExistence(timeout: 5))
            let group = app.buttons["展开未分组"]
            if group.exists { group.tap() }
        }
        let copyName = "打开计划UI 保存计划 · 副本"
        app.buttons["复制"].tap()
        let failure = app.descendants(matching: .any).matching(identifier: "复制失败，原计划仍保留，请重试").firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 5))
        showList()
        XCTAssertFalse(app.buttons[copyName].exists)
        let original = app.buttons["打开计划UI 保存计划"]
        XCTAssertTrue(original.isHittable)
        original.tap()
        app.buttons["复制"].tap()
        let success = app.descendants(matching: .any).matching(identifier: "已复制计划").firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 5))
        showList()
        let copy = app.buttons[copyName]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: copyName).count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "打开计划UI 保存计划").count, 1)
        copy.tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
    }

    @MainActor func testCreateGroupFailureKeepsNameAndRetryCreatesSingleGroup() throws {
        let app = launchPlanFixture(inDetail: false)
        app.buttons["添加计划或分组"].tap()
        app.buttons["新建分组"].tap()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UI 保存新分组")
        app.buttons["完成"].tap()
        let error = app.staticTexts["localSave.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "UI 保存新分组")
        app.buttons["完成"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        let group = app.buttons["展开UI 保存新分组"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "展开UI 保存新分组").count, 1)
    }

    @MainActor func testSyncFailureShowsResultAndRetrySucceeds() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-sync-recovery", "-tab-profile",
                               "-clear-active-workout", "-dismiss-career-review"]
        app.launch()
        let row = app.buttons["profile.sync"]
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.value as? String, "尚未同步")
        row.tap()
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 2), .completed)
        waitForValue("上次部分失败", of: row)
        XCTAssertTrue(row.isEnabled)
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.lifetime = .keepAlways
        add(failure)
        row.tap()
        waitForValue("上次同步成功", of: row)
        XCTAssertTrue(row.isEnabled)
    }

    @MainActor func testExistingPlanSaveFailureKeepsFormAndRetryReturnsToPlan() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-fail-plan-save",
                               "-clear-active-workout", "-dismiss-career-review"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["计划"].waitForExistence(timeout: 15))
        app.tabBars.buttons["计划"].tap()
        let plan = app.buttons["打开计划UI 保存计划"]
        if !plan.waitForExistence(timeout: 2) {
            let group = app.buttons["展开未分组"]
            XCTAssertTrue(group.waitForExistence(timeout: 5))
            group.tap()
        }
        if !plan.isHittable { app.swipeUp() }
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(in: name, with: "UI 保存计划重试")
        app.buttons["完成"].tap()
        let error = app.staticTexts["planEditor.saveError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "UI 保存计划重试")
        XCTAssertTrue(app.buttons["完成"].isEnabled)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        XCTAssertFalse(error.exists)
        XCTAssertFalse(name.exists)
        XCTAssertTrue(app.staticTexts["UI 保存计划重试"].exists)
    }

    @MainActor func testDebouncedInputFailureRetainsValueAndCanRetry() throws {
        let app = launchWorkout(extra: ["-uitest-fail-input-save", "-profile-workout",
                                        "-profile-history-count", "600"])
        let weight = app.buttons["第 1 组 重量"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        weight.tap()
        app.buttons["数字 7"].tap()
        app.buttons["收起键盘"].tap()
        let retry = app.buttons["workout.retrySave"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "7 公斤")
        XCTAssertTrue(app.staticTexts["workout.saveError"].exists)
        retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "7 公斤")
    }

    @MainActor func testFinishFailureKeepsTrainingAndRestThenRetryFinishes() throws {
        let app = launchWorkout(extra: ["-uitest-fail-lifecycle-save"])
        let mark = app.buttons["workout.set.complete.0"].firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 10))
        mark.tap()
        let finish = app.buttons["结束训练"].firstMatch
        if !finish.isHittable { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap() }
        finish.tap()
        let confirm = app.buttons.matching(identifier: "结束训练").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let retry = app.buttons["workout.retrySave"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(mark.exists && mark.label.contains("已完成"))
        XCTAssertTrue(app.buttons["第 2 组 重量"].firstMatch.exists, "失败不能清掉未完成组")
        XCTAssertTrue(app.buttons["休息计时，点按展开"].firstMatch.exists, "保存失败时休息仍在运行")
        retry.tap()
        XCTAssertTrue(finish.waitForNonExistence(timeout: 10))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor func testDiscardFailureKeepsTrainingAndRestThenRetryDiscards() throws {
        let app = launchWorkout(extra: ["-uitest-fail-lifecycle-save"])
        let weight = app.buttons["第 1 组 重量"].firstMatch
        revealUITestElement(weight, in: app)
        weight.tap()
        app.buttons["数字 6"].tap()
        app.buttons["数字 4"].tap()
        app.buttons["收起键盘"].tap()
        let mark = app.buttons["workout.set.complete.0"].firstMatch
        revealUITestElement(mark, in: app)
        mark.tap()
        let rest = app.buttons["休息计时，点按展开"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        app.buttons["训练更多操作"].tap()
        app.buttons["放弃此次训练"].tap()
        app.buttons["放弃训练"].tap()
        let retry = app.buttons["workout.retrySave"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "64 公斤")
        XCTAssertTrue(mark.label.contains("已完成"))
        XCTAssertTrue(rest.exists, "丢弃保存失败时保留休息")
        retry.tap()
        let minimize = app.buttons["收起训练"]
        XCTAssertTrue(minimize.waitForNonExistence(timeout: 10))
        XCTAssertFalse(rest.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 ")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI 测试训练")).firstMatch.exists,
                       "被丢弃的原训练不能进入历史列表")
        let start = app.buttons["开始训练"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["已有进行中的训练"].exists, "丢弃成功后不再有旧会话冲突")
        XCTAssertFalse(app.buttons["workout.set.complete.0"].exists, "随后开始的是新的空白训练")
    }

    @MainActor func testDeleteFailureKeepsDetailAndRetryDeletes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-history-save", "-uitest-fail-lifecycle-save",
                               "-dismiss-career-review"]
        app.launch()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "UI 另存胸背")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        let more = app.buttons["训练更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["删除训练"].tap()
        app.buttons["删除"].tap()
        let alert = app.alerts["未能删除训练"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(more.exists, "保存失败后详情仍在")
        alert.buttons["重试"].tap()
        XCTAssertTrue(more.waitForNonExistence(timeout: 10))
        XCTAssertFalse(row.exists)
    }

    @MainActor private func launchWorkout(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-dismiss-career-review"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["结束训练"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func launchPlanFixture(inDetail: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-fail-commit-save", "-clear-active-workout",
                               "-dismiss-career-review"]
        app.launch()
        let tab = mainTab("计划", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        guard inDetail else { return app }
        let plan = app.buttons["打开计划UI 保存计划"]
        if !plan.waitForExistence(timeout: 2) {
            let group = app.buttons["展开未分组"]
            XCTAssertTrue(group.waitForExistence(timeout: 5))
            if !group.isHittable { app.swipeUp() }
            group.tap()
        }
        if !plan.isHittable { app.swipeUp() }
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func waitForValue(_ value: String, of element: XCUIElement) {
        let result = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [result], timeout: 10), .completed)
    }

    @MainActor private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
