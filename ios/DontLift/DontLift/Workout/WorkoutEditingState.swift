import SwiftUI

/// 输入中间态由消费它的动作列表观察；不会让计时标题与浮层随每个字符重绘。
@MainActor
@Observable
final class WorkoutEditingState {
    var buffer = ""
    var pendingReplace = false
}

/// 在独立 body 中建立 Observation 依赖，避免父页面订阅子区块的模型属性。
struct WorkoutObservationScope<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View { content() }
}
