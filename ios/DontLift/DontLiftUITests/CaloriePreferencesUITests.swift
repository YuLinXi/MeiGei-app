import XCTest

final class CaloriePreferencesUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testInitialOptionalAndCancelAtDefaultSize() throws { checkInitial(size: "large") }
    @MainActor func testInitialOptionalAndCancelAtLargestSize() throws { checkInitial(size: "accessibility5") }

    @MainActor func testExplicitEnableSavesValidWeightAndOffKeepsWeight() throws {
        let app = launch()
        let toggle = app.switches["profile.calorieEstimate"]
        reveal(toggle, in: app)
        tapToggle(toggle)
        let field = weightField(in: app)
        replaceWeight(field, with: "70")
        app.buttons["完成"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertTrue(app.buttons["估算体重"].valueDescription.contains("70"))
        tapToggle(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.buttons["估算体重"].valueDescription.contains("70"))
        capture("显式开启后保存有效体重，关闭仍保留体重", in: app)
    }

    @MainActor func testMissingWeightRowSaveKeepsVisibleOffChoice() throws {
        let app = launch()
        let toggle = app.switches["profile.calorieEstimate"]
        let row = app.buttons["估算体重"]
        reveal(row, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        row.tap()
        let field = weightField(in: app)
        replaceWeight(field, with: "70")
        app.buttons["完成"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(row.valueDescription.contains("70"))
        capture("缺少体重时从体重行保存仍保持关闭", in: app)
    }

    @MainActor func testEditingWeightPreservesEnabledChoice() throws { checkEdit(enabled: true) }
    @MainActor func testEditingWeightPreservesDisabledChoice() throws { checkEdit(enabled: false) }

    @MainActor func testInvalidInputsAndCancelPreserveStoredConfiguration() throws {
        let app = launch(flags: ["-uitest-calorie-known-on"])
        let row = app.buttons["估算体重"]
        reveal(row, in: app)
        row.tap()
        let field = weightField(in: app)
        for value in ["", "..", "29", "251"] {
            replaceWeight(field, with: value)
            XCTAssertFalse(app.buttons["完成"].isEnabled)
            XCTAssertTrue(app.staticTexts["profile.calorieWeight.helper"].exists)
        }
        capture("无效体重不可提交，取消保留原配置", in: app)
        app.buttons["取消"].tap()
        XCTAssertEqual(app.switches["profile.calorieEstimate"].value as? String, "1")
        XCTAssertTrue(row.valueDescription.contains("70"))
    }

    @MainActor private func checkInitial(size: String) {
        let app = launch(size: size)
        let toggle = app.switches["profile.calorieEstimate"]
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        let row = app.buttons["估算体重"]
        reveal(row, in: app)
        XCTAssertTrue(row.valueDescription.contains("未设置"))
        XCTAssertFalse(row.valueDescription.contains("必填"))
        capture("估算为可选且尚未设置：\(size)", in: app)
        reveal(toggle, in: app)
        tapToggle(toggle)
        let field = weightField(in: app)
        XCTAssertFalse(app.buttons["完成"].isEnabled)
        capture("开启配置可取消且不会立即改变选择：\(size)", in: app)
        app.buttons["取消"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(row.valueDescription.contains("未设置"))
    }

    @MainActor private func checkEdit(enabled: Bool) {
        let app = launch(flags: [enabled ? "-uitest-calorie-known-on" : "-uitest-calorie-known-off"])
        let toggle = app.switches["profile.calorieEstimate"]
        let row = app.buttons["估算体重"]
        reveal(row, in: app)
        XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
        row.tap()
        let field = weightField(in: app)
        replaceWeight(field, with: "75")
        app.buttons["完成"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
        XCTAssertTrue(row.valueDescription.contains("75"))
        capture("单独编辑体重保留原可见选择：\(enabled)", in: app)
    }

    @MainActor private func launch(size: String = "large", flags: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-dev-auto-login", "-clear-active-workout", "-uitest-calorie-preferences",
                               "-dismiss-career-review", "-uitest-typography-size", size] + flags
        app.launch()
        let profile = app.tabBars.buttons["我的"]
        XCTAssertTrue(waitForIsolatedUITestScene(profile, in: app))
        profile.tap()
        return app
    }

    @MainActor private func weightField(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["profile.calorieWeight.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        return field
    }

    @MainActor private func replaceWeight(_ field: XCUIElement, with value: String) {
        let previous = field.value as? String ?? ""
        let count = previous == "30–250" ? 0 : previous.count
        if count > 0 { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count)) }
        if !value.isEmpty { field.typeText(value) }
    }

    @MainActor private func tapToggle(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 {
            let bottom = app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY - 8 : app.frame.maxY - 34
            if element.exists && element.isHittable && element.frame.minY >= 120 && element.frame.maxY <= bottom { return }
            let down = element.exists && element.frame.minY < 120
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 280 : 550))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.maxX - 9, dy: down ? 450 : 380))
            from.press(forDuration: 0.01, thenDragTo: to)
        }
        XCTFail("估算偏好控件未滚入可用区域")
    }

    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    var valueDescription: String { value as? String ?? "" }
}
