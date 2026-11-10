import XCTest

/// 假登录、画像响应与清理均限定在独立 UI 测试库，不执行真实登录或删除账号。
final class AuthReadabilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testCompletionAtDefaultReadingSize() throws { checkCompletion(size: "large") }
    @MainActor func testCompletionAtXXXLReadingSize() throws { checkCompletion(size: "xxxLarge") }
    @MainActor func testCompletionAtLargestReadingSize() throws { checkCompletion(size: "accessibility5") }
    @MainActor func testLoginAtDefaultReadingSize() throws { checkLogin(size: "large") }
    @MainActor func testLoginAtXXXLReadingSize() throws { checkLogin(size: "xxxLarge") }

    @MainActor func testRecoveryAtLargestReadingSizeKeepsHistory() throws {
        let app = launch(size: "accessibility5", flags: ["-uitest-profile-recovery", "-uitest-profile-recovery-success"])
        let retry = app.buttons["profileGate.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 25))
        reveal(retry, in: app)
        XCTAssertGreaterThanOrEqual(retry.frame.height + 0.001, 44)
        capture("最大字号画像失败与恢复入口", in: app)
        retry.tap()
        XCTAssertTrue(mainTab("训练", in: app).waitForExistence(timeout: 15))
        let history = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UI 恢复保留训练")).firstMatch
        reveal(history, in: app)
        capture("恢复后保留本地训练", in: app)
    }

    @MainActor func testCleanupAndLoginAtLargestReadingSize() throws {
        let app = launch(size: "accessibility5", flags: ["-uitest-local-cleanup-recovery", "-uitest-fail-cleanup-save"])
        let retry = app.buttons["accountCleanup.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        XCTAssertFalse(mainTab("训练", in: app).exists)
        XCTAssertFalse(app.buttons["Sign in with Apple"].exists)
        reveal(retry, in: app)
        capture("最大字号清理失败门控", in: app)
        retry.tap()
        XCTAssertTrue(app.staticTexts["别练了 · BIELIANLE"].waitForExistence(timeout: 10))
        checkLegalControls(in: app, size: "accessibility5")
    }

    @MainActor private func checkCompletion(size: String) {
        let app = launch(size: size, flags: ["-uitest-profile-completion", "-clear-active-workout"])
        capture("首登补全初始布局：\(size)", in: app)
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        XCTAssertEqual(name.label, "称呼")
        let start = app.buttons["开始训练"]
        XCTAssertFalse(start.isEnabled)
        reveal(name, in: app)
        name.tap()
        name.typeText("UI 大字训练用户\n")
        let female = app.buttons["性别：女"]
        reveal(female, in: app)
        female.tap()
        XCTAssertTrue(female.isSelected)
        reveal(start, in: app)
        XCTAssertGreaterThanOrEqual(start.frame.height + 0.001, 44)
        start.tap()
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "资料未保存")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "UI 大字训练用户")
        XCTAssertTrue(female.isSelected)
        reveal(error, in: app)
        capture("补全失败保留称呼与性别：\(size)", in: app)
        if size == "accessibility5" {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "首登大字辅助功能树"
            tree.lifetime = .keepAlways
            add(tree)
        }
        reveal(start, in: app)
        start.tap()
        XCTAssertTrue(mainTab("训练", in: app).waitForExistence(timeout: 15))
    }

    @MainActor private func checkLogin(size: String) {
        let app = launch(size: size, flags: ["-uitest-profile-recovery"])
        let retry = app.buttons["profileGate.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 25))
        let login = app.buttons["profileGate.login"]
        reveal(login, in: app)
        login.tap()
        XCTAssertTrue(app.staticTexts["别练了 · BIELIANLE"].waitForExistence(timeout: 10))
        checkLegalControls(in: app, size: size)
    }

    @MainActor private func checkLegalControls(in app: XCUIApplication, size: String) {
        capture("登录页初始布局：\(size)", in: app)
        let terms = app.buttons["服务条款"]
        let privacy = app.buttons["隐私政策"]
        reveal(terms, in: app)
        XCTAssertGreaterThanOrEqual(terms.frame.height + 0.001, 44)
        reveal(privacy, in: app)
        XCTAssertGreaterThanOrEqual(privacy.frame.height + 0.001, 44)
        capture("登录操作与法律入口可达：\(size)", in: app)
    }

    @MainActor private func launch(size: String, flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-dismiss-career-review", "-uitest-typography-size", size] + flags
        app.launch()
        XCTAssertTrue(waitForIsolatedUITestScene(app.windows.firstMatch, in: app))
        return app
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
