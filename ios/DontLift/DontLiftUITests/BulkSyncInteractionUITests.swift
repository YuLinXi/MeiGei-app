import XCTest

/// 新建隔离 SQLite，真实页面操作与 5000 条 HTTP fixture 下拉同时进行；不连接后端。
final class BulkSyncInteractionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testInputCompletionAndNavigationDuringBulkHistoryRestore() throws {
        try check(updating: false)
    }

    @MainActor func testInputCompletionAndNavigationDuringBulkHistoryUpdate() throws {
        try check(updating: true)
    }

    @MainActor private func check(updating: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-bulk-sync",
                               "-tab-profile", "-dismiss-career-review", "-uitest-typography-size", "large"]
        if updating { app.launchArguments.append("-uitest-bulk-sync-update") }
        app.launch()
        let collapse = app.buttons["收起训练"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 15))
        collapse.tap()
        let sync = app.buttons["profile.sync"]
        for _ in 0..<8 where !sync.isHittable { app.swipeUp() }
        XCTAssertTrue(sync.waitForExistence(timeout: 15))
        let progress = app.staticTexts["uitest.sync.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForProgress(progress, timeout: 5) { $0.contains("|set:") })
        let initial = try XCTUnwrap(progress.value as? String)
        let initialIdentity = initial.components(separatedBy: "|").filter {
            $0.hasPrefix("active:") || $0.hasPrefix("set:")
        }
        XCTAssertEqual(initialIdentity.count, 2)
        sync.tap()
        if updating {
            XCTAssertTrue(waitForProgress(progress, timeout: 180) {
                $0.hasPrefix("idle|") && self.count(in: $0) == 5001
            })
            XCTAssertTrue(app.staticTexts["总训练次数 5000 次"].waitForExistence(timeout: 30))
            sync.tap()
        }
        let field = updating ? "updated" : "count"
        XCTAssertTrue(waitForProgress(progress, timeout: 30) { value in
            value.hasPrefix("busy|") && self.count(field, in: value) > 1 && self.count(field, in: value) < 5000
        })
        let during = try XCTUnwrap(progress.value as? String)
        app.tabBars.buttons["训练"].tap()
        let resume = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "继续训练 UI 测试训练")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        let weight = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "重量")).firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        weight.tap()
        XCTAssertTrue(app.buttons["数字 7"].waitForExistence(timeout: 5))
        app.buttons["数字 7"].tap()
        app.buttons["数字 7"].tap()
        app.buttons["收起键盘"].tap()
        XCTAssertEqual(weight.value as? String, "77 公斤")
        let check = app.buttons["workout.set.complete.0"].firstMatch
        check.tap()
        XCTAssertTrue(check.label.contains("已完成"))
        XCTAssertTrue(app.buttons["休息计时，点按展开"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["收起训练"].tap()
        XCTAssertTrue(waitForProgress(progress, timeout: 10) { value in
            value.hasPrefix("busy|") && value.contains("weight:77.0|completed:true")
        })
        let savedDuring = try XCTUnwrap(progress.value as? String)
        XCTAssertGreaterThan(count(field, in: savedDuring), count(field, in: during))
        for identity in initialIdentity { XCTAssertTrue(savedDuring.contains(identity)) }
        let restEnd = try XCTUnwrap(savedDuring.components(separatedBy: "|").first { $0.hasPrefix("restEnd:") })
        let restDeadline = try XCTUnwrap(Double(restEnd.dropFirst(8).replacingOccurrences(of: ",", with: "")))
        XCTAssertGreaterThan(restDeadline, Date.now.timeIntervalSince1970)
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(sync.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForProgress(progress, timeout: 180) { value in
            value.hasPrefix("idle|") && self.count(in: value) == 5001
                && (!updating || self.count("updated", in: value) == 5000)
        })
        XCTAssertEqual(sync.value as? String, "上次同步成功")
        let finished = try XCTUnwrap(progress.value as? String)
        XCTAssertTrue(finished.contains("weight:77.0|completed:true"))
        XCTAssertTrue(finished.contains(restEnd))
        for identity in initialIdentity { XCTAssertTrue(finished.contains(identity)) }
        XCTAssertTrue(app.staticTexts["总训练次数 5000 次"].waitForExistence(timeout: 30))
        print("[S4-bulk-ui] mode=\(updating ? "update" : "restore") initial=\(initial) during=\(during) saved=\(savedDuring) finished=\(finished)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "批量历史\(updating ? "更新" : "恢复")后保留已落盘训练输入"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    private func count(_ key: String = "count", in value: String) -> Int {
        let field = value.components(separatedBy: "|").first { $0.hasPrefix(key + ":") }
        return Int(field?.dropFirst(key.count + 1) ?? "") ?? -1
    }

    @MainActor private func waitForProgress(_ element: XCUIElement, timeout: TimeInterval,
                                           matches: @escaping (String) -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in matches(element.value as? String ?? "") }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                             timeout: timeout) == .completed
    }
}
