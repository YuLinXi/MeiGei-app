import SwiftUI

@MainActor
@Observable
final class SyncProgressCenter {
    private(set) var isVisible = false
    private var shownAt: Date?
    private var hideTask: Task<Void, Never>?
    private let minimumVisibleDuration: TimeInterval = 1.2

    func update(isSyncing: Bool) {
        hideTask?.cancel()
        hideTask = nil
        if isSyncing {
            if !isVisible {
                shownAt = .now
                isVisible = true
            }
            return
        }
        guard isVisible else { return }
        let elapsed = Date().timeIntervalSince(shownAt ?? .now)
        let remaining = max(0, minimumVisibleDuration - elapsed)
        hideTask = Task { [weak self] in
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isVisible = false
                self?.shownAt = nil
                self?.hideTask = nil
            }
        }
    }

    func hideImmediately() {
        hideTask?.cancel()
        hideTask = nil
        isVisible = false
        shownAt = nil
    }
}

/// 自动同步期间的全局轻量提示。只展示状态，不拦截任何用户操作。
struct GlobalSyncProgressOverlay: View {
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(SyncProgressCenter.self) private var center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                if center.isVisible {
                    syncPill
                        .padding(.top, 8)
                        .transition(transition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.2), value: center.isVisible)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { center.update(isSyncing: syncEngine.isSyncing) }
        .onDisappear { center.hideImmediately() }
        .onChange(of: syncEngine.isSyncing) { _, isSyncing in
            center.update(isSyncing: isSyncing)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("同步中")
                .font(Theme.Font.body(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Theme.Color.fg.opacity(0.92), in: Capsule())
        .paperShadow(.sm, cornerRadius: 18)
    }

    private var transition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .top).combined(with: .opacity)
    }
}
