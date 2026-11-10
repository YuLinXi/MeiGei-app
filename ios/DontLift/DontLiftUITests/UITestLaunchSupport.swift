import XCTest
import UIKit

/// iPhone 的底部按钮与 iPad 的顶部 tab 使用不同原生角色，保留同一标签的真实导航动作。
@MainActor
func mainTab(_ label: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(
        format: "label == %@ AND (elementType == %d OR elementType == %d)", label,
        Int(XCUIElement.ElementType.button.rawValue), Int(XCUIElement.ElementType.tab.rawValue)
    )).firstMatch
}

/// 沿用既有套件的单次 App 首启恢复，仅处理未进入隔离场景且仍显示登录页的情况。
@MainActor
func waitForIsolatedUITestScene(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    defer {
        if ProcessInfo.processInfo.environment["DONTLIFT_EXPECT_IPAD_MINI_FULLSCREEN"] == "1" {
            let window = app.windows.firstMatch.frame
            print("[S5-complex-window] app=\(app.frame) window=\(window)")
            XCTAssertEqual(window.width, 744, accuracy: 1, "需在当前iPad mini全屏竖屏中验收")
            XCTAssertEqual(window.height, 1133, accuracy: 1, "窄窗口不能计作全屏证据")
        }
    }
    if let expected = ProcessInfo.processInfo.environment["DONTLIFT_EXPECT_REDUCE_MOTION"] {
        print("[S5-motion] systemReduceMotion=\(UIAccessibility.isReduceMotionEnabled)")
        XCTAssertEqual(UIAccessibility.isReduceMotionEnabled, expected == "1", "需在实际系统开关状态下验证")
    }
    if element.waitForExistence(timeout: 15) { return true }
    guard app.buttons["Sign in with Apple"].exists else { return false }
    XCTContext.runActivity(named: "首启仍在登录页，保留证据后单次恢复隔离场景") { activity in
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.lifetime = .keepAlways
        activity.add(attachment)
    }
    app.terminate()
    app.launch()
    return element.waitForExistence(timeout: 15)
}

/// 在真实正文范围内短距离双向滚动；数值字段需完整可见，大卡片入口可明确允许可视部分。
@MainActor @discardableResult
func revealUITestElement(_ element: XCUIElement, in app: XCUIApplication,
                     allowPartial: Bool = false, scrollDownWhenMissing: Bool = false) -> CGRect {
    var enclosingScrollView: XCUIElement?
    for _ in 0..<30 {
        let appFrame = app.frame
        let exists = element.exists
        let frame = exists ? element.frame : .zero
        let targetType = exists ? element.elementType : .any
        let targetIdentifier = exists ? element.identifier : ""
        let targetLabel = exists ? element.label : ""
        if exists && enclosingScrollView == nil {
            let key = targetIdentifier.isEmpty ? targetLabel : targetIdentifier
            if !key.isEmpty {
                let views = app.scrollViews.containing(targetType, identifier: key)
                    .allElementsBoundByIndex.map { ($0, $0.frame.intersection(appFrame)) }
                    .filter { !$0.1.isNull && !$0.1.isEmpty }
                if let enclosing = views.min(by: { $0.1.width * $0.1.height < $1.1.width * $1.1.height }) {
                    enclosingScrollView = enclosing.0
                }
            }
        }
        let viewport = enclosingScrollView?.frame.intersection(appFrame) ?? appFrame
        let minimize = app.buttons["收起训练"].firstMatch
        let logging = minimize.exists && minimize.isHittable
        let cancel = app.buttons["取消"].firstMatch
        let formSheet = cancel.exists && cancel.isHittable
        let expandedRest = app.buttons["最小化休息计时"].exists
        let tab = app.tabBars.firstMatch
        let coveredNavigation = logging || formSheet || expandedRest
        let visibleTab = !coveredNavigation && tab.exists && tab.isHittable
        let tabFrame = visibleTab ? tab.frame : .zero
        let bottomTab = visibleTab && tabFrame.midY > appFrame.midY
        let contentBottom = bottomTab ? tabFrame.minY - 8 : appFrame.maxY - 20
        var bottom = contentBottom
        let pageFooters = formSheet || expandedRest ? [] : logging
            ? ["添加动作"] : ["复制", "开始这次训练", "开始训练", "添加计划或分组"]
        for name in pageFooters + ["收起键盘"] {
            if exists && targetType == .button
                && (targetLabel == name || targetIdentifier == name) { continue }
            let footer = app.buttons[name].firstMatch
            guard footer.exists else { continue }
            let footerFrame = footer.frame
            let scrollingFooter = enclosingScrollView?.buttons[name].firstMatch
            if let scrollingFooter, scrollingFooter.exists, scrollingFooter.frame == footerFrame { continue }
            if footer.isHittable && footerFrame.midY > appFrame.midY
                && (!exists || (frame.maxX > footerFrame.minX && frame.minX < footerFrame.maxX)) {
                bottom = min(bottom, footerFrame.minY - 8)
            }
        }
        let nav = app.navigationBars.firstMatch
        let navBottom = nav.exists && nav.isHittable ? nav.frame.maxY + 4 : appFrame.minY + 24
        let floatingTab = mainTab("计划", in: app)
        let floatingFrame = !coveredNavigation && floatingTab.exists && floatingTab.isHittable ? floatingTab.frame : .zero
        let floatingBottom = floatingFrame != .zero && floatingFrame.midY < appFrame.midY
            ? floatingFrame.maxY + 4 : navBottom
        var top = max(floatingBottom, visibleTab && !bottomTab ? tabFrame.maxY + 4 : navBottom)
        for name in ["返回", "收起训练", "取消", "完成", "完成排序"] {
            if exists && targetType == .button
                && (targetLabel == name || targetIdentifier == name) { continue }
            let header = app.buttons[name].firstMatch
            guard header.exists else { continue }
            let headerFrame = header.frame
            let scrollingHeader = enclosingScrollView?.buttons[name].firstMatch
            if let scrollingHeader, scrollingHeader.exists, scrollingHeader.frame == headerFrame { continue }
            if header.isHittable && headerFrame.midY < appFrame.midY
                && (!exists || (frame.maxX > headerFrame.minX && frame.minX < headerFrame.maxX)) {
                top = max(top, headerFrame.maxY + 8)
            }
        }
        let keyboard = app.keyboards.firstMatch
        let keyboardFrame = keyboard.exists ? keyboard.frame : .zero
        if keyboardFrame.height > 0 { bottom = min(bottom, keyboardFrame.minY - 8) }
        if enclosingScrollView != nil {
            top = max(top, viewport.minY)
            bottom = min(bottom, viewport.maxY)
        }
        let visibleHeight = min(bottom, frame.maxY) - max(top, frame.minY)
        let visible = allowPartial ? visibleHeight >= min(44, frame.height) : frame.minY >= top && frame.maxY <= bottom
        if exists && element.isHittable && visible {
            return frame.intersection(CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, bottom - top)))
        }
        let upwards = exists ? frame.maxY > bottom : !scrollDownWhenMissing
        // 横屏右边缘可能落在不接收滚动的安全区；在实际内容中间拖动。
        let limit = max(24, (bottom - top) / 2 - 12)
        let gap = exists ? (upwards ? frame.maxY - bottom : top - frame.minY) : limit
        let distance = min(limit, max(24, gap + 12))
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let y = (top + bottom) / 2
        let start = origin.withOffset(CGVector(dx: viewport.midX - appFrame.minX, dy: y - appFrame.minY))
        let end = origin.withOffset(CGVector(dx: viewport.midX - appFrame.minX,
                                           dy: y - appFrame.minY + (upwards ? -distance : distance)))
        start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }
    XCTContext.runActivity(named: "控件无法进入可视区域") { activity in
        let description = XCTAttachment(string: app.debugDescription)
        description.name = "窗口布局失败时的辅助功能树"
        description.lifetime = .keepAlways
        activity.add(description)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "窗口布局失败时的实际画面"
        screenshot.lifetime = .keepAlways
        activity.add(screenshot)
    }
    print("[S5-layout-failure] target=\(element.exists ? String(describing: element.frame) : "未加载") app=\(app.frame)")
    XCTFail("控件未完整进入当前窗口：\(element)")
    return .zero
}
