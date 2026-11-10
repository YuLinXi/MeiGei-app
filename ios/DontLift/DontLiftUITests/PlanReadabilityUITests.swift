import XCTest

/// 在隔离计划上操作真实详情与编辑器，不触碰日常计划或后端。
final class PlanReadabilityUITests: XCTestCase {
    private let planName = "UI 大字计划 · 胸背力量与训练复盘"
    private let groupName = "UI 大字分组 · 长期力量与稳定控制"
    private let exerciseName = "UI 大字坐姿器械胸部推举与稳定控制训练"

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testPlanAtDefaultReadingSize() throws { try checkPlan(size: "large") }
    @MainActor func testPlanAtXXXLReadingSize() throws { try checkPlan(size: "xxxLarge") }
    @MainActor func testPlanAtLargestReadingSize() throws { try checkPlan(size: "accessibility5") }

    @MainActor func testNewPlanCanCancelAndCreateAgainAtDefaultReadingSize() throws {
        try checkNewPlanInputs(size: "large")
    }

    @MainActor func testNewPlanCanCancelAndCreateAgainAtLargestReadingSize() throws {
        try checkNewPlanInputs(size: "accessibility5")
    }

    @MainActor private func checkNewPlanInputs(size: String) throws {
        let app = openPlan(size: size)
        app.navigationBars.buttons["返回"].tap()
        let add = app.buttons["添加计划或分组"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["新建计划"].tap()
        let name = app.textFields["计划名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        tapVisibleCenter(name, in: app)
        name.typeText("UI_CANCELLED_PLAN\n")
        let note = app.textViews["计划备注输入框"]
        tapVisibleCenter(note, in: app)
        note.typeText("UI_CANCELLED_NOTE")
        app.navigationBars.buttons["返回"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["打开计划UI_CANCELLED_PLAN"].exists)
        add.tap()
        app.buttons["新建计划"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        tapVisibleCenter(name, in: app)
        name.typeText("UI_SAVED_PLAN\n")
        XCTAssertEqual(note.value as? String, "")
        tapVisibleCenter(note, in: app)
        note.typeText("UI_SAVED_NOTE")
        app.buttons["保存"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        let ungrouped = app.buttons["展开未分组"]
        reveal(ungrouped, in: app)
        ungrouped.tap()
        let saved = app.buttons["打开计划UI_SAVED_PLAN"]
        reveal(saved, in: app)
        saved.tap()
        XCTAssertTrue(app.buttons["计划备注，UI_SAVED_NOTE"].waitForExistence(timeout: 5))
        capture("取消后新建计划名称与备注正确保存：\(size)", app: app)
    }

    @MainActor func testPlanFormInputsReceiveCenterTouchesAtDefaultReadingSize() throws {
        try checkPlanFormInputs(size: "large")
    }

    @MainActor func testLargestPlanFormInputsReceiveCenterTouches() throws {
        try checkPlanFormInputs(size: "accessibility5")
    }

    @MainActor private func checkPlanFormInputs(size: String) throws {
        let app = openPlan(size: size, extra: ["-uitest-fail-plan-save"])
        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        let name = app.textFields["计划名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        tapVisibleCenter(name, in: app)
        name.typeText("X")
        let draftName = try XCTUnwrap(name.value as? String)
        XCTAssertTrue(draftName.contains("X"))
        XCTAssertNotEqual(draftName, planName)
        let note = app.textViews["计划备注输入框"]
        tapVisibleCenter(note, in: app)
        note.typeText("UI_NOTE")
        let draftNote = try XCTUnwrap(note.value as? String)
        XCTAssertTrue(draftNote.contains("UI_NOTE"))
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["planEditor.saveError"].waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, draftName)
        XCTAssertEqual(note.value as? String, draftNote)
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, draftName)
        XCTAssertEqual(note.value as? String, draftNote)
        capture("名称与备注中心输入已保存：\(size)", app: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
    }

    @MainActor func testStandalonePlanNoteReceivesCenterTouchAtDefaultReadingSize() throws {
        try checkStandalonePlanNote(size: "large")
    }

    @MainActor func testLargestStandalonePlanNoteReceivesCenterTouch() throws {
        try checkStandalonePlanNote(size: "accessibility5")
    }

    @MainActor private func checkStandalonePlanNote(size: String) throws {
        let app = openPlan(size: size, extra: ["-uitest-fail-commit-save"])
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "计划备注，")).firstMatch
        tapVisibleCenter(entry, in: app)
        let note = app.textViews["计划备注输入框"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let title = app.staticTexts["计划备注"]
        XCTAssertTrue(title.exists)
        XCTAssertTrue(app.frame.contains(title.frame))
        let grabber = app.buttons["Sheet Grabber"]
        if grabber.exists {
            XCTAssertGreaterThanOrEqual(title.frame.minY, grabber.frame.midY)
        }
        let dismissKeyboard = app.toolbars.buttons["完成"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 5))
        dismissKeyboard.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        tapVisibleCenter(note, in: app)
        note.typeText("UI_STANDALONE")
        waitForText("UI_STANDALONE", in: note)
        var draftNote = try XCTUnwrap(note.value as? String)
        XCTAssertTrue(draftNote.contains("UI_STANDALONE"))
        try confirmStandalonePlanNote(in: app)
        XCTAssertTrue(app.staticTexts["localSave.error"].waitForExistence(timeout: 5))
        XCTAssertEqual(note.value as? String, draftNote)
        draftNote = try editText(in: note, inserting: "UI_RETRY", app: app)
        try confirmStandalonePlanNote(in: app)
        XCTAssertTrue(note.waitForNonExistence(timeout: 5))
        XCTAssertEqual(entry.label, "计划备注，" + draftNote)
        tapVisibleCenter(entry, in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.value as? String, draftNote)
        let clear = app.buttons["清空备注"]
        scrollFormToBottom(containing: clear, in: app)
        reveal(clear, in: app)
        XCTAssertTrue(clear.isHittable)
        clear.tap()
        XCTAssertEqual(note.value as? String, "")
        let count = app.staticTexts["0/200"]
        reveal(count, in: app)
        XCTAssertTrue(count.isHittable)
        capture("独立计划备注中心输入已保存：\(size)", app: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 5))
        XCTAssertEqual(entry.label, "计划备注，" + draftNote)
    }

    @MainActor func testFailedStandalonePlanNoteCanCancelWithoutChangingOriginal() throws {
        let app = openPlan(size: "large", extra: ["-uitest-fail-commit-save"])
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "计划备注，")).firstMatch
        tapVisibleCenter(entry, in: app)
        let note = app.textViews["计划备注输入框"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let original = try XCTUnwrap(note.value as? String)
        let draft = try editText(in: note, inserting: "UI_CANCELLED_NOTE", app: app)
        try confirmStandalonePlanNote(in: app)
        XCTAssertTrue(app.staticTexts["localSave.error"].waitForExistence(timeout: 5))
        XCTAssertEqual(note.value as? String, draft)
        app.buttons["取消"].tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 5))
        tapVisibleCenter(entry, in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.value as? String, original)
        capture("独立备注保存失败后取消保持原内容", app: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 5))
    }

    @MainActor private func confirmStandalonePlanNote(in app: XCUIApplication) throws {
        let confirm = try XCTUnwrap(app.buttons.matching(identifier: "完成").allElementsBoundByIndex
            .filter { $0.isHittable }.min { $0.frame.minY < $1.frame.minY })
        confirm.tap()
    }

    @MainActor func testFailedPlanRenameCanCancelWithoutChangingOriginal() throws {
        let app = openPlan(size: "large", extra: ["-uitest-fail-plan-save"])
        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        let name = app.textFields["计划名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let cancelledName = try editText(in: name, inserting: "UI_CANCELLED_NAME", app: app)
        let note = app.textViews["计划备注输入框"]
        let originalNote = try XCTUnwrap(note.value as? String)
        let cancelledNote = try editText(in: note, inserting: "UI_CANCELLED_NOTE", app: app)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["planEditor.saveError"].waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, cancelledName)
        XCTAssertEqual(note.value as? String, cancelledNote)
        capture("计划保存失败后取消前", app: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, planName)
        XCTAssertEqual(note.value as? String, originalNote)
        capture("取消后重新编辑保留原名称", app: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
    }

    @MainActor func testBaselineEdgeSwipeAtDefaultReadingSize() throws {
        let app = openPlan(size: "large")
        edgeSwipeBack(in: app)
        XCTAssertTrue(app.buttons["添加计划或分组"].waitForExistence(timeout: 5))
    }

    @MainActor func testNativeBackKeepsSinglePaperControlAfterNavigationUpdates() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-plan-readability", "-dismiss-career-review",
                               "-uitest-typography-size", "large"]
        app.launch()
        let tab = mainTab("计划", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        app.buttons["展开" + groupName].tap()
        app.buttons["打开计划" + planName].tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        let controls = app.navigationBars.buttons.allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertEqual(controls.count, 2, "Header 只应有返回和更多操作：\(controls.map(\.label))")
        XCTAssertEqual(app.navigationBars.buttons.matching(identifier: "返回").count, 1)
        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        XCTAssertTrue(app.textFields["计划名称"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        XCTAssertTrue(app.textFields["计划名称"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.navigationBars.buttons.allElementsBoundByIndex.filter { $0.isHittable }.count, 2)
        app.navigationBars.buttons["返回"].tap()
        XCTAssertTrue(app.buttons["添加计划或分组"].waitForExistence(timeout: 5))
    }

    @MainActor func testEdgeSwipeFromScrolledCardAfterClosingExpandedDetails() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-plan-readability", "-dismiss-career-review",
                               "-uitest-typography-size", "large"]
        app.launch()
        let tab = mainTab("计划", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        app.buttons["展开" + groupName].tap()
        let plan = app.buttons["打开计划" + planName]
        reveal(plan, in: app)
        plan.tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))

        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                     "plan.item.", exerciseName + "，")).firstMatch
        reveal(first, in: app)
        first.tap()
        XCTAssertEqual(first.value as? String, "已展开")
        reveal(app.staticTexts["正式组 3"], in: app)
        reveal(first, in: app, down: true)
        first.tap()
        XCTAssertEqual(first.value as? String, "已收起")

        let second = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                      "plan.item.", "杠铃卧推，")).firstMatch
        let card = revealUITestElement(second, in: app, allowPartial: true)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let y = card.midY - app.frame.minY
        capture("收起详情后从动作卡高度侧滑前", app: app)
        origin.withOffset(CGVector(dx: 1, dy: y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width - 8, dy: y)),
                   withVelocity: .slow, thenHoldForDuration: 0)
        let add = app.buttons["添加计划或分组"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["取消"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(add.isHittable)
        capture("收起详情后侧滑返回计划列表", app: app)
    }

    @MainActor func testFreshPlanEdgeSwipeRepeatedlyKeepsListClear() throws {
        for iteration in 0..<3 {
            let app = openPlan(size: "large")
            edgeSwipeBack(in: app)
            let add = app.buttons["添加计划或分组"]
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["取消"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(add.isHittable)
            capture("首次进入详情后侧滑：\(iteration)", app: app)
        }
    }

    @MainActor func testEdgeSwipeAfterEditSheetKeepsPlanListClear() throws {
        for iteration in 0..<3 {
            let app = openPlan(size: "large")
            app.buttons["计划更多操作"].tap()
            app.buttons["编辑计划"].tap()
            let name = app.textFields["计划名称"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            app.buttons["完成"].tap()
            XCTAssertTrue(name.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
            edgeSwipeBack(in: app)
            let add = app.buttons["添加计划或分组"]
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["取消"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(add.isHittable)
            capture("编辑后侧滑无残留弹层：\(iteration)", app: app)
        }
    }

    @MainActor func testDropSetPlanAtLargestReadingSize() throws {
        let app = openPlan(size: "accessibility5")
        let dropRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                       "plan.item.", "杠铃卧推，")).firstMatch
        reveal(dropRow, in: app)
        dropRow.tap()
        XCTAssertEqual(dropRow.value as? String, "已展开")
        let lastSegment = app.staticTexts["45 kg × 9 次"].firstMatch
        reveal(lastSegment, in: app)
        capture("递减组完整训练安排", app: app)
        openItemEditor("递减组 · 杠铃卧推", in: app, down: true)
        let weight = app.buttons["第 3 子组重量"]
        reveal(weight, in: app)
        weight.tap()
        input("7.5", in: app)
        assertAboveKeypad(weight, in: app)
        app.buttons["下一项"].tap()
        input("11", in: app)
        let reps = app.buttons["第 3 子组次数"]
        XCTAssertEqual(reps.value as? String, "11")
        assertAboveKeypad(reps, in: app)
        capture("递减组末段编辑", app: app)
        app.buttons["完成输入"].tap()
        app.buttons["完成"].tap()
        let changed = app.staticTexts["7.5 kg × 11 次"].firstMatch
        reveal(changed, in: app)
        let superRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                        "plan.item.", "杠铃划船 + 坐姿哑铃推肩")).firstMatch
        reveal(superRow, in: app)
        superRow.tap()
        XCTAssertEqual(dropRow.value as? String, "已收起")
        capture("递减组保存后切换到超级组", app: app)
    }

    @MainActor func testStructuredPlanAtLargestReadingSize() throws {
        let app = openPlan(size: "accessibility5")
        let superRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                        "plan.item.", "杠铃划船 + 坐姿哑铃推肩")).firstMatch
        reveal(superRow, in: app)
        superRow.tap()
        XCTAssertEqual(superRow.value as? String, "已展开")
        openItemEditor("杠铃划船 + 坐姿哑铃推肩", in: app)
        let secondReps = app.buttons["动作二次数"]
        reveal(secondReps, in: app)
        secondReps.tap()
        input("14", in: app)
        assertAboveKeypad(secondReps, in: app)
        XCTAssertGreaterThanOrEqual(secondReps.frame.minY,
                                    app.buttons["完成"].frame.maxY + 8)
        app.buttons["下一项"].tap()
        input("4", in: app)
        let rounds = app.buttons["统一组数"]
        XCTAssertEqual(rounds.value as? String, "4")
        assertAboveKeypad(rounds, in: app)
        capture("超级组成员与统一轮数编辑", app: app)
        XCTAssertGreaterThanOrEqual(rounds.frame.minY,
                                    app.buttons["完成"].frame.maxY + 8)
        app.buttons["完成输入"].tap()
        app.buttons["完成"].tap()
        XCTAssertTrue(superRow.label.contains("4 轮"))
        capture("超级组保存保留统一轮数", app: app)
    }

    @MainActor func testPlanReorderingAtLargestReadingSize() throws {
        let app = openPlan(size: "accessibility5")
        let sort = app.buttons["调整动作顺序"]
        reveal(sort, in: app)
        sort.tap()
        let done = app.buttons["完成排序"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(done.frame.height + 0.001, 44)
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder " + exerciseName)).firstMatch
        let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder 杠铃卧推")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        reveal(second, in: app)
        capture("排序长名称与原生手柄", app: app)
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)),
                   withVelocity: .slow, thenHoldForDuration: 0.5)
        capture("真实拖动后的排序", app: app)
        XCTAssertLessThan(second.frame.minY, first.frame.minY, "必须实际移动，不能只以面板打开通过排序验收")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.item."))
        XCTAssertTrue(rows.element(boundBy: 0).label.hasPrefix("杠铃卧推，"))
        let savedFirstID = rows.element(boundBy: 0).identifier
        app.buttons["返回"].tap()
        app.buttons["打开计划" + planName].tap()
        reveal(app.buttons[savedFirstID], in: app)
        XCTAssertTrue(rows.element(boundBy: 0).label.hasPrefix("杠铃卧推，"))
    }

    @MainActor private func checkPlan(size: String) throws {
        let app = openPlan(size: size, extra: ["-uitest-fail-plan-save"])
        let rules = app.buttons["自适应模式，查看规则"]
        reveal(rules, in: app)
        rules.tap()
        let strictDraft = app.buttons["严格模式"]
        reveal(strictDraft, in: app)
        strictDraft.tap()
        XCTAssertTrue(strictDraft.isSelected)
        capture("计划模式草稿与取消：\(size)", app: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(rules.exists)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                   "plan.item.", exerciseName)).firstMatch
        reveal(row, in: app)
        row.tap()
        XCTAssertEqual(row.value as? String, "已展开")
        let arrangement = app.staticTexts["下次训练安排"].firstMatch
        reveal(arrangement, in: app)
        capture("计划展开安排：\(size)", app: app)
        openItemEditor(exerciseName, in: app, down: true)
        let weight = app.buttons["正式组重量"]
        reveal(weight, in: app)
        XCTAssertGreaterThanOrEqual(weight.frame.height + 0.001, 44)
        weight.tap()
        input("999.75", in: app)
        XCTAssertEqual(weight.value as? String, "999.75")
        assertAboveKeypad(weight, in: app)
        app.buttons["下一项"].tap()
        input("11", in: app)
        let reps = app.buttons["正式组次数"]
        XCTAssertEqual(reps.value as? String, "11")
        assertAboveKeypad(reps, in: app)
        capture("计划重量次数录入：\(size)", app: app)
        app.buttons["完成输入"].tap()
        app.buttons["完成"].tap()
        XCTAssertTrue(row.label.contains("3 组 × 11 次"))
        openItemEditor(exerciseName, in: app, down: true)
        reveal(weight, in: app)
        weight.tap()
        input("7", in: app)
        app.buttons["取消"].tap()
        openItemEditor(exerciseName, in: app)
        XCTAssertEqual(weight.value as? String, "999.75")
        app.buttons["取消"].tap()

        app.buttons["计划更多操作"].tap()
        app.buttons["编辑计划"].tap()
        let name = app.textFields["计划名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let editedName = try editText(in: name, inserting: "UI_RETRY_NAME", app: app)
        let editedNote = try editText(in: app.textViews["计划备注输入框"], inserting: "UI_RETRY_NOTE", app: app)
        app.buttons["完成"].tap()
        let error = app.staticTexts["planEditor.saveError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, editedName)
        XCTAssertEqual(app.textViews["计划备注输入框"].value as? String, editedNote)
        capture("计划名称保存失败保留输入：\(size)", app: app)
        app.buttons["完成"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["计划备注，" + editedNote].exists)

        // 使用原生 List 的左边缘返回，避免仅验证导航按钮。
        capture("侧滑返回前：\(size)", app: app)
        edgeSwipeBack(in: app)
        let add = app.buttons["添加计划或分组"]
        capture("侧滑返回后：\(size)", app: app)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["取消"].waitForNonExistence(timeout: 5), "返回列表后不得残留计划编辑弹层")
        XCTAssertTrue(add.isHittable)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "侧滑返回后的完整屏幕：\(size)"
        screen.lifetime = .keepAlways
        self.add(screen)
        add.tap()
        app.buttons["新建计划"].tap()
        let save = app.buttons["保存"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        let newName = "UI 大字新建 · 长名称训练计划 · " + size
        tapVisibleCenter(name, in: app)
        name.typeText(newName + "\n")
        let strict = app.buttons["严格模式"]
        reveal(strict, in: app)
        strict.tap()
        XCTAssertTrue(strict.isSelected)
        let creationNote = app.textViews["计划备注输入框"]
        tapVisibleCenter(creationNote, in: app)
        creationNote.typeText("UI_CANCEL_NOTE")
        XCTAssertEqual(creationNote.value as? String, "UI_CANCEL_NOTE")
        let group = app.buttons["选择分组"]
        func revealGroupPicker() {
            _ = revealUITestElement(group, in: app, allowPartial: true)
            // 分组是表单最后一项，滚到底后按实际窗口校验，不扣除无 Home Indicator 设备的额外底边。
            scrollFormToBottom(containing: group, in: app)
            XCTAssertTrue(group.isHittable)
            XCTAssertGreaterThanOrEqual(group.frame.minY, app.navigationBars.firstMatch.frame.maxY)
            XCTAssertLessThanOrEqual(group.frame.maxY, app.frame.maxY)
            if app.keyboards.firstMatch.exists {
                XCTAssertLessThanOrEqual(group.frame.maxY, app.keyboards.firstMatch.frame.minY)
            }
        }
        revealGroupPicker()
        group.tap()
        XCTAssertTrue(app.buttons["未分组"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["未分组"].isSelected)
        capture("新建计划分组选择：\(size)", app: app)
        app.buttons["取消"].tap()
        XCTAssertEqual(group.value as? String, "未分组")
        app.buttons["返回"].tap()
        XCTAssertFalse(app.buttons["打开计划" + newName].exists)
        add.tap()
        app.buttons["新建计划"].tap()
        tapVisibleCenter(name, in: app)
        name.typeText(newName + "\n")
        XCTAssertEqual(creationNote.value as? String, "")
        tapVisibleCenter(creationNote, in: app)
        creationNote.typeText("UI_SAVED_NOTE")
        XCTAssertEqual(creationNote.value as? String, "UI_SAVED_NOTE")
        revealGroupPicker()
        group.tap()
        let selection = app.buttons[groupName]
        reveal(selection, in: app)
        selection.tap()
        XCTAssertEqual(group.value as? String, groupName)
        revealGroupPicker()
        capture("新建计划可滚动完整表单：\(size)", app: app)
        save.tap()
        let created = app.buttons["打开计划" + newName]
        XCTAssertTrue(created.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "打开计划" + newName).count, 1)
        reveal(created, in: app)
        capture("新建保存返回计划列表：\(size)", app: app)
        created.tap()
        XCTAssertTrue(app.buttons["计划备注，UI_SAVED_NOTE"].waitForExistence(timeout: 5))
    }

    @MainActor private func openPlan(size: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow", "-uitest-plan-readability", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size] + extra
        app.launch()
        let tab = mainTab("计划", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        let group = app.buttons["展开" + groupName]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        capture("计划列表：\(size)", app: app)
        let plan = app.buttons["打开计划" + planName]
        let visiblePlan = revealUITestElement(plan, in: app, allowPartial: true)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: visiblePlan.midX - app.frame.minX, dy: visiblePlan.midY - app.frame.minY)).tap()
        XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
        capture("计划详情：\(size)", app: app)
        return app
    }

    @MainActor private func openItemEditor(_ name: String, in app: XCUIApplication, down: Bool = false) {
        let menu = app.buttons[name + "更多操作"]
        reveal(menu, in: app, down: down)
        menu.tap()
        app.buttons["编辑"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5))
        let title = app.staticTexts[name.hasPrefix("递减组") ? "编辑递减组"
                                   : name.contains(" + ") ? "编辑超级组" : "编辑动作"].firstMatch
        XCTAssertGreaterThanOrEqual(title.frame.minX, 18)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX - 18)
    }

    @MainActor private func input(_ text: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["数字 1"].waitForExistence(timeout: 5))
        for character in text {
            app.buttons[character == "." ? "小数点" : "数字 \(character)"].tap()
        }
    }

    @MainActor private func assertAboveKeypad(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertLessThanOrEqual(element.frame.maxY, app.buttons["数字 1"].frame.minY,
                                 "完整字段必须在数字键盘上方：\(element.frame)")
    }

    @MainActor private func edgeSwipeBack(in app: XCUIApplication) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let y = app.frame.height * 0.45
        origin.withOffset(CGVector(dx: 1, dy: y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width - 8, dy: y)),
                   withVelocity: .fast, thenHoldForDuration: 0)
    }

    @MainActor private func scrollFormToBottom(containing element: XCUIElement, in app: XCUIApplication) {
        let key = element.identifier.isEmpty ? element.label : element.identifier
        let body = app.scrollViews.containing(element.elementType, identifier: key).firstMatch
        XCTAssertTrue(body.exists)
        let viewport = body.frame.intersection(app.frame)
        let keyboard = app.keyboards.firstMatch
        let bottom = keyboard.exists ? min(viewport.maxY, keyboard.frame.minY) : viewport.maxY
        XCTAssertGreaterThan(bottom - viewport.minY, 40)
        // 从正文边距滚动父容器，避免只滚动 TextEditor 内部的文字。
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = viewport.minX + 10 - app.frame.minX
        origin.withOffset(CGVector(dx: x, dy: bottom - 20 - app.frame.minY))
            .press(forDuration: 0.01,
                   thenDragTo: origin.withOffset(CGVector(dx: x, dy: viewport.minY + 20 - app.frame.minY)),
                   withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    @MainActor private func tapVisibleCenter(_ element: XCUIElement, in app: XCUIApplication) {
        let visible = revealUITestElement(element, in: app, allowPartial: true)
        XCTAssertFalse(visible.isEmpty)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: visible.midX - app.frame.minX, dy: visible.midY - app.frame.minY)).tap()
    }

    @MainActor private func editText(in field: XCUIElement, inserting text: String, app: XCUIApplication) throws -> String {
        let original = try XCTUnwrap(field.value as? String)
        tapVisibleCenter(field, in: app)
        field.typeText(text)
        waitForText(text, in: field)
        let draft = try XCTUnwrap(field.value as? String)
        XCTAssertTrue(draft.contains(text))
        XCTAssertEqual(draft.replacingOccurrences(of: text, with: ""), original)
        return draft
    }

    @MainActor private func waitForText(_ text: String, in field: XCUIElement) {
        // 原生键盘事件发送完毕时，字段仍可能处于输入中间态。
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, down: Bool = false) {
        revealUITestElement(element, in: app, scrollDownWhenMissing: down)
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
