import XCTest

final class SessionRecoveryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLocalCleanupFailureBlocksLoginUntilRetrySucceeds() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-local-cleanup-recovery", "-uitest-fail-cleanup-save",
                               "-dismiss-career-review"]
        app.launch()
        let retry = app.buttons["accountCleanup.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["本机数据尚未清理完成"].exists)
        XCTAssertFalse(app.staticTexts["别练了 · BIELIANLE"].exists)
        XCTAssertFalse(app.tabBars.buttons["训练"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "清理失败可重试，登录受门控"
        attachment.lifetime = .keepAlways
        add(attachment)
        retry.tap()
        XCTAssertTrue(app.staticTexts["别练了 · BIELIANLE"].waitForExistence(timeout: 10))
        XCTAssertFalse(retry.exists)
    }

    @MainActor
    func testProfileFailureCanRetryAndKeepLocalHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-profile-recovery",
                               "-uitest-profile-recovery-success", "-dismiss-career-review"]
        app.launch()
        let retry = app.buttons["profileGate.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["暂时无法读取账号资料"].exists)
        retry.tap()

        XCTAssertTrue(app.tabBars.buttons["训练"].waitForExistence(timeout: 15))
        let history = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UI 恢复保留训练")).firstMatch
        if !history.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profileGate.retry"].exists)
    }

    @MainActor
    func testProfileFailureCanReturnToLogin() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-profile-recovery", "-dismiss-career-review"]
        app.launch()
        let login = app.buttons["profileGate.login"]
        XCTAssertTrue(app.buttons["profileGate.retry"].waitForExistence(timeout: 25))
        XCTAssertTrue(login.isHittable)
        login.tap()

        XCTAssertTrue(app.staticTexts["别练了 · BIELIANLE"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profileGate.retry"].exists)
    }
}
