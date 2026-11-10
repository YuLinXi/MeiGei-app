import XCTest

final class WorkoutPosterExportUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLongWorkoutCanSwitchShareCancelAndReturn() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow",
                               "-uitest-long-poster", "-uitest-history-loading", "-dismiss-career-review"]
        app.launch()
        let history = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI 长训练海报")).firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(history, in: app))
        reveal(history, in: app)
        history.tap()
        let more = app.buttons["训练更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["分享训练海报"].tap()
        let save = app.buttons["保存图片"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))

        let backgrounds = ["完成庆典台", "能量环游轨迹", "迷你综合训练场", "伙伴击掌", "训练装备花环"]
        for name in backgrounds {
            let option = app.buttons[name + "版式"]
            XCTAssertTrue(option.exists)
            XCTAssertTrue(option.isHittable)
            option.tap()
            XCTAssertEqual(option.value as? String, "已选择")
            let preview = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", name + "训练海报预览")).firstMatch
            XCTAssertTrue(preview.waitForExistence(timeout: 5))
            let summary = preview.value as? String ?? ""
            XCTAssertTrue(summary.contains("100 组，20 个动作"), summary)
            XCTAssertTrue(summary.contains("UI 海报动作 01") && summary.contains("UI 海报动作 20"), summary)
        }
        capture("长训练最后版式包含首尾动作", in: app)

        let share = app.buttons["分享"].firstMatch
        XCTAssertTrue(share.isHittable)
        share.tap()
        let saveImage = app.cells.matching(NSPredicate(format: "label IN %@", ["Save Image", "存储图像", "保存图像"])).firstMatch
        XCTAssertTrue(saveImage.waitForExistence(timeout: 20), "系统分享面板应包含图片保存操作")
        capture("长训练实际系统图片分享面板", in: app)
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Close", "关闭"])).firstMatch
        XCTAssertTrue(close.exists)
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(saveImage.waitForNonExistence(timeout: 5))
        XCTAssertTrue(share.isHittable)
        XCTAssertEqual(app.buttons["训练装备花环版式"].value as? String, "已选择")
        capture("取消系统分享后保留当前版式", in: app)

        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: app.frame.midX, dy: 72)).press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.height * 0.85)),
            withVelocity: .fast, thenHoldForDuration: 0.1)
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertTrue(more.isHittable)
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        XCTAssertTrue(history.label.contains("20 个动作") && history.label.contains("100 组"))
        capture("关闭海报后长训练仍在历史列表", in: app)
    }

    @MainActor
    func testPhotoPermissionDenialKeepsPreviewAndRetry() throws {
        checkPhotoPermissionDenial(size: "large")
    }

    @MainActor
    func testPhotoPermissionDenialAtLargestSize() throws {
        checkPhotoPermissionDenial(size: "accessibility5")
    }

    @MainActor private func checkPhotoPermissionDenial(size: String) {
        let app = openLongPoster(size: size, resetPhotosAuthorization: true)
        app.buttons["伙伴击掌版式"].tap()
        app.buttons["保存图片"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Don't Allow", "不允许"])).firstMatch
        let error = app.staticTexts["未获得相册写入权限，请在系统设置中允许添加照片后重试。"].firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 10), "每个权限用例应独立触发真实系统授权弹窗")
        deny.tap()
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        let save = app.buttons["保存图片"]
        XCTAssertLessThan(error.frame.maxY, save.frame.minY, "完整错误提示不应遮住底部保存操作")
        capture("拒绝权限后完整说明设置与重试：" + size, in: app)
        XCTAssertFalse(app.buttons["已保存"].exists)
        XCTAssertTrue(save.isEnabled)
        XCTAssertEqual(app.buttons["伙伴击掌版式"].value as? String, "已选择")
        XCTAssertTrue(error.waitForNonExistence(timeout: 7), "先等待旧提示消失，再验证重试产生的新反馈")
        save.tap()
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        capture("未授权时重试仍有准确错误：" + size, in: app)
    }

    @MainActor
    func testAuthorizedPhotoSaveTracksCurrentBackground() throws {
        let app = openLongPoster(resetPhotosAuthorization: true)
        for name in ["伙伴击掌", "完成庆典台"] {
            app.buttons[name + "版式"].tap()
            let save = app.buttons["保存图片"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            XCTAssertTrue(save.isEnabled)
            save.tap()
            if name == "伙伴击掌" {
                let prompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
                XCTAssertTrue(prompt.waitForExistence(timeout: 10))
                XCTAssertEqual(prompt.buttons.count, 2)
                let deniedLabels = ["Don't Allow", "不允许"]
                XCTAssertTrue(prompt.buttons.matching(NSPredicate(format: "label IN %@", deniedLabels)).firstMatch.exists)
                let allow = prompt.buttons.matching(NSPredicate(format: "NOT (label IN %@)", deniedLabels)).firstMatch
                capture("实际系统请求添加照片权限", in: app)
                allow.tap()
            }
            let saved = app.buttons["已保存"]
            XCTAssertTrue(saved.waitForExistence(timeout: 10))
            XCTAssertFalse(saved.isEnabled)
            XCTAssertEqual(app.buttons[name + "版式"].value as? String, "已选择")
            capture("已授权后保存当前版式：" + name, in: app)
        }
    }

    @MainActor private func openLongPoster(size: String = "large", resetPhotosAuthorization: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // 只准备此 App 的照片授权，令允许/拒绝用例不依赖执行顺序；不清理训练库或相册。
        if resetPhotosAuthorization { app.resetAuthorizationStatus(for: .photos) }
        app.launchArguments = ["-dev-auto-login", "-uitest-live-workout", "-uitest-finish-flow",
                               "-uitest-long-poster", "-uitest-history-loading", "-dismiss-career-review",
                               "-uitest-typography-size", size]
        app.launch()
        let history = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI 长训练海报")).firstMatch
        XCTAssertTrue(waitForIsolatedUITestScene(history, in: app))
        reveal(history, in: app)
        history.tap()
        let more = app.buttons["训练更多操作"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["分享训练海报"].tap()
        XCTAssertTrue(app.buttons["保存图片"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if target.isHittable && target.frame.minY >= 70 && target.frame.maxY < app.tabBars.firstMatch.frame.minY { return }
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable)
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
