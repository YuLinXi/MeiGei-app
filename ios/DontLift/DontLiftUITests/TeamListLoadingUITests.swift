import XCTest

final class TeamListLoadingUITests: XCTestCase {
    private let teamName = "UI 大字 Team · 长期力量与稳定控制"
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSlowFirstLoadKeepsCreateAndJoinAvailableWithoutFalseEmpty() throws {
        let app = launch(flags: ["-uitest-team-list-slow"])
        let loading = app.descendants(matching: .any).matching(identifier: "team.list.loading").firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 3))
        assertNoEmptyClaim(in: app)
        capture("Team 首次未知保持中性加载", in: app)
        openMenu(in: app)
        app.buttons["创建 Team"].firstMatch.tap()
        XCTAssertTrue(app.textFields["队名"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        openMenu(in: app)
        app.buttons["用邀请码加入"].firstMatch.tap()
        XCTAssertTrue(app.textFields["邀请码"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        XCTAssertTrue(teamButton(in: app).waitForExistence(timeout: 18))
        XCTAssertFalse(loading.exists)
        assertNoEmptyClaim(in: app)
    }

    @MainActor func testOfflineFirstLoadRetriesAtLargestSize() throws {
        let app = launch(size: "accessibility5", flags: ["-uitest-team-list-offline-once"])
        let retry = app.buttons["team.list.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未能加载 Team"].exists)
        assertNoEmptyClaim(in: app)
        XCTAssertTrue(retry.isHittable)
        XCTAssertGreaterThanOrEqual(retry.frame.height + 0.001, 44)
        XCTAssertTrue(app.frame.contains(retry.frame))
        XCTAssertTrue(app.buttons["创建或加入 Team"].isHittable)
        capture("Team 首次离线可重试且入口可达：最大字号", in: app)
        retry.tap()
        XCTAssertTrue(teamButton(in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["未能加载 Team"].exists)
        assertNoEmptyClaim(in: app)
    }

    @MainActor func testRefreshFailureKeepsCachedTeamAndRetries() throws {
        let app = launch(flags: ["-uitest-team-list-refresh-failure"])
        let team = teamButton(in: app)
        XCTAssertTrue(team.waitForExistence(timeout: 5))
        let scroll = app.scrollViews["team.list.scroll"]
        XCTAssertTrue(scroll.isHittable)
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        let retry = app.buttons["team.list.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(team.isHittable)
        XCTAssertTrue(app.staticTexts["刷新失败，已保留原列表"].exists)
        assertNoEmptyClaim(in: app)
        capture("Team 刷新离线仍保留已有列表", in: app)
        retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5))
        XCTAssertTrue(team.isHittable)
    }

    @MainActor func testSuccessfulEmptyResponseShowsOnboarding() throws {
        let app = launch(flags: ["-uitest-team-empty"])
        XCTAssertTrue(app.staticTexts["和训练搭子组队"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["team.list.retry"].exists)
        XCTAssertFalse(teamButton(in: app).exists)
        let create = app.buttons["创建 Team"].firstMatch
        XCTAssertTrue(create.isHittable)
        create.tap()
        XCTAssertTrue(app.textFields["队名"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        capture("Team 成功读取空列表后显示组队引导", in: app)
    }

    @MainActor private func launch(size: String = "large", flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-uitest-team-readability",
                               "-dismiss-career-review", "-uitest-typography-size", size] + flags
        app.launch()
        let tab = app.tabBars.buttons["Team"]
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        return app
    }

    @MainActor private func teamButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(.staticText, identifier: teamName).firstMatch
    }

    @MainActor private func assertNoEmptyClaim(in app: XCUIApplication) {
        XCTAssertFalse(app.staticTexts["和训练搭子组队"].exists)
    }

    @MainActor private func openMenu(in app: XCUIApplication) {
        let menu = app.buttons["创建或加入 Team"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
