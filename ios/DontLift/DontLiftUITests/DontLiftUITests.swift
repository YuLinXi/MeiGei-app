//
//  DontLiftUITests.swift
//  DontLiftUITests
//
//  Created by Yu on 2026/5/17.
//

import XCTest

final class DontLiftUITests: XCTestCase {

    /// 等待元素出现；若超时则 terminate 后带原参数重启一次再等到位。
    /// 冷启动（模拟器首次开机 + 安装）时 App 偶发停在登录页（种子/注入竞态，与环境相关），
    /// 重启后第二次即正常——这是环境性抖动，重试比拉长超时更有效。
    @MainActor
    private func waitForElementWithRelaunch(_ element: XCUIElement, in app: XCUIApplication,
                                            timeout: TimeInterval = 30) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }
        app.terminate()
        app.launch()
        return element.waitForExistence(timeout: timeout)
    }

    @MainActor
    func testAssistedWeightHintInWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-uitest-assisted-weight"]
        app.launch()
        let title = app.staticTexts["辅助引体向上"].firstMatch
        XCTAssertTrue(waitForElementWithRelaunch(title, in: app), "应直达训练进行中页面并显示种子动作")
        let hint = app.staticTexts["此动作记录辅助重量，辅助越小，难度越大。"]
        if !hint.exists { title.tap() }
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        XCTAssertTrue(hint.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testBadgeWallRepeatedEntryAndLazyScrolling() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-dev-seed-demo", "-tab-profile", "-dismiss-career-review"]
        app.launch()
        let entry = app.buttons["profile.badge.entry"]
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

    /// 排序统一弹窗（系统 sheet）：打开后底层页面（含导航栏按钮、结束训练、底部添加栏）被 scrim 封锁；
    /// 点「完成」关闭弹窗后一切恢复。依赖 -uitest-live-workout 钩子直达训练进行中页面。
    @MainActor
    func testReorderSheetBlocksOtherAreas() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uitest-live-workout")
        app.launch()

        // 冷启动偶发停在登录页：wait 内部会自动 terminate 重启一次再等到位。
        let sortButton = app.buttons["调整训练动作顺序"]
        XCTAssertTrue(waitForElementWithRelaunch(sortButton, in: app),
                      "应直达训练进行中页面并显示排序入口")

        let finishButton = app.buttons["结束训练"]
        XCTAssertTrue(finishButton.isHittable, "进入排序前「结束训练」可点击")

        sortButton.tap()

        // 排序统一弹窗（系统 sheet，默认 60% 高）：标题「训练动作排序」+ 实心「完成」胶囊。
        XCTAssertTrue(app.staticTexts["训练动作排序"].waitForExistence(timeout: 5),
                      "进入排序后应弹出「训练动作排序」弹窗")
        let doneButton = app.buttons["完成排序"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "弹窗内应显示「完成」按钮")
        XCTAssertTrue(doneButton.isHittable, "排序弹窗「完成」按钮必须可点击")

        // 系统 sheet 的 scrim 封锁底层页面：「结束训练」/导航栏/底部添加栏均不可命中。
        // （isHittable 会穿透纯视觉蒙层，但系统 sheet 的遮挡是真实命中测试，故可用 isHittable 断言。）
        XCTAssertFalse(finishButton.isHittable, "排序弹窗打开时「结束训练」应被封锁")
        XCTAssertFalse(app.buttons["收起训练"].isHittable, "排序弹窗打开时导航栏收起按钮应被封锁")
        XCTAssertFalse(app.buttons["训练更多操作"].isHittable, "排序弹窗打开时导航栏 ⋯ 菜单应被封锁")
        XCTAssertFalse(app.buttons["添加动作"].isHittable, "排序弹窗打开时底部添加动作栏应被封锁")

        // 排序行存在（3 个动作；第三个种子名「哑铃肩推」经内置库归并显示为「坐姿哑铃推肩」）。
        XCTAssertTrue(app.staticTexts["上斜杠铃卧推"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["杠铃划船"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["坐姿哑铃推肩"].waitForExistence(timeout: 3))

        // 真实拖拽（best-effort）：把末行拖到列表顶部（系统 EditMode 手柄，label 形如 "Reorder 坐姿哑铃推肩"）。
        // 注意：系统 sheet 的下滑关闭/detent 手势与 XCUI 合成拖拽事件相斥，录屏证实合成拖拽无法
        // 触发 sheet 内 List 的行浮起（真机手指长按手柄正常）。因此拖拽只尝试、不硬断言，
        // 排序正确性回归靠真机验证；本用例的硬断言是 sheet 的呈现/封锁/关闭恢复。
        let lastHandle = app.buttons["Reorder 坐姿哑铃推肩"]
        if lastHandle.waitForExistence(timeout: 2) {
            let firstHandle = app.buttons["Reorder 上斜杠铃卧推"]
            let dragStart = lastHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dropTarget = firstHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.5))
            dragStart.press(forDuration: 1.0, thenDragTo: dropTarget,
                            withVelocity: .slow, thenHoldForDuration: 0.6)
            Thread.sleep(forTimeInterval: 1.0)
            // 拖动后检查「坐姿哑铃推肩」是否上移到「上斜杠铃卧推」之上；未移动仅记录告警。
            let firstTitle = app.staticTexts["上斜杠铃卧推"].firstMatch
            let thirdTitle = app.staticTexts["坐姿哑铃推肩"].firstMatch
            if thirdTitle.frame.minY >= firstTitle.frame.minY {
                print("[UITest] 合成拖拽未触发 sheet 内行重排（已知 XCUI 限制），排序回归需真机验证")
            }
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
