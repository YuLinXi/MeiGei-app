import XCTest

/// 系统语义门禁覆盖名称、角色与命中区域；原生对比度诊断需独立核验，不代替颜色比值或真实读屏。
final class NativeAccessibilityAuditUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testHomeSemantics() throws { try audit(tab: "训练") }
    @MainActor func testPlanSemantics() throws { try audit(tab: "计划") }
    @MainActor func testExerciseSemantics() throws { try audit(tab: "动作") }
    @MainActor func testTeamSemantics() throws { try audit(tab: "Team") }
    @MainActor func testProfileSemantics() throws { try audit(tab: "我的") }

    @MainActor func testHomeHistoryOutsideFirstViewportCanBeOpened() throws {
        let app = launch(tab: "训练")
        for title in ["UI 另存胸背", "UI 大字徽章训练"] {
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            revealUITestElement(row, in: app)
            XCTAssertTrue(row.staticTexts[title].isHittable)
            captureVisible(row, tab: "训练", in: app)
            row.tap()
            XCTAssertTrue(app.buttons["训练更多操作"].waitForExistence(timeout: 5))
            app.buttons["返回"].firstMatch.tap()
        }
    }

    @MainActor func testProfilePreferencesOutsideFirstViewportRemainReachable() throws {
        let app = launch(tab: "我的")
        let rest = app.buttons["profile.defaultRest"]
        revealUITestElement(rest, in: app)
        XCTAssertNotNil(rest.value as? String)
        captureVisible(rest, tab: "我的", in: app)
        rest.tap()
        let cancel = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        let estimate = app.switches["profile.calorieEstimate"]
        revealUITestElement(estimate, in: app)
        XCTAssertTrue(estimate.isHittable)
        captureVisible(estimate, tab: "我的", in: app)
    }

    @MainActor func testExerciseCardsAndLastCategoryRemainReachable() throws {
        let app = launch(tab: "动作")
        for title in ["下斜杠铃卧推", "下斜哑铃卧推", "史密斯卧推", "器械推胸"] {
            let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title + "，")).firstMatch
            revealUITestElement(card, in: app)
            captureVisible(card, tab: "动作", in: app)
            card.tap()
            let back = app.buttons["返回"].firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
        }
        let category = app.buttons["功能性"]
        let rail = app.scrollViews.containing(.button, identifier: "功能性").firstMatch
        XCTAssertTrue(rail.exists)
        let bottom = min(rail.frame.maxY, app.tabBars.firstMatch.frame.minY - 8)
        for _ in 0..<12 {
            if category.exists && category.isHittable && category.frame.minY >= rail.frame.minY
                && category.frame.maxY <= bottom { break }
            rail.swipeUp(velocity: .slow)
        }
        captureVisible(category, tab: "动作", in: app)
        XCTAssertGreaterThanOrEqual(category.frame.minY, rail.frame.minY)
        XCTAssertLessThanOrEqual(category.frame.maxY, bottom)
        category.tap()
        XCTAssertEqual(category.value as? String, "已选择")
    }

    @MainActor private func captureVisible(_ element: XCUIElement, tab: String, in app: XCUIApplication) {
        print("[S5-scroll-audit] tab=\(tab) label=\(element.label) frame=\(element.frame)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "滚动后可达：\(tab) · \(element.label)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func launch(tab: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow", "-clear-active-workout",
                               "-uitest-history-save", "-uitest-plan-readability", "-uitest-badge-readability",
                               "-uitest-team-readability", "-dismiss-career-review"]
        app.launch()
        let target = mainTab(tab, in: app)
        XCTAssertTrue(waitForIsolatedUITestScene(target, in: app))
        target.tap()
        XCTAssertTrue(target.isSelected)
        if tab == "Team" {
            XCTAssertTrue(app.buttons.containing(.staticText, identifier: "UI 大字 Team · 长期力量与稳定控制")
                .firstMatch.waitForExistence(timeout: 5))
        }
        return app
    }

    @MainActor private func audit(tab: String) throws {
        let app = launch(tab: tab)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "系统语义审计：" + tab
        attachment.lifetime = .keepAlways
        add(attachment)
        let contrastDiagnostic = ProcessInfo.processInfo.environment["DONTLIFT_NATIVE_CONTRAST_DIAGNOSTIC"] == "1"
        var auditTypes: XCUIAccessibilityAuditType = [.sufficientElementDescription, .trait, .hitRegion]
        if contrastDiagnostic { auditTypes.insert(.contrast) }
        print("[S5-audit-scope] tab=\(tab) nativeContrast=\(contrastDiagnostic)")
        // 不过滤或吞掉审计问题，任何被报告的问题都应保留在 xcresult 并使该用例失败。
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            let element = issue.element
            print("[S5-audit] tab=\(tab) type=\(issue.auditType.rawValue) label=\(element?.label ?? "无元素") frame=\(String(describing: element?.frame)) detail=\(issue.detailedDescription)")
            return false
        }
    }
}
