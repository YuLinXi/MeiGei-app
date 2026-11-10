import UIKit
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct SwipeBackGestureTests {
    @Test func rootPageDoesNotBeginEdgePop() async throws {
        let (navigation, gesture) = try await makeStack(depth: 1)
        #expect(navigation.viewControllers.count == 1)
        #expect(!SwipeBackGestureDelegate.shared.gestureRecognizerShouldBegin(gesture))
    }

    @Test func pushedPageBeginsEdgePop() async throws {
        let (navigation, gesture) = try await makeStack(depth: 2)
        #expect(navigation.viewControllers.count == 2)
        #expect(SwipeBackGestureDelegate.shared.gestureRecognizerShouldBegin(gesture))
    }

    @Test func modalRootDoesNotReplacePushedPagesNavigationStack() async throws {
        let (outerNavigation, outerGesture) = try await makeStack(depth: 2)
        #expect(SwipeBackGestureDelegate.shared.gestureRecognizerShouldBegin(outerGesture))

        let (modalNavigation, modalGesture) = try await makeStack(depth: 1)
        #expect(outerNavigation.viewControllers.count == 2)
        #expect(modalNavigation.viewControllers.count == 1)
        #expect(!SwipeBackGestureDelegate.shared.gestureRecognizerShouldBegin(modalGesture))
        #expect(SwipeBackGestureDelegate.shared.gestureRecognizerShouldBegin(outerGesture))
    }

    @Test func removingHeaderReleasesProbeAndStopsNavigationItemChanges() async throws {
        let (navigation, _) = try await makeStack(depth: 2)
        let page = try #require(navigation.topViewController)
        let item = page.navigationItem
        weak var probe: SwipeBackProbeController? = page.children.compactMap {
            $0 as? SwipeBackProbeController
        }.first
        try #require(probe != nil)
        probe?.willMove(toParent: nil)
        probe?.view.removeFromSuperview()
        probe?.removeFromParent()
        #expect(probe == nil)
        item.leftItemsSupplementBackButton = true
        #expect(item.leftItemsSupplementBackButton, "Header 移除后不再改写导航项")
    }

    private func makeStack(depth: Int) async throws -> (UINavigationController, UIGestureRecognizer) {
        let navigation = UINavigationController()
        navigation.setViewControllers((0..<depth).map { _ in UIViewController() }, animated: false)
        navigation.loadViewIfNeeded()
        let page = try #require(navigation.topViewController)
        page.loadViewIfNeeded()
        let probe = SwipeBackProbeController()
        page.addChild(probe)
        page.view.addSubview(probe.view)
        probe.didMove(toParent: page)
        // 等待生产探针安装手势代理，保留与 sheet 内导航栈相同的挂载顺序。
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        let gesture = try #require(navigation.interactivePopGestureRecognizer)
        _ = try #require(gesture.view)
        #expect(gesture.delegate === SwipeBackGestureDelegate.shared)
        return (navigation, gesture)
    }
}
