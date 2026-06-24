import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

/// 组间休息 Live Activity：iPhone 锁屏卡片 + 灵动岛。
/// Apple Watch Smart Stack 是平台条件能力：仅在系统版本、连接状态与 ActivityKit/WidgetKit 预算支持时自动转呈。
/// 当前不引入 Watch 专用 `supplementalActivityFamilies` 小尺寸布局，Watch 缺席不得判定为休息提醒失败。
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
                    IslandBrandHeader()
                        .padding(.leading, 18)
                        .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.endDate)
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 82, alignment: .trailing)
                        .padding(.trailing, 16)
                        .padding(.top, 6)
                        .accessibilityLabel("休息倒计时")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedRestDetail(state: context.state)
                }
            } compactLeading: {
                IslandAppIcon(size: 18, cornerRadius: 5)
                    .accessibilityLabel("组间休息")
            } compactTrailing: {
                countdown(to: context.state.endDate)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 46)
                    .accessibilityLabel("休息倒计时")
            } minimal: {
                IslandAppIcon(size: 18, cornerRadius: 5)
                    .accessibilityLabel("组间休息")
            }
            .keylineTint(.orange)
        }
    }

    private func countdown(to end: Date) -> Text {
        Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
    }
}

private struct IslandAppIcon: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image("DontLiftIslandIcon", bundle: .main)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct IslandBrandHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            IslandAppIcon(size: 22, cornerRadius: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text("REST")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(.orange)
                Text("别练了")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("组间休息，别练了")
    }
}

private struct ExpandedRestDetail: View {
    let state: RestActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(nextSetCaption)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
                Text(nextExerciseTitle)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let loadSummary {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(loadSummary.weight)
                            .font(.title3.weight(.black).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("× \(loadSummary.reps)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            Spacer(minLength: 8)
            Button(intent: EndRestIntent()) {
                Text("结束")
                    .font(.caption2.weight(.black))
                    .frame(minWidth: 44, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .foregroundStyle(.black)
            .accessibilityLabel("结束休息")
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .padding(.bottom, 4)
    }

    private var nextSetCaption: String {
        if let next = state.nextSet {
            return "下一组 · 第\(next.setIndex)组"
        }
        return "下一组"
    }

    private var nextExerciseTitle: String {
        if let next = state.nextSet {
            return next.exerciseName
        }
        if let nextExercise = state.nextExercise {
            return nextExercise
        }
        return "开始下一组"
    }

    private var loadSummary: (weight: String, reps: String)? {
        guard let next = state.nextSet,
              let weight = next.weightText?.trimmingCharacters(in: .whitespacesAndNewlines),
              let reps = next.repsText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !weight.isEmpty,
              !reps.isEmpty else {
            return nil
        }
        return (weight, reps)
    }

    private var accessibilitySummary: String {
        if let loadSummary {
            return "\(nextSetCaption)，\(nextExerciseTitle)，\(loadSummary.weight)，\(loadSummary.reps)"
        }
        return "\(nextSetCaption)，\(nextExerciseTitle)"
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
                if let next = context.state.nextSet {
                    Text("下一组：\(next.exerciseName) · \(next.setLabel) · \(next.weightText ?? "未填重量") · \(next.repsText ?? "未填次数")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let next = context.state.nextExercise {
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
