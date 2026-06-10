import ActivityKit
import SwiftUI
import WidgetKit

/// 组间休息 Live Activity：锁屏卡片 + 灵动岛 + 配对 Watch Smart Stack（系统自动转呈）。
/// 倒计时用 `Text(timerInterval:countsDown:)` 自走，无需推送更新即可在锁屏/后台持续刷新。
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenRestView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("休息", systemImage: "timer")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.endDate)
                        .font(.title2.bold().monospacedDigit())
                        .frame(maxWidth: 70)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let next = context.state.nextExercise {
                            Text("下一个：\(next)").font(.caption).lineLimit(1)
                        }
                        Spacer()
                        Button(intent: EndRestIntent()) {
                            Label("结束", systemImage: "forward.end.fill")
                        }
                        .tint(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                countdown(to: context.state.endDate).monospacedDigit().frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func countdown(to end: Date) -> Text {
        Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
    }
}

private struct LockScreenRestView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Label("组间休息", systemImage: "timer")
                    .font(.caption).foregroundStyle(.secondary)
                Text(timerInterval: Date.now...max(Date.now, context.state.endDate), countsDown: true)
                    .font(.largeTitle.bold().monospacedDigit())
                if let next = context.state.nextExercise {
                    Text("下一个：\(next)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Button(intent: EndRestIntent()) {
                Label("结束", systemImage: "forward.end.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}
