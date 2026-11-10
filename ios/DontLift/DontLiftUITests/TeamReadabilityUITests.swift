import XCTest

/// 通过进程内 HTTP fixture 验证 Team 布局与入口，不发送真实分享、表情或通知。
final class TeamReadabilityUITests: XCTestCase {
    private let teamName = "UI 大字 Team · 长期力量与稳定控制"
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testTeamAtDefaultReadingSize() throws { checkTeam(size: "large") }
    @MainActor func testTeamAtXXXLReadingSize() throws { checkTeam(size: "xxxLarge") }
    @MainActor func testTeamAtLargestReadingSize() throws { checkTeam(size: "accessibility5") }

    @MainActor func testTeamPreferencesAtLargestReadingSize() throws {
        let app = launch(size: "accessibility5")
        let team = app.buttons.containing(.staticText, identifier: teamName).firstMatch
        XCTAssertTrue(team.waitForExistence(timeout: 5))
        team.tap()
        let share = app.switches["team.autoShare"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        reveal(share, in: app)
        XCTAssertEqual(share.value as? String, "0")
        tapSwitch(share)
        let confirm = app.buttons["开启"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        capture("Team 自动分享确认与取消", in: app)
        XCTAssertGreaterThanOrEqual(app.buttons["取消"].frame.minY, 60)
        XCTAssertLessThanOrEqual(confirm.frame.maxY, app.frame.maxY - 34)
        app.buttons["取消"].tap()
        XCTAssertEqual(share.value as? String, "0")
        tapSwitch(share)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        XCTAssertEqual(share.value as? String, "1")
        tapSwitch(share)
        XCTAssertEqual(share.value as? String, "0")
        let notifications = app.switches["team.notifications"]
        reveal(notifications, in: app)
        XCTAssertEqual(notifications.value as? String, "1")
        tapSwitch(notifications)
        XCTAssertEqual(notifications.value as? String, "0")
        tapSwitch(notifications)
        XCTAssertEqual(notifications.value as? String, "1")
        capture("Team 偏好名称与切换", in: app)
    }

    @MainActor func testTeamMembersAndSnapshotAtDefaultReadingSize() throws { checkMembers(size: "large") }
    @MainActor func testTeamMembersAndSnapshotAtLargestReadingSize() throws { checkMembers(size: "accessibility5") }

    @MainActor private func checkMembers(size: String) {
        let app = launch(size: size)
        let team = app.buttons.containing(.staticText, identifier: teamName).firstMatch
        XCTAssertTrue(team.waitForExistence(timeout: 5))
        team.tap()
        let members = app.buttons["拍一拍队友"]
        reveal(members, in: app)
        members.tap()
        let sheet = app.scrollViews["team.todayMembers"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Team 成员"].exists)
        XCTAssertFalse(app.buttons["关闭"].exists)
        let memberName = app.staticTexts["UI 长名称训练搭子 · 胸背力量复盘"].firstMatch
        reveal(memberName, in: app)
        capture("Team 成员长名称与状态", in: app)
        let from = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        let to = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: sheet.frame.midX, dy: app.frame.maxY - 34))
        from.press(forDuration: 0.05, thenDragTo: to)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        let snapshot = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "team.checkin.")).firstMatch
        reveal(snapshot, in: app)
        snapshot.tap()
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5))
        let weight = app.staticTexts["40 kg"].firstMatch
        reveal(weight, in: app)
        let reps = app.staticTexts["12 次"].firstMatch
        reveal(reps, in: app)
        XCTAssertTrue(weight.isHittable)
        XCTAssertTrue(reps.isHittable)
        capture("Team 训练快照每组值", in: app)
        app.buttons["关闭"].tap()
        for name in ["火热", "加油", "喜欢", "鼓掌"] {
            let reaction = app.buttons[name].firstMatch
            reveal(reaction, in: app)
            XCTAssertGreaterThanOrEqual(reaction.frame.width + 0.001, 44)
            XCTAssertGreaterThanOrEqual(reaction.frame.height + 0.001, 44)
            XCTAssertFalse(reaction.isSelected)
        }
        let fire = app.buttons["火热"].firstMatch
        reveal(fire, in: app)
        fire.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1 人回应"), object: fire)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        XCTAssertTrue(fire.isSelected)
        fire.tap()
        let cancelled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0 人回应"), object: fire)
        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: 3), .completed)
        XCTAssertFalse(fire.isSelected)
    }
    @MainActor func testEmptyTeamAtDefaultReadingSize() throws { checkEmptyTeam(size: "large") }
    @MainActor func testEmptyTeamAtLargestReadingSize() throws { checkEmptyTeam(size: "accessibility5") }

    @MainActor private func checkEmptyTeam(size: String) {
        let app = launch(size: size, empty: true)
        let create = app.buttons["创建 Team"].firstMatch
        reveal(create, in: app)
        capture("Team 空态与入口：\(size)", in: app)
        create.tap()
        let name = app.textFields["队名"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UI 长名称力量训练小队\n")
        let createNotice = app.staticTexts["team.defaultSharing.notice"]
        reveal(createNotice, in: app)
        XCTAssertTrue(createNotice.label.contains("默认开启"))
        XCTAssertTrue(createNotice.label.contains("关闭不会撤回"))
        capture("Team 创建前默认分享说明：\(size)", in: app)
        let confirm = app.buttons["创建"].firstMatch
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "稍后")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "UI 长名称力量训练小队")
        capture("Team 创建失败保留输入：\(size)", in: app)
        app.buttons["取消"].tap()
        let join = app.buttons["用邀请码加入"].firstMatch
        reveal(join, in: app)
        join.tap()
        let code = app.textFields["邀请码"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        code.typeText("abc123\n")
        XCTAssertEqual(code.value as? String, "ABC123")
        XCTAssertGreaterThanOrEqual(code.frame.height + 0.001, 44)
        let joinNotice = app.staticTexts["team.defaultSharing.notice"]
        reveal(joinNotice, in: app)
        XCTAssertTrue(joinNotice.label.contains("默认开启"))
        XCTAssertTrue(joinNotice.label.contains("关闭不会撤回"))
        capture("Team 加入前默认分享说明：\(size)", in: app)
        app.buttons["加入"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "稍后")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(code.value as? String, "ABC123")
        capture("Team 加入失败保留邀请码：\(size)", in: app)
        app.buttons["加入"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: teamName).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor private func checkTeam(size: String) {
        let app = launch(size: size)
        let team = app.buttons.containing(.staticText, identifier: teamName).firstMatch
        XCTAssertTrue(team.waitForExistence(timeout: 5))
        capture("Team 列表：\(size)", in: app)
        team.tap()
        let share = app.switches["分享动态"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        capture("Team 详情：\(size)", in: app)
        let history = app.buttons["历史训练"]
        reveal(history, in: app)
        XCTAssertGreaterThanOrEqual(history.frame.width + 0.001, 44)
        XCTAssertGreaterThanOrEqual(history.frame.height + 0.001, 44)
        history.tap()
        XCTAssertTrue(app.scrollViews["calendar.grid"].waitForExistence(timeout: 5))
        capture("Team 历史：\(size)", in: app)
        app.buttons["返回"].tap()
        let plans = app.buttons["Team 计划"]
        reveal(plans, in: app)
        plans.tap()
        let plan = app.buttons.containing(.staticText, identifier: "UI Team 计划 · 胸背力量与稳定控制逐组安排").firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        capture("Team 长计划与反馈：\(size)", in: app)
        let start = app.buttons["开始训练"]
        let copy = app.buttons["复制"]
        reveal(start, in: app)
        XCTAssertGreaterThanOrEqual(start.frame.height + 0.001, 44)
        XCTAssertGreaterThanOrEqual(copy.frame.width + 0.001, 44)
        XCTAssertGreaterThanOrEqual(copy.frame.height + 0.001, 44)
        capture("Team 计划底部统计与入口：\(size)", in: app)
        let planTitle = plan.staticTexts["UI Team 计划 · 胸背力量与稳定控制逐组安排"]
        reveal(planTitle, in: app)
        planTitle.tap()
        let fork = app.buttons["复制到我的计划"]
        XCTAssertTrue(fork.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(fork.frame.height + 0.001, 44)
        capture("Team 计划详情与操作：\(size)", in: app)
    }

    @MainActor private func launch(size: String, empty: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-team-readability", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size]
        if empty { app.launchArguments.append("-uitest-team-empty") }
        app.launch()
        let tab = mainTab("Team", in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        return app
    }

    @MainActor private func tapSwitch(_ control: XCUIElement) {
        let nativeSwitch = control.switches.firstMatch
        (nativeSwitch.exists ? nativeSwitch : control).tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        revealUITestElement(element, in: app)
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
