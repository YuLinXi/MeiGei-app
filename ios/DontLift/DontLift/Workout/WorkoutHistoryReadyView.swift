import SwiftUI

/// 仅等待依赖预填的局部流程；当前训练列表继续可操作。
struct WorkoutHistoryReadyView<Content: View>: View {
    @Environment(WorkoutHistoryStore.self) private var history
    @State private var ready = false
    @State private var failed = false
    var requiresCurrent = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if ready || (!requiresCurrent && history.hasSnapshot) {
                content()
            } else if failed {
                ContentUnavailableView {
                    Label("历史记录暂未就绪", systemImage: "arrow.clockwise")
                } description: {
                    Text("重试后继续，已有训练输入已保留。")
                } actions: {
                    Button("重试") { Task { await load() } }
                }
            } else {
                ProgressView("正在准备历史记录…")
            }
        }
        .task { await load() }
    }

    private func load() async {
        failed = false
        ready = await history.waitUntilLoaded()
        failed = !ready
    }
}
