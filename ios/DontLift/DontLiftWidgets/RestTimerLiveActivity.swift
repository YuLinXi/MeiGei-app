import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

/// 训练会话 Live Activity：iPhone 锁屏卡片 + 灵动岛。
/// `workout` phase 显示训练正向计时，`rest` phase 显示组间休息倒计时。
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenWorkoutActivityView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandBrandHeader(phase: context.state.phase)
                        .padding(.leading, 18)
                        .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    phaseTimer(context: context)
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 82, alignment: .trailing)
                        .padding(.trailing, 16)
                        .padding(.top, 6)
                        .accessibilityLabel(context.state.phase == .rest ? "休息倒计时" : "训练计时")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.phase == .rest {
                        ExpandedRestDetail(state: context.state)
                    } else {
                        ExpandedWorkoutDetail(context: context)
                    }
                }
            } compactLeading: {
                IslandAppIcon(size: 18, cornerRadius: 5)
                    .accessibilityLabel(context.state.phase == .rest ? "组间休息" : "训练进行中")
            } compactTrailing: {
                CompactPhaseTimer(phase: context.state.phase, timer: phaseTimer(context: context))
                    .accessibilityLabel(context.state.phase == .rest ? "休息倒计时" : "训练计时")
            } minimal: {
                IslandAppPhaseIcon(phase: context.state.phase, size: 18)
                    .accessibilityLabel(context.state.phase == .rest ? "组间休息" : "训练进行中")
            }
            .keylineTint(brandAccent)
        }
    }

    private var brandAccent: Color {
        Color(red: 0.89, green: 0.25, blue: 0.16)
    }

    private func phaseTimer(context: ActivityViewContext<RestActivityAttributes>) -> Text {
        if context.state.phase == .rest, let end = context.state.restEndDate {
            return Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
        }
        return Text(context.attributes.startedAt, style: .timer)
    }
}

private let brandAccent = Color(red: 0.89, green: 0.25, blue: 0.16)

private struct CompactPhaseTimer: View {
    let phase: RestActivityAttributes.Phase
    let timer: Text

    var body: some View {
        HStack(spacing: 2) {
            IslandPhaseIcon(phase: phase, size: 11)
            timer
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: 64, alignment: .trailing)
        .accessibilityElement(children: .combine)
    }
}

private struct IslandPhaseIcon: View {
    let phase: RestActivityAttributes.Phase
    let size: CGFloat

    var body: some View {
        Image(systemName: phase == .rest ? "timer" : "record.circle.fill")
            .font(.system(size: size * 0.78, weight: .black))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(brandAccent)
            .frame(width: size, height: size)
    }
}

private struct IslandAppPhaseIcon: View {
    let phase: RestActivityAttributes.Phase
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            IslandAppIcon(size: size, cornerRadius: 5)
            IslandPhaseIcon(phase: phase, size: size * 0.52)
                .background(.black, in: Circle())
                .offset(x: 2, y: 2)
        }
        .frame(width: size, height: size)
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
    let phase: RestActivityAttributes.Phase

    var body: some View {
        HStack(spacing: 7) {
            IslandAppIcon(size: 22, cornerRadius: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(phase == .rest ? "REST" : "REC")
                    .font(.caption2.weight(.black).monospaced())
                    .foregroundStyle(brandAccent)
                Text("别练了")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(phase == .rest ? "组间休息，别练了" : "训练进行中，别练了")
    }
}

private struct ExpandedWorkoutDetail: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.workoutTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("训练进行中")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    stat("\(context.state.completedSetCount)", label: "已完成组")
                    stat("\(context.state.remainingExerciseCount)", label: "剩余动作")
                }
                if let next = context.state.nextSet {
                    Text("下一组 · \(next.exerciseName) 第\(next.setIndex)组")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("训练进行中，已完成 \(context.state.completedSetCount) 组，剩余 \(context.state.remainingExerciseCount) 个动作")
    }

    private func stat(_ value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.title3.weight(.black).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.62))
        }
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
                            .foregroundStyle(brandAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            Spacer(minLength: 0)
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
        state.nextSet?.exerciseName ?? "开始下一组"
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

private struct LockScreenWorkoutActivityView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    IslandAppIcon(size: 22, cornerRadius: 6)
                    Text(context.state.phase == .rest ? "组间休息" : "训练进行中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    IslandPhaseIcon(phase: context.state.phase, size: 12)
                }
                .accessibilityElement(children: .combine)
                phaseTimer
                    .font(.largeTitle.bold().monospacedDigit())
                if context.state.phase == .rest {
                    restSubtitle
                } else {
                    workoutSubtitle
                }
            }
            Spacer()
        }
    }

    private var phaseTimer: Text {
        if context.state.phase == .rest, let end = context.state.restEndDate {
            return Text(timerInterval: Date.now...max(Date.now, end), countsDown: true)
        }
        return Text(context.attributes.startedAt, style: .timer)
    }

    @ViewBuilder private var workoutSubtitle: some View {
        if let next = context.state.nextSet {
            Text("已完成 \(context.state.completedSetCount) 组 · 剩余 \(context.state.remainingExerciseCount) 动作 · 下一组：\(next.exerciseName) 第\(next.setIndex)组")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("已完成 \(context.state.completedSetCount) 组 · 剩余 \(context.state.remainingExerciseCount) 动作")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var restSubtitle: some View {
        if let next = context.state.nextSet {
            Text("下一组：\(next.exerciseName) · \(next.setLabel) · \(next.weightText ?? "未填重量") · \(next.repsText ?? "未填次数")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("开始下一组")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
