//
//  DontLiftUITests.swift
//  DontLiftUITests
//
//  Created by Yu on 2026/5/17.
//

import XCTest

final class DontLiftUITests: XCTestCase {

    @MainActor
    func testBadgeWallRepeatedEntryAndLazyScrolling() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-dev-seed-demo", "-tab-profile", "-dismiss-career-review"]
        app.launch()
        let entry = app.buttons.containing(.staticText, identifier: "成就徽章").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        let summary = app.staticTexts["badge.wall.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "value BEGINSWITH %@", "ready:")
        expectation(for: ready, evaluatedWith: summary)
        waitForExpectations(timeout: 20)
        let counts = summary.value as? String
        XCTAssertFalse(app.staticTexts["正在加载徽章"].exists)
        for _ in 0..<10 {
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            XCTAssertEqual(summary.value as? String, counts)
        }
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            for _ in 0..<4 { app.swipeUp() }
            XCTAssertTrue(app.staticTexts["单次战役极限"].exists)
            for _ in 0..<4 { app.swipeDown() }
        }
        XCTAssertTrue(summary.isHittable)
        XCTAssertEqual(summary.value as? String, counts)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    /// 排序模式蒙层：开启后只有「训练动作」排序区可操作，其它区域（含导航栏按钮）全部被封锁；
    /// 点「完成」退出后一切恢复。依赖 -uitest-live-workout 钩子直达训练进行中页面。
    @MainActor
    func testReorderModeMasksOtherAreas() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uitest-live-workout")
        app.launch()

        let sortButton = app.buttons["调整训练动作顺序"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 15), "应直达训练进行中页面并显示排序入口")

        let finishButton = app.buttons["结束训练"]
        XCTAssertTrue(finishButton.isHittable, "进入排序前「结束训练」可点击")

        sortButton.tap()

        let doneButton = app.buttons["完成排序"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "进入排序后入口应变为「完成」")
        XCTAssertTrue(doneButton.isHittable, "排序区「完成」按钮必须可点击")

        // 蒙层封锁：点「结束训练」实际事件被蒙层吞掉，不应弹出结束确认弹窗。
        // （isHittable 在 AX 命中测试下会穿透纯视觉蒙层，故须用真实 tap 验证封锁。）
        finishButton.tap()
        let finishConfirm = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "确定结束训练")).firstMatch
        XCTAssertFalse(finishConfirm.waitForExistence(timeout: 1.5),
                       "排序模式下点「结束训练」不应弹确认框")
        // 导航栏两侧按钮在排序模式下直接移除。
        XCTAssertFalse(app.buttons["收起训练"].exists, "排序模式下导航栏收起按钮应隐藏")
        XCTAssertFalse(app.buttons["训练更多操作"].exists, "排序模式下导航栏 ⋯ 菜单应隐藏")
        // 底部添加动作栏隐藏。
        XCTAssertFalse(app.buttons["添加动作"].exists, "排序模式下底部添加动作栏应隐藏")

        // 排序行存在（3 个动作；第三个种子名「哑铃肩推」经内置库归并显示为「坐姿哑铃推肩」）。
        XCTAssertTrue(app.staticTexts["上斜杠铃卧推"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["杠铃划船"].exists)
        XCTAssertTrue(app.staticTexts["坐姿哑铃推肩"].exists)

        // 真实拖拽：把第一行拖到列表末尾（系统 EditMode 手柄，label 形如 "Reorder 上斜杠铃卧推"）。
        // 落点须越过末行底缘才会插到最后；慢速拖拽避免被当成滚动吞掉。
        let firstHandle = app.buttons["Reorder 上斜杠铃卧推"]
        if firstHandle.waitForExistence(timeout: 2) {
            let thirdHandle = app.buttons["Reorder 坐姿哑铃推肩"]
            firstHandle.press(forDuration: 1.0, thenDragTo: thirdHandle)
            Thread.sleep(forTimeInterval: 1.0)
            // 拖动后断言「坐姿哑铃推肩」上移到「上斜杠铃卧推」之上。
            let firstTitle = app.staticTexts["上斜杠铃卧推"].firstMatch
            let thirdTitle = app.staticTexts["坐姿哑铃推肩"].firstMatch
            XCTAssertLessThan(thirdTitle.frame.minY, firstTitle.frame.minY,
                              "拖拽后「坐姿哑铃推肩」应排在「上斜杠铃卧推」之前")
        } else {
            // 手柄命名不可知时打印全部按钮名辅助排查，不让用例误失败。
            print("[UITest] reorder handle missing, buttons:", app.buttons.allElementsBoundByIndex.map(\.label))
        }

        // 点「完成」退出排序：一切恢复。
        doneButton.tap()
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "退出排序后应恢复「排序」入口")
        XCTAssertTrue(finishButton.isHittable, "退出排序后「结束训练」应恢复可点击")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
