import XCTest

/// 操作真实主动分享页面，通过进程内替身请求日志断言取消与既有分享独立。
final class TeamSharingFlowUITests: XCTestCase {
    private let teamA = "A1000000-0000-0000-0000-000000000001"
    private let teamB = "A1000000-0000-0000-0000-000000000004"
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testAlreadySharedCancelAtDefaultSize() throws { checkCancel(size: "large", alreadyShared: true) }
    @MainActor func testAlreadySharedCancelAtLargestSize() throws { checkCancel(size: "accessibility5", alreadyShared: true) }
    @MainActor func testUnsharedCancelAtDefaultSize() throws { checkCancel(size: "large", alreadyShared: false) }

    @MainActor func testSubmittingOneTargetKeepsExistingShare() throws {
        let app = launch(size: "large", alreadyShared: true)
        let target = app.buttons["team.share.target.\(teamB)"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        XCTAssertTrue(target.isSelected)
        app.buttons["team.share.submit"].tap()
        XCTAssertTrue(app.buttons["team.share.submit"].waitForNonExistence(timeout: 5))
        expectAudit("share=1;delete=0;preferences=0;other=0;targets=\(teamB);existing=\(teamA),\(teamB)", in: app)
    }

    @MainActor func testLoadingFailureRetriesWithoutPrivateClaim() throws {
        let app = launch(size: "large", alreadyShared: true, flags: ["-uitest-team-share-load-failure"])
        let retry = app.buttons["重试加载 Team"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["还没有 Team"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "仅自己可见")).firstMatch.exists)
        capture("主动分享首次失败与重试", in: app)
        retry.tap()
        XCTAssertTrue(app.buttons["team.share.target.\(teamB)"].waitForExistence(timeout: 5))
        app.buttons["team.share.cancel"].tap()
        expectAudit("share=0;delete=0;preferences=0;other=0;targets=;existing=\(teamA)", in: app)
    }

    @MainActor func testNoTeamsDoesNotClaimWithdrawal() throws {
        let app = launch(size: "large", alreadyShared: true, flags: ["-uitest-team-empty"])
        XCTAssertTrue(app.staticTexts["还没有 Team"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "仅自己可见")).firstMatch.exists)
        app.buttons["team.share.cancel"].tap()
        expectAudit("share=0;delete=0;preferences=0;other=0;targets=;existing=\(teamA)", in: app)
    }

    @MainActor private func checkCancel(size: String, alreadyShared: Bool) {
        let app = launch(size: size, alreadyShared: alreadyShared)
        capture("主动分享取消边界：\(size)", in: app)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "默认仅自己可见")).firstMatch.exists)
        let cancel = app.buttons["team.share.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let confirm = app.buttons["team.share.submit"]
        for button in [cancel, confirm] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height + 0.001, 44)
            XCTAssertTrue(app.frame.contains(button.frame))
        }
        if size == "accessibility5" {
            let target = app.buttons["team.share.target.\(teamB)"]
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<8 where !scroll.frame.contains(target.frame) { scroll.swipeUp() }
            XCTAssertTrue(scroll.frame.contains(target.frame))
            target.tap()
            XCTAssertTrue(target.isSelected)
            capture("最大字号滚动选择完整Team后取消", in: app)
        }
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        expectAudit("share=0;delete=0;preferences=0;other=0;targets=;existing=\(alreadyShared ? teamA : "")", in: app)
    }

    @MainActor private func launch(size: String, alreadyShared: Bool, flags: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-team-sharing", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size] + flags
        if alreadyShared { app.launchArguments.append("-uitest-team-already-shared") }
        app.launch()
        let open = app.buttons["打开主动分享"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: open)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        open.tap()
        XCTAssertTrue(app.staticTexts["分享至 Team"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func expectAudit(_ value: String, in app: XCUIApplication) {
        let audit = app.staticTexts["uitest.team.share.audit"]
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: audit)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
        let log = XCTAttachment(string: audit.value as? String ?? "nil")
        log.name = "隔离服务器实际写请求与既有分享"
        log.lifetime = .keepAlways
        add(log)
        capture("取消或分享后的实际请求与既有目标", in: app)
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
