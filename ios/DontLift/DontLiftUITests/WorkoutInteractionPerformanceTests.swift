import XCTest

/// 在专用模拟器运行。XCTest 的 tap 墙钟含自动化等待，不能冒充触摸到显示延迟。
final class WorkoutInteractionPerformanceTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLargeHistoryRepeatedCompletion() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-history-count", "600", "-profile-workout", "-dismiss-career-review"]
        app.launch()
        let check = app.buttons["workout.set.complete.0"].firstMatch
        XCTAssertTrue(check.waitForExistence(timeout: 90))
        XCTAssertTrue(check.isHittable)
        for _ in 0..<30 {
            check.tap()
            XCTAssertTrue(check.label.contains("已完成"))
            check.tap()
            XCTAssertTrue(check.label.contains("标记"))
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLongWorkoutInputAndRestOverlay() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-history-count", "1000", "-profile-workout", "-profile-long-workout", "-dismiss-career-review"]
        app.launch()
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "重量")).firstMatch
        if !weight.waitForExistence(timeout: 15) {
            // 与现有 UI 套件一致：模拟器偶发未携带启动参数，重启后核验真实目标。
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(weight.waitForExistence(timeout: 90))
        weight.tap()
        let digit = app.buttons["数字 7"]
        XCTAssertTrue(digit.waitForExistence(timeout: 5))
        for _ in 0..<30 {
            digit.tap()
            app.buttons["删除"].tap()
        }
        digit.tap()
        app.buttons["收起键盘"].tap()
        XCTAssertTrue(weight.value as? String == "7 公斤")
        let check = app.buttons["workout.set.complete.0"].firstMatch
        check.tap()
        let rest = app.buttons["休息计时，点按展开"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 5))
        rest.tap()
        XCTAssertTrue(app.buttons["完成休息"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testColdRestoreTenTimes() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-history-count", "600", "-dismiss-career-review"]
        app.launch()
        XCTAssertTrue(app.buttons["workout.set.complete.0"].firstMatch.waitForExistence(timeout: 90))
        app.terminate()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-resume-workout", "-dismiss-career-review"]
        for _ in 0..<10 {
            app.launch()
            XCTAssertTrue(app.buttons["workout.set.complete.0"].firstMatch.waitForExistence(timeout: 30))
            app.terminate()
        }
    }
}
