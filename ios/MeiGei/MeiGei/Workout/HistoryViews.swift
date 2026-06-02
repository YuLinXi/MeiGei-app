import SwiftUI
import SwiftData
import Charts

// MARK: - 3.9 训练历史

/// 按动作归并历史的稳定 key：内置 code 优先，其次自定义 id，最后回退动作名。
extension WorkoutExercise {
    var historyKey: String { builtinExerciseCode ?? customExerciseId?.uuidString ?? exerciseName }
}

// MARK: - 历史入口（Screen 10，Neon 改版）

struct TrainingHistoryView: View {
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]

    @State private var windowId: String = "30"
    @State private var showCalendar = false

    private let windowChips: [HistoryChip] = [
        HistoryChip(id: "7",   title: "7 天",   days: 7),
        HistoryChip(id: "30",  title: "30 天",  days: 30),
        HistoryChip(id: "90",  title: "90 天",  days: 90),
        HistoryChip(id: "all", title: "全部",   days: nil),
    ]

    private var selectedChip: HistoryChip {
        windowChips.first(where: { $0.id == windowId }) ?? windowChips[1]
    }

    private var windowStart: Date {
        guard let d = selectedChip.days else { return .distantPast }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(-Double(d - 1) * 86_400)
    }

    private var inWindow: [Workout] {
        workouts.filter { $0.startedAt >= windowStart }
    }

    /// 上一窗口（用于 MoM/WoW delta）。
    private var prevInWindow: [Workout] {
        guard let d = selectedChip.days else { return [] }
        let prevEnd = windowStart
        let prevStart = prevEnd.addingTimeInterval(-Double(d) * 86_400)
        return workouts.filter { $0.startedAt >= prevStart && $0.startedAt < prevEnd }
    }

    private var totalVolumeKg: Double { Self.volume(of: inWindow) }
    private var prevVolumeKg: Double { Self.volume(of: prevInWindow) }

    private static func volume(of list: [Workout]) -> Double {
        var sum = 0.0
        for w in list {
            for ex in w.exercises {
                for s in ex.sets {
                    sum += (s.weightKg ?? 0) * Double(s.reps ?? 0)
                }
            }
        }
        return sum
    }

    private var prList: [PRSummary] {
        let until = Date()
        return PRStats.newPRs(in: workouts, since: windowStart, until: until)
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    HorizontalChipPicker(items: windowChips, selection: $windowId) { $0.title }
                        .padding(.horizontal, -Theme.Spacing.lg)

                    volumeCard

                    if !prList.isEmpty {
                        Text(selectedChip.eyebrow + " PR").eyebrowStyle()
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(Array(prList.enumerated()), id: \.element.exerciseKey) { idx, pr in
                                prCard(pr: pr, isFirst: idx == 0)
                            }
                        }
                    }

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCalendar = true } label: {
                    Image(systemName: "calendar").foregroundStyle(Theme.Color.fg)
                }
            }
        }
        .navigationDestination(isPresented: $showCalendar) { WorkoutCalendarView() }
    }

    private var volumeCard: some View {
        let tons = totalVolumeKg / 1000
        let deltaPct: Double? = prevVolumeKg > 0
            ? (totalVolumeKg - prevVolumeKg) / prevVolumeKg * 100
            : nil
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .lastTextBaseline) {
                Text("\(selectedChip.eyebrow)总训练量").eyebrowStyle()
                Spacer()
                if let d = deltaPct {
                    let label = selectedChip.days == 7 ? "WoW" : "MoM"
                    let color = d >= 0 ? Theme.Color.ok : Theme.Color.danger
                    Text("\(label) \(d >= 0 ? "+" : "")\(String(format: "%.1f", d))%")
                        .font(Theme.Font.mono(size: 11, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", tons))
                    .numStyle(size: 36, weight: .bold)
                    .foregroundStyle(Theme.Color.fg)
                Text("吨")
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg2)
            }
            chart
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private struct VolumeBar: Identifiable {
        let id: Date
        let day: Date
        let volume: Double
    }

    private var volumeBars: [VolumeBar] {
        let cal = Calendar.current
        // 按日聚合：从 windowStart（或最早数据）到今天，每日一柱。
        let totalDays = selectedChip.days ?? 90
        let bars = totalDays > 60 ? 30 : (totalDays > 14 ? totalDays / 3 : totalDays)
        let unitDays = max(1, totalDays / max(1, bars))
        let today = cal.startOfDay(for: Date())
        var out: [VolumeBar] = []
        var d = today.addingTimeInterval(-Double(bars - 1) * Double(unitDays) * 86_400)
        for _ in 0..<bars {
            let end = d.addingTimeInterval(Double(unitDays) * 86_400)
            let slice = inWindow.filter { $0.startedAt >= d && $0.startedAt < end }
            let vol = Self.volume(of: slice)
            out.append(VolumeBar(id: d, day: d, volume: vol))
            d = end
        }
        return out
    }

    @ViewBuilder
    private var chart: some View {
        let bars = volumeBars
        let lastDay = bars.last?.day
        Chart(bars) { b in
            BarMark(
                x: .value("日期", b.day, unit: .day),
                y: .value("容量", b.volume)
            )
            .foregroundStyle(
                lastDay.map { Calendar.current.isDate(b.day, inSameDayAs: $0) } ?? false
                    ? Theme.Color.accentMagenta
                    : Theme.Color.accentCyan
            )
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 90)
    }

    private func prCard(pr: PRSummary, isFirst: Bool) -> some View {
        let deltaText: String? = pr.previousBestKg.flatMap { prev in
            let d = pr.weightKg - prev
            return d > 0 ? "+\(formatKg(d))kg" : nil
        }
        return HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                if isFirst {
                    Text("★ NEW PR")
                        .font(Theme.Font.mono(size: 10, weight: .semibold))
                        .tracking(0.08 * 10)
                        .foregroundStyle(Theme.Color.accentMagenta)
                }
                Text(displayName(for: pr.exerciseKey))
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(formatKg(pr.weightKg)).numStyle(size: 22, weight: .bold).foregroundStyle(Theme.Color.fg)
                    Text("kg × \(pr.reps)")
                        .font(Theme.Font.mono(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                }
            }
            Spacer()
            if let delta = deltaText {
                Text(delta)
                    .font(Theme.Font.mono(size: 12, weight: .semibold))
                    .foregroundStyle(isFirst ? Theme.Color.accentMagenta : Theme.Color.ok)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        (isFirst ? Theme.Color.accentMagenta : Theme.Color.ok).opacity(0.15),
                        in: Capsule()
                    )
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(isFirst ? Theme.Color.accentMagenta.opacity(0.55) : Theme.Color.border, lineWidth: 1)
        )
        .conditionalMagentaGlow(isFirst)
    }

    /// 把 historyKey 反查成可读名：内置 code → BuiltinExercise.starter；UUID → 简短回退；否则原样。
    private func displayName(for key: String) -> String {
        if let b = BuiltinExercise.starter.first(where: { $0.code == key }) { return b.name }
        if let last = workouts.flatMap(\.exercises).first(where: { $0.historyKey == key }) {
            return last.exerciseName
        }
        return key
    }
}

private struct HistoryChip: Identifiable, Hashable {
    let id: String
    let title: String
    /// nil = 全部
    let days: Int?
    var eyebrow: String {
        switch id {
        case "7":   return "本周"
        case "30":  return "本月"
        case "90":  return "本季"
        case "all": return "全部"
        default:    return ""
        }
    }
}

private extension View {
    @ViewBuilder
    func conditionalMagentaGlow(_ on: Bool) -> some View {
        if on {
            self.neonGlow(.magenta, intensity: .medium, cornerRadius: Theme.Radius.md)
        } else {
            self
        }
    }
}

// MARK: - 训练日历（保留：从历史首页 toolbar 进入）

/// 按月日历：有已完成训练的日期标点，点选某天列出当天训练。必要的 List 用法。
struct WorkoutCalendarView: View {
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @State private var month: Date = .now
    @State private var selected: Date = .now
    @State private var pendingDelete: Workout?

    private var cal: Calendar { Calendar.current }

    private var byDay: [Date: [Workout]] {
        Dictionary(grouping: workouts) { cal.startOfDay(for: $0.startedAt) }
    }

    private var selectedWorkouts: [Workout] {
        byDay[cal.startOfDay(for: selected)] ?? []
    }

    var body: some View {
        // 必要的 List 用法：日历 + 当日训练列表混排，sheet 自绘成本高，保留 List 配深色背景。
        List {
            Section {
                CalendarGrid(month: month, selected: $selected,
                             markedDays: Set(byDay.keys),
                             onPrev: { shift(-1) }, onNext: { shift(1) })
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section(selected.formatted(.dateTime.year().month().day())) {
                if selectedWorkouts.isEmpty {
                    Text("这天没有训练").foregroundStyle(Theme.Color.muted)
                } else {
                    ForEach(selectedWorkouts) { w in
                        NavigationLink(value: w) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.title ?? "训练")
                                    .font(.headline)
                                    .foregroundStyle(Theme.Color.fg)
                                Text(daySummary(w))
                                    .font(.caption)
                                    .foregroundStyle(Theme.Color.muted)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { pendingDelete = w } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .navigationTitle("日历")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Workout.self) { WorkoutLoggingView(workout: $0) }
        .confirmationDialog("删除这次训练？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { w in
            Button("删除", role: .destructive) {
                w.markDeleted()
                try? modelContext.save()
            }
            Button("取消", role: .cancel) {}
        } message: { _ in Text("删除后将从列表移除、不再计入统计，且同步到云端。") }
    }

    private func shift(_ months: Int) {
        if let m = cal.date(byAdding: .month, value: months, to: month) { month = m }
    }

    private func daySummary(_ w: Workout) -> String {
        let sets = w.exercises.reduce(0) { $0 + $1.sets.count }
        return "\(w.startedAt.formatted(date: .omitted, time: .shortened)) · \(w.exercises.count)动作/\(sets)组"
    }
}

private struct CalendarGrid: View {
    let month: Date
    @Binding var selected: Date
    let markedDays: Set<Date>
    let onPrev: () -> Void
    let onNext: () -> Void

    private var cal: Calendar { Calendar.current }
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onPrev) {
                    Image(systemName: "chevron.left").foregroundStyle(Theme.Color.fg)
                }
                Spacer()
                Text(month.formatted(.dateTime.year().month()))
                    .font(.headline)
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Color.fg)
                }
            }
            .padding(.horizontal)
            HStack {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s).font(.caption2).foregroundStyle(Theme.Color.muted).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 36) }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDateInToday(day)
        let marked = markedDays.contains(cal.startOfDay(for: day))
        return Button { selected = day } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.callout)
                    .foregroundStyle(isSelected ? Theme.Color.bg : (isToday ? Theme.Color.accentCyan : Theme.Color.fg))
                Circle().fill(marked ? Theme.Color.accentCyan : Color.clear).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(isSelected ? Theme.Color.accentCyan : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var weekdaySymbols: [String] {
        let s = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    private var days: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = interval.start
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 0
        let leading = (cal.component(.weekday, from: firstDay) - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<count {
            if let d = cal.date(byAdding: .day, value: offset, to: firstDay) { result.append(d) }
        }
        return result
    }
}

// MARK: - 单动作历史曲线（保留：从训练详情进入）

struct ExerciseHistoryChartView: View {
    let exerciseKey: String
    let exerciseName: String

    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil },
           sort: \Workout.startedAt, order: .forward)
    private var workouts: [Workout]

    struct Point: Identifiable {
        let date: Date
        let maxWeight: Double
        let totalReps: Int
        var id: Date { date }
    }

    private var points: [Point] {
        workouts.compactMap { w -> Point? in
            let sets = w.exercises
                .filter { $0.historyKey == exerciseKey }
                .flatMap(\.sets)
                .filter { $0.weightKg != nil }
            guard let maxW = sets.compactMap(\.weightKg).max() else { return nil }
            let reps = sets.reduce(0) { $0 + ($1.reps ?? 0) }
            return Point(date: w.startedAt, maxWeight: maxW, totalReps: reps)
        }
    }

    var body: some View {
        // 必要的 List 用法：曲线 + 记录条目混排。
        List {
            Section("重量趋势") {
                if points.count < 2 {
                    Text("至少需要两次记录才能画出趋势").foregroundStyle(Theme.Color.muted)
                } else {
                    Chart(points) { p in
                        LineMark(x: .value("日期", p.date, unit: .day),
                                 y: .value("重量", p.maxWeight))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.Color.accentCyan)
                        PointMark(x: .value("日期", p.date, unit: .day),
                                  y: .value("重量", p.maxWeight))
                            .foregroundStyle(Theme.Color.accentCyan)
                    }
                    .chartYAxisLabel("kg")
                    .frame(height: 220)
                    .padding(.vertical, 8)
                }
            }
            Section("记录") {
                ForEach(points.reversed()) { p in
                    HStack {
                        Text(p.date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(Theme.Color.fg)
                        Spacer()
                        Text("\(formatKg(p.maxWeight)) kg")
                            .bold()
                            .foregroundStyle(Theme.Color.fg)
                    }
                    .font(.subheadline)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Color.bg)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
