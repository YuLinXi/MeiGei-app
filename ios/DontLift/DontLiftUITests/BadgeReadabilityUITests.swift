import XCTest

final class BadgeReadabilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testWallAtDefaultReadingSize() throws { checkWall(size: "large") }
    @MainActor func testWallAtXXXLReadingSize() throws { checkWall(size: "xxxLarge") }
    @MainActor func testWallAtLargestReadingSize() throws { checkWall(size: "accessibility5") }
    @MainActor func testSingleCelebrationAtDefaultReadingSize() throws { checkCelebration(size: "large", single: true) }
    @MainActor func testSingleCelebrationAtLargestReadingSize() throws { checkCelebration(size: "accessibility5", single: true) }
    @MainActor func testMultiCelebrationAtDefaultReadingSize() throws { checkCelebration(size: "large", single: false) }
    @MainActor func testMultiCelebrationAtLargestReadingSize() throws { checkCelebration(size: "accessibility5", single: false) }
    @MainActor func testCareerReviewAtDefaultReadingSize() throws { checkCareer(size: "large") }
    @MainActor func testCareerReviewAtLargestReadingSize() throws { checkCareer(size: "accessibility5") }

    @MainActor private func checkWall(size: String) {
        let app = launch(size: size, flags: ["-tab-profile"])
        let entry = app.buttons["profile.badge.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        reveal(entry, in: app)
        entry.tap()
        let summary = app.staticTexts["badge.wall.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "ready:"), object: summary)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        let counts = summary.value as? String
        capture("徽章墙：\(size)", in: app)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "徽章墙辅助功能树：\(size)"
        tree.lifetime = .keepAlways
        add(tree)
        if size == "accessibility5" { XCTAssertGreaterThanOrEqual(summary.frame.height, 40) }
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "badge.wall.item.")).firstMatch
        reveal(first, in: app)
        XCTAssertFalse(first.label.isEmpty)
        XCTAssertFalse((first.value as? String ?? "").isEmpty)
        first.tap()
        let close = app.buttons["关闭"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let button = object as? XCUIElement else { return false }
            return button.isHittable && button.frame.height + 0.001 >= 44
        }, object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
        XCTAssertGreaterThanOrEqual(close.frame.height + 0.001, 44)
        capture("徽章详情与关闭：\(size)", in: app)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertEqual(summary.value as? String, counts)
        XCTAssertTrue(app.buttons["返回"].firstMatch.isHittable)
    }

    @MainActor private func checkCelebration(size: String, single: Bool) {
        var flags = ["-test-badge-celebration"]
        if single { flags.append("-test-badge-celebration-single") }
        let app = launch(size: size, flags: flags)
        let title = app.staticTexts["新徽章已解锁"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        capture("\(single ? "单枚" : "多枚")徽章庆祝：\(size)", in: app)
        if size == "accessibility5" { XCTAssertGreaterThanOrEqual(title.frame.height, 35) }
        let done = app.buttons["收下荣誉"]
        reveal(done, in: app)
        XCTAssertGreaterThanOrEqual(done.frame.height + 0.001, 44)
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(mainTab("训练", in: app).isHittable)
    }

    @MainActor private func checkCareer(size: String) {
        let app = launch(size: size, flags: ["-test-career-review"])
        let title = app.staticTexts["力量生涯成就回顾"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(title.frame.minX, 16)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX - 16)
        capture("生涯回顾：\(size)", in: app)
        if size == "accessibility5" { XCTAssertGreaterThanOrEqual(title.frame.height, 40) }
        let done = app.buttons["全部收入我的徽章馆"]
        reveal(done, in: app)
        XCTAssertGreaterThanOrEqual(done.frame.height + 0.001, 44)
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(mainTab("训练", in: app).isHittable)
    }

    @MainActor private func launch(size: String, flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-badge-readability", "-clear-active-workout",
                               "-dismiss-career-review", "-uitest-typography-size", size] + flags
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
