import SwiftUI
import WidgetKit

struct WorkoutSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WorkoutWidgetSnapshot.widgetKind,
                            provider: WorkoutSummaryProvider()) { entry in
            WorkoutSummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("训练摘要")
        .description("查看今日训练状态和本周训练节奏。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WorkoutSummaryEntry: TimelineEntry {
    let date: Date
    let snapshot: WorkoutWidgetSnapshot
}

struct WorkoutSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutSummaryEntry {
        WorkoutSummaryEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutSummaryEntry) -> Void) {
        completion(WorkoutSummaryEntry(date: .now, snapshot: WorkoutWidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutSummaryEntry>) -> Void) {
        let entry = WorkoutSummaryEntry(date: .now, snapshot: WorkoutWidgetSnapshotStore.read())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private struct WorkoutSummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WorkoutSummaryEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .containerBackground(WidgetStyle.bg, for: .widget)
        .widgetURL(entry.snapshot.destinationURL)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            Text(primaryTitle)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(WidgetStyle.fg)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(primaryMessage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetStyle.fg2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatTons(entry.snapshot.weekStats.volumeKg))
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(WidgetStyle.accent)
                    .monospacedDigit()
                Text("t")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetStyle.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(primaryTitle)，\(primaryMessage)，本周训练量 \(formatTons(entry.snapshot.weekStats.volumeKg)) 吨")
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(primaryTitle)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(WidgetStyle.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(primaryMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetStyle.fg2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if let recent = entry.snapshot.recentWorkout {
                    Text("最近 · \(recent.title) · \(recent.setCount) 组")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetStyle.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                } else {
                    Text("打开 App 开始第 1 次训练")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetStyle.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 10) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTons(entry.snapshot.weekStats.volumeKg))
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(WidgetStyle.accent)
                        .monospacedDigit()
                    Text("本周训练量 t")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WidgetStyle.fg2)
                }
                HStack(spacing: 8) {
                    metric("\(entry.snapshot.weekStats.sessionCount)", "次")
                    metric("\(entry.snapshot.weekStats.setCount)", "组")
                    metric("\(entry.snapshot.weekStats.repCount)", "次")
                }
                weekStrip
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(primaryTitle)，本周 \(entry.snapshot.weekStats.sessionCount) 次训练，\(entry.snapshot.weekStats.setCount) 组")
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image("AppIcon", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("别练了")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(WidgetStyle.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(displayDays) { day in
                VStack(spacing: 3) {
                    Text(day.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(day.isToday ? WidgetStyle.accent : WidgetStyle.muted)
                    Circle()
                        .fill(day.isCompleted ? WidgetStyle.accent : WidgetStyle.border)
                        .frame(width: day.isToday ? 8 : 6, height: day.isToday ? 8 : 6)
                }
                .frame(width: 14)
            }
        }
    }

    private var displayDays: [WorkoutWidgetSnapshot.Day] {
        if !entry.snapshot.weekDays.isEmpty { return entry.snapshot.weekDays }
        return ["一", "二", "三", "四", "五", "六", "日"].enumerated().map { index, label in
            WorkoutWidgetSnapshot.Day(
                date: Date(timeIntervalSinceReferenceDate: Double(index)),
                label: label,
                sessionCount: 0,
                isToday: index == 0
            )
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(WidgetStyle.fg)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(WidgetStyle.muted)
        }
    }

    private var primaryTitle: String {
        if entry.snapshot.activeWorkout != nil { return "训练进行中" }
        if entry.snapshot.todayCompletedWorkoutCount > 0 { return "今天已练" }
        if entry.snapshot.currentTrainingStreakDays >= 3 {
            return "已坚持 \(entry.snapshot.currentTrainingStreakDays) 天"
        }
        return "今天还没练"
    }

    private var primaryMessage: String {
        if let active = entry.snapshot.activeWorkout {
            return active.title
        }
        if entry.snapshot.todayCompletedWorkoutCount > 0 {
            return "本周第 \(entry.snapshot.weekStats.sessionCount) 次 · 保持节奏"
        }
        if entry.snapshot.weekStats.sessionCount > 0 {
            return "本周已练 \(entry.snapshot.weekStats.sessionCount) 次"
        }
        return "打开 App 开始第 1 次训练"
    }

    private func formatTons(_ kg: Double) -> String {
        guard kg > 0 else { return "0.0" }
        return String(format: "%.1f", kg / 1000)
    }
}

private enum WidgetStyle {
    static let bg = Color(red: 0.957, green: 0.949, blue: 0.925)
    static let surface = Color.white
    static let border = Color(red: 0.894, green: 0.867, blue: 0.816)
    static let fg = Color(red: 0.110, green: 0.102, blue: 0.090)
    static let fg2 = Color(red: 0.369, green: 0.349, blue: 0.314)
    static let muted = Color(red: 0.604, green: 0.580, blue: 0.525)
    static let accent = Color(red: 0.851, green: 0.282, blue: 0.169)
}

private extension WorkoutWidgetSnapshot {
    static let sample = WorkoutWidgetSnapshot(
        generatedAt: .now,
        todayCompletedWorkoutCount: 1,
        currentTrainingStreakDays: 4,
        weekStats: .init(volumeKg: 28_400, sessionCount: 4, setCount: 62, repCount: 480),
        weekDays: ["一", "二", "三", "四", "五", "六", "日"].enumerated().map { index, label in
            .init(
                date: Date(timeIntervalSinceReferenceDate: Double(index)),
                label: label,
                sessionCount: [0, 1, 0, 1, 1, 1, 0][index],
                isToday: index == 5
            )
        },
        recentWorkout: .init(title: "推日 A", startedAt: .now, setCount: 16, volumeKg: 8_200),
        activeWorkout: nil
    )
}

#Preview(as: .systemSmall) {
    WorkoutSummaryWidget()
} timeline: {
    WorkoutSummaryEntry(date: .now, snapshot: .sample)
}

#Preview(as: .systemMedium) {
    WorkoutSummaryWidget()
} timeline: {
    WorkoutSummaryEntry(date: .now, snapshot: .sample)
}
