import XCTest

/// 复用当前模拟器的独立性能库。XCTest 的 tap 墙钟含自动化等待，不能冒充触摸到显示延迟。
final class WorkoutInteractionPerformanceTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// 先准备数据，再由外部采集器重新启动；播种成本不混入冷启动或交互指标。
    @MainActor
    func testPreparePerformanceDataset() throws {
        let env = ProcessInfo.processInfo.environment
        guard let count = Int(env["DONTLIFT_PROFILE_HISTORY_COUNT"] ?? "600"), count >= 0 else {
            XCTFail("性能历史条数必须是非负整数")
            return
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-history-count", String(count),
                               "-dismiss-career-review"]
        if env["DONTLIFT_PROFILE_LONG_WORKOUT"] == "1" { app.launchArguments.append("-profile-long-workout") }
        app.launch()
        let check = app.buttons["workout.set.complete.0"].firstMatch
        recoverInitialLoginIfNeeded(check, in: app)
        XCTAssertTrue(check.waitForExistence(timeout: 90))
        XCTAssertTrue(check.isHittable)
        print("[S4-seed] history=\(count) long=\(env["DONTLIFT_PROFILE_LONG_WORKOUT"] == "1")")
        app.terminate()
    }

    @MainActor
    func testLargeHistoryRepeatedCompletion() async throws {
        try prepareProfilerHandshake()
        XCUIDevice.shared.orientation = .portrait
        let env = ProcessInfo.processInfo.environment
        guard let count = Int(env["DONTLIFT_PROFILE_HISTORY_COUNT"] ?? "600"), count >= 0 else {
            XCTFail("性能历史条数必须是非负整数")
            return
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-history-count", String(count), "-profile-workout", "-dismiss-career-review"]
        if env["DONTLIFT_PROFILE_LONG_WORKOUT"] == "1" { app.launchArguments.append("-profile-long-workout") }
        app.launch()
        let check = app.buttons["workout.set.complete.0"].firstMatch
        recoverInitialLoginIfNeeded(check, in: app)
        XCTAssertTrue(check.waitForExistence(timeout: 90))
        app.terminate()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-resume-workout", "-dismiss-career-review"]
        app.launch()
        recoverInitialLoginIfNeeded(check, in: app)
        XCTAssertTrue(check.waitForExistence(timeout: 90))
        XCTAssertTrue(check.isHittable)
        print("[S4-cell] history=\(count) long=\(env["DONTLIFT_PROFILE_LONG_WORKOUT"] == "1") resumed=true cycles=30")
        try await waitForProfiler("start")
        if env["DONTLIFT_PROFILE_METRICS"] == "1" {
            let frame = check.frame
            let point = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            let options = XCTMeasureOptions()
            options.iterationCount = 30
            measure(metrics: interactionMetrics(for: app), options: options) {
                point.tap()
                point.tap()
            }
            XCTAssertTrue(check.label.contains("标记"))
        } else {
            for _ in 0..<30 {
                check.tap()
                XCTAssertTrue(check.label.contains("已完成"))
                check.tap()
                XCTAssertTrue(check.label.contains("标记"))
            }
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try await waitForProfiler("stop")
    }

    /// 与现有隔离 UI 套件一致，仅对仍在登录页的首次启动恢复一次；播种慢不触发重启。
    @MainActor
    private func recoverInitialLoginIfNeeded(_ target: XCUIElement, in app: XCUIApplication) {
        guard !target.waitForExistence(timeout: 15), app.buttons["Sign in with Apple"].exists else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "性能场景首启仍在登录页"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("[S4-environment] initial-login-recovery=1")
        app.terminate()
        app.launch()
    }

    /// 仅外部采集时启用；让采集器就绪后开始交互、报告取回后结束宿主。
    private var profilerHandshakeEnabled: Bool {
        ProcessInfo.processInfo.environment["DONTLIFT_PROFILE_HANDSHAKE"] == "1"
    }

    private func profilerMarker(_ phase: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("dontlift-s4-profile.\(phase)")
    }

    private func prepareProfilerHandshake(phases: [String] = ["start", "stop"]) throws {
        guard profilerHandshakeEnabled else { return }
        for phase in phases {
            let marker = profilerMarker(phase)
            if FileManager.default.fileExists(atPath: marker.path) {
                try FileManager.default.removeItem(at: marker)
            }
        }
    }

    private func waitForProfiler(_ phase: String) async throws {
        guard profilerHandshakeEnabled else { return }
        let marker = profilerMarker(phase)
        print("[S4-profile] waiting=\(phase) marker=\(marker.path)")
        let started = ContinuousClock.now
        while !FileManager.default.fileExists(atPath: marker.path) {
            if started.duration(to: .now) >= .seconds(90) {
                XCTFail("外部采集未在90秒内确认\(phase)")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
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
        let check = app.buttons["workout.set.complete.0"].firstMatch
        recoverInitialLoginIfNeeded(check, in: app)
        XCTAssertTrue(check.waitForExistence(timeout: 90))
        app.terminate()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-resume-workout", "-dismiss-career-review"]
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            XCTAssertTrue(check.waitForExistence(timeout: 30))
            XCTAssertTrue(check.isHittable)
        }
        app.terminate()
    }

    /// 测量整个个人分组展开/折叠；外部采集模式保留冷展开，由 HID 驱动并在退出前取回报告。
    @MainActor
    func testPlanGroupExpansionAtScale() async throws {
        try prepareProfilerHandshake()
        let env = ProcessInfo.processInfo.environment
        guard let count = Int(env["DONTLIFT_PROFILE_PLAN_COUNT"] ?? "100"), count >= 0 else {
            XCTFail("性能个人计划份数必须是非负整数")
            return
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-history-count", "600",
                               "-profile-plan-count", String(count), "-dismiss-career-review"]
        app.launch()
        let minimize = app.buttons["收起训练"]
        recoverInitialLoginIfNeeded(minimize, in: app)
        XCTAssertTrue(minimize.waitForExistence(timeout: 90))
        app.terminate()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-resume-workout", "-dismiss-career-review"]
        app.launch()
        recoverInitialLoginIfNeeded(minimize, in: app)
        XCTAssertTrue(minimize.waitForExistence(timeout: 90))
        minimize.tap()
        let plans = app.tabBars.buttons["计划"]
        XCTAssertTrue(plans.waitForExistence(timeout: 5))
        plans.tap()
        let options = XCTMeasureOptions()
        options.iterationCount = 30
        if count == 0 {
            XCTAssertTrue(app.staticTexts["还没有计划"].waitForExistence(timeout: 5))
            app.tabBars.buttons["训练"].tap()
            measure(metrics: interactionMetrics(for: app), options: options) {
                plans.tap()
                app.tabBars.buttons["训练"].tap()
            }
        } else {
            let header = app.buttons["展开性能计划分组"]
            XCTAssertTrue(header.waitForExistence(timeout: 5))
            XCTAssertTrue(header.isHittable)
            let frame = header.frame
            let point = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            print("[S4-plan] count=\(count) center=\(frame.midX),\(frame.midY)")
            if profilerHandshakeEnabled {
                try await waitForProfiler("start")
                try await waitForProfiler("stop")
            } else {
                measure(metrics: interactionMetrics(for: app), options: options) {
                    point.tap()
                    point.tap()
                }
            }
            XCTAssertTrue(header.exists)
            XCTAssertEqual(header.value as? String, "已折叠，\(count) 个计划")
            // 计量结束后实际滚动到末项并打开，防止按需渲染使远端计划不可达。
            header.tap()
            let name = String(format: "性能个人计划 %03d · 胸背力量与训练复盘", count - 1)
            let last = app.buttons["打开计划" + name]
            for _ in 0..<max(10, count) where !last.exists || !last.isHittable { app.swipeUp() }
            XCTAssertTrue(last.exists && last.isHittable)
            let lastRow = XCTAttachment(screenshot: app.screenshot())
            lastRow.name = "大分组末项可达：\(count)份"
            lastRow.lifetime = .keepAlways
            add(lastRow)
            last.tap()
            XCTAssertTrue(app.buttons["自适应模式，查看规则"].waitForExistence(timeout: 10))
            app.buttons["返回"].tap()
            XCTAssertTrue(app.buttons["添加计划或分组"].waitForExistence(timeout: 5))
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// 固定可见区域往返滚动；统计预热后的滚动，冷缓存另行采集，不混报。
    @MainActor
    func testExerciseLibraryWarmScrollingMetrics() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-dismiss-career-review"]
        app.launch()
        let tab = app.tabBars.buttons["动作"]
        recoverInitialLoginIfNeeded(tab, in: app)
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(app.textFields["exercise.search"].waitForExistence(timeout: 10))
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "，")).firstMatch
        XCTAssertTrue(card.isHittable)
        let original = card.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let bottom = origin.withOffset(CGVector(dx: app.frame.width * 0.64, dy: app.frame.height * 0.7))
        let top = origin.withOffset(CGVector(dx: app.frame.width * 0.64, dy: app.frame.height * 0.35))
        bottom.press(forDuration: 0.01, thenDragTo: top)
        XCTAssertTrue(!card.exists || card.frame.minY < original.minY - 10)
        top.press(forDuration: 0.01, thenDragTo: bottom)
        let options = XCTMeasureOptions()
        options.iterationCount = 30
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric] + interactionMetrics(for: app), options: options) {
            bottom.press(forDuration: 0.01, thenDragTo: top)
            top.press(forDuration: 0.01, thenDragTo: bottom)
        }
        XCTAssertTrue(app.textFields["exercise.search"].isHittable)
    }

    /// 三类查询各输入并清空；原生 CPU/内存包含自动化与辅助功能成本，不代表可见反馈延迟。
    @MainActor
    func testExerciseLibrarySearchMetrics() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow",
                               "-clear-active-workout", "-dismiss-career-review"]
        app.launch()
        let tab = app.tabBars.buttons["动作"]
        XCTAssertTrue(waitForIsolatedUITestScene(tab, in: app))
        tab.tap()
        let search = app.textFields["exercise.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        let queries = [("杠铃 卧推", "杠铃卧推"), ("宽握高位下拉", "高位下拉"), ("BB_BENCH_PRESS", "杠铃卧推")]
        var clearFrame = CGRect.zero
        for (query, expectedName) in queries {
            search.typeText(query)
            let result = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", expectedName + "，")).firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 5), "查询必须返回标准动作：\(query)")
            let clear = app.buttons["清除搜索"]
            XCTAssertTrue(clear.isHittable)
            clearFrame = clear.frame
            clear.tap()
            XCTAssertFalse(clear.exists)
        }
        let clearPoint = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: clearFrame.midX, dy: clearFrame.midY))
        let options = XCTMeasureOptions()
        options.iterationCount = 30
        print("[S4-search] queries=multi-keyword,alias,legacy-code cycles=30 metrics=cpu,memory")
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            for (query, _) in queries {
                search.typeText(query)
                clearPoint.tap()
            }
        }
        XCTAssertFalse(app.buttons["清除搜索"].exists)
        XCTAssertTrue(search.isHittable)
    }

    /// 播种与首次加载在计量外；每个样本包含上月/本月往返，不将自动化墙钟作为切月延迟。
    @MainActor
    func testCalendarMonthSwitchingAtHistoryScale() throws {
        let env = ProcessInfo.processInfo.environment
        guard let count = Int(env["DONTLIFT_PROFILE_HISTORY_COUNT"] ?? "600"), count >= 0 else {
            XCTFail("性能历史条数必须是非负整数")
            return
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-history-count", String(count),
                               "-dismiss-career-review"]
        app.launch()
        let minimize = app.buttons["收起训练"]
        recoverInitialLoginIfNeeded(minimize, in: app)
        XCTAssertTrue(minimize.waitForExistence(timeout: 90))
        // 播种与计量使用不同进程，排除插入/删除测试聚合后仍驻留的对象。
        app.terminate()
        app.launchArguments = ["-uitest-live-workout", "-profile-workout", "-profile-resume-workout", "-dismiss-career-review"]
        app.launch()
        XCTAssertTrue(minimize.waitForExistence(timeout: 90))
        minimize.tap()
        let entry = app.buttons["历史日历"]
        XCTAssertTrue(entry.waitForExistence(timeout: 60))
        // 首页加载态入口可位于110pt以上；该根页没有导航栏，按实际可点击性判定。
        XCTAssertTrue(entry.isHittable)
        print("[S4-calendar-entry] frame=\(entry.frame)")
        entry.tap()
        let summary = app.staticTexts["calendar.month.summary"]
        let calendar = Calendar.current
        let now = Date.now
        let interval = try XCTUnwrap(calendar.dateInterval(of: .month, for: now))
        let expected = (0..<count).filter {
            interval.contains(now.addingTimeInterval(-Double($0 + 1) * 86400))
        }.count
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", "\(expected) 次训练"), object: summary)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
        let previous = app.buttons["上个月"]
        let next = app.buttons["下个月"]
        XCTAssertTrue(previous.isHittable && previous.isEnabled && next.isHittable)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let previousPoint = origin.withOffset(CGVector(dx: previous.frame.midX, dy: previous.frame.midY))
        let nextPoint = origin.withOffset(CGVector(dx: next.frame.midX, dy: next.frame.midY))
        previousPoint.tap()
        nextPoint.tap()
        let options = XCTMeasureOptions()
        options.iterationCount = 30
        print("[S4-calendar] history=\(count) expected-current-month=\(expected) cycles=30 metrics=cpu,memory")
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            previousPoint.tap()
            nextPoint.tap()
        }
        XCTAssertTrue(summary.label.hasPrefix("\(expected) 次训练"))
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        XCTAssertTrue(app.staticTexts["\(year)年 \(month)月"].exists)
        app.buttons["选择月份"].tap()
        let currentMonth = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(year)年\(month)月，")).firstMatch
        XCTAssertTrue(currentMonth.waitForExistence(timeout: 5))
        XCTAssertTrue(currentMonth.label.contains(expected > 0 ? "\(expected)次训练" : "没有训练"))
        currentMonth.tap()
        XCTAssertTrue(app.staticTexts["选择月份"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(summary.label.hasPrefix("\(expected) 次训练"))
    }

    /// 同一进程往返计划、历史、海报与徽章；内存采样不加载 ETTrace，避免工具自身分配干扰。
    @MainActor
    func testRepeatedNavigationMemory() async throws {
        try prepareProfilerHandshake()
        guard let iterations = Int(ProcessInfo.processInfo.environment["DONTLIFT_MEMORY_ITERATIONS"] ?? "20"), iterations > 0 else {
            XCTFail("内存采样轮数必须为正整数")
            return
        }
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow", "-clear-active-workout",
                               "-uitest-history-save", "-uitest-plan-readability", "-uitest-badge-readability", "-dismiss-career-review"]
        app.launch()
        let plans = app.tabBars.buttons["计划"]
        recoverInitialLoginIfNeeded(plans, in: app)
        XCTAssertTrue(plans.waitForExistence(timeout: 15))
        var rounds = 0
        func round() -> Bool {
            plans.tap()
            let group = app.buttons["展开UI 大字分组 · 长期力量与稳定控制"]
            if group.exists { group.tap() }
            let plan = app.buttons["打开计划UI 大字计划 · 胸背力量与训练复盘"]
            revealMemoryTarget(plan, in: app)
            plan.tap()
            XCTAssertTrue(app.buttons["计划更多操作"].waitForExistence(timeout: 5))
            app.buttons["返回"].firstMatch.tap()

            app.tabBars.buttons["训练"].tap()
            let history = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "UI 另存胸背")).firstMatch
            revealMemoryTarget(history, in: app)
            history.tap()
            let more = app.buttons["训练更多操作"]
            XCTAssertTrue(more.waitForExistence(timeout: 5))
            more.tap()
            app.buttons["分享训练海报"].tap()
            let save = app.buttons["保存图片"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            // 使用系统 sheet 拖动关闭；不申请照片权限、不写入相册。
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.midX, dy: 72))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.height * 0.8)),
                       withVelocity: .fast, thenHoldForDuration: 0.1)
            guard save.waitForNonExistence(timeout: 5) else {
                XCTFail("海报弹层未关闭，不继续执行或采样后续页面")
                return false
            }
            XCTAssertTrue(more.isHittable)
            app.buttons["返回"].firstMatch.tap()

            app.tabBars.buttons["我的"].tap()
            let entry = app.buttons["profile.badge.entry"]
            revealMemoryTarget(entry, in: app)
            entry.tap()
            let summary = app.staticTexts["badge.wall.summary"]
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "ready:"), object: summary)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
            let badge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "badge.wall.item.")).firstMatch
            revealMemoryTarget(badge, in: app)
            badge.tap()
            let close = app.buttons["关闭"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 5))
            app.buttons["返回"].firstMatch.tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            rounds += 1
            print("[S4-memory] completed-round=\(rounds)")
            return true
        }
        guard round() else { return }
        try await waitForProfiler("start")
        let options = XCTMeasureOptions()
        options.iterationCount = iterations
        var failed = false
        measure(metrics: [XCTMemoryMetric(application: app)], options: options) {
            guard !failed else { return }
            failed = !round()
        }
        print("[S4-memory] measured-iterations=\(iterations) actual-rounds=\(rounds)")
        try await waitForProfiler("stop")
    }

    @MainActor
    private func revealMemoryTarget(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            let tab = app.tabBars.firstMatch
            let tabTop = tab.exists && tab.isHittable ? tab.frame.minY - 8 : app.frame.maxY - 34
            if element.exists && element.isHittable && element.frame.minY >= 110 && element.frame.maxY < tabTop { return }
            let upwards = !element.exists || element.frame.minY >= tabTop
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.width - 10, dy: upwards ? 550 : 280))
                .press(forDuration: 0.01, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width - 10, dy: upwards ? 350 : 480)))
        }
        XCTFail("内存场景目标未进入可用区域：\(element)")
    }

    @MainActor
    private func interactionMetrics(for app: XCUIApplication) -> [XCTMetric] {
        var metrics: [XCTMetric] = [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)]
        if #available(iOS 26.0, *) { metrics.append(XCTHitchMetric(application: app)) }
        return metrics
    }

    /// 首次进入与同进程再次滚动分别取样；数据来自既有全新内存场景，图片仍走正式目录。
    @MainActor
    func testExerciseArtworkColdAndWarmProfile() async throws {
        try prepareProfilerHandshake(phases: ["start", "stop", "warm-start", "warm-stop"])
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow",
                               "-profile-workout", "-dismiss-career-review"]
        app.launch()
        let minimize = app.buttons["收起训练"]
        recoverInitialLoginIfNeeded(minimize, in: app)
        XCTAssertTrue(minimize.waitForExistence(timeout: 90))
        minimize.tap()
        let tab = app.tabBars.buttons["动作"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        let frame = app.frame
        print("[S4-library] tab=\(tab.frame.midX),\(tab.frame.midY) grid=\(frame.width * 0.64),\(frame.height * 0.7),\(frame.height * 0.35)")
        if profilerHandshakeEnabled {
            try await waitForProfiler("start")
            try await waitForProfiler("stop")
            XCTAssertTrue(app.textFields["exercise.search"].waitForExistence(timeout: 10))
            try await waitForProfiler("warm-start")
            try await waitForProfiler("warm-stop")
        } else {
            tab.tap()
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let bottom = origin.withOffset(CGVector(dx: frame.width * 0.64, dy: frame.height * 0.7))
            let top = origin.withOffset(CGVector(dx: frame.width * 0.64, dy: frame.height * 0.35))
            for _ in 0..<5 { bottom.press(forDuration: 0.01, thenDragTo: top) }
            for _ in 0..<5 { top.press(forDuration: 0.01, thenDragTo: bottom) }
        }
        XCTAssertTrue(app.textFields["exercise.search"].isHittable)
        XCTAssertTrue(tab.isSelected)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
