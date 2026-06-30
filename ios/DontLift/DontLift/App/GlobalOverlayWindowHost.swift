import SwiftUI

/// 承载 App 级提示的透明顶层窗口，确保 sheet/fullScreenCover 打开时仍显示在最上层。
struct GlobalOverlayWindowHost: UIViewRepresentable {
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(SyncProgressCenter.self) private var syncProgress
    @Environment(GlobalMessageCenter.self) private var globalMessage

    func makeUIView(context: Context) -> GlobalOverlayAnchorView {
        let view = GlobalOverlayAnchorView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.onWindowSceneChange = { [weak coordinator = context.coordinator] anchor in
            coordinator?.attachIfPossible(from: anchor)
        }
        return view
    }

    func updateUIView(_ uiView: GlobalOverlayAnchorView, context: Context) {
        context.coordinator.updateDependencies(syncEngine: syncEngine,
                                               syncProgress: syncProgress,
                                               globalMessage: globalMessage)
        context.coordinator.attachIfPossible(from: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ uiView: GlobalOverlayAnchorView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class GlobalOverlayAnchorView: UIView {
        var onWindowSceneChange: ((UIView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowSceneChange?(self)
        }
    }

    final class Coordinator {
        private weak var scene: UIWindowScene?
        private var window: UIWindow?
        private var syncEngine: SyncEngine?
        private var syncProgress: SyncProgressCenter?
        private var globalMessage: GlobalMessageCenter?

        @MainActor
        func updateDependencies(syncEngine: SyncEngine,
                                syncProgress: SyncProgressCenter,
                                globalMessage: GlobalMessageCenter) {
            self.syncEngine = syncEngine
            self.syncProgress = syncProgress
            self.globalMessage = globalMessage
        }

        @MainActor
        func attachIfPossible(from anchor: UIView) {
            guard let windowScene = anchor.window?.windowScene,
                  let syncEngine,
                  let syncProgress,
                  let globalMessage
            else { return }
            guard window == nil || scene !== windowScene else { return }
            detach()

            let overlayWindow = UIWindow(windowScene: windowScene)
            overlayWindow.windowLevel = .alert + 1
            overlayWindow.backgroundColor = .clear
            overlayWindow.isUserInteractionEnabled = false

            let controller = UIHostingController(rootView: GlobalOverlayWindowContent()
                .environment(syncEngine)
                .environment(syncProgress)
                .environment(globalMessage))
            controller.view.backgroundColor = .clear
            controller.view.isUserInteractionEnabled = false
            overlayWindow.rootViewController = controller
            overlayWindow.isHidden = false

            scene = windowScene
            window = overlayWindow
        }

        @MainActor
        func detach() {
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil
            scene = nil
        }
    }
}

private struct GlobalOverlayWindowContent: View {
    var body: some View {
        ZStack {
            GlobalSyncProgressOverlay()
            GlobalMessageOverlay()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
