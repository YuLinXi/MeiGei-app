import SwiftUI
import SwiftData
import Charts

// MARK: - 3.9 训练历史：日历 + 单动作历史曲线

/// 按动作归并历史的稳定 key：内置 code 优先，其次自定义 id，最后回退动作名。
extension WorkoutExercise {
    var historyKey: String { builtinExerciseCode ?? customExerciseId?.uuidString ?? exerciseName }
}

/// 历史入口：日历 / 动作趋势两段切换。统计全部由原始记录重算，不持久化派生数据（design.md Non-Goals）。
struct TrainingHistoryView: View {
    private enum Tab: String, CaseIterable, Identifiable { case calendar = "日历", trends = "动作趋势"; var id: String { rawValue } }
    @State private var tab: Tab = .calendar

    var body: some View {
        VStack(spacing: 0) {
            Picker("视图", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            switch tab {
            case .calendar: WorkoutCalendarView()
            case .trends: ExerciseTrendListView()
            }
        }
        .navigationTitle("训练历史")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 训练日历

/// 按月日历：有已完成训练的日期标点，点选某天列出当天训练。
struct WorkoutCalendarView: View {
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var month: Date = .now
    @State private var selected: Date = .now

    private var cal: Calendar { Calendar.current }

    /// 当月「日 → 训练」索引，只取已完成训练。
    private var byDay: [Date: [Workout]] {
        Dictionary(grouping: workouts) { cal.startOfDay(for: $0.startedAt) }
    }

    private var selectedWorkouts: [Workout] {
        byDay[cal.startOfDay(for: selected)] ?? []
    }

    var body: some View {
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
                    Text("这天没有训练").foregroundStyle(.secondary)
                } else {
                    ForEach(selectedWorkouts) { w in
                        NavigationLink(value: w) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.title ?? "训练").font(.headline)
                                Text(daySummary(w)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Workout.self) { WorkoutLoggingView(workout: $0) }
    }

    private func shift(_ months: Int) {
        if let m = cal.date(byAdding: .month, value: months, to: month) { month = m }
    }

    private func daySummary(_ w: Workout) -> String {
        let sets = w.exercises.reduce(0) { $0 + $1.sets.count }
        return "\(w.startedAt.formatted(date: .omitted, time: .shortened)) · \(w.exercises.count)动作/\(sets)组"
    }
}

/// 单月网格。仅做展示与选择，不承载业务统计。
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
                Button(action: onPrev) { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.year().month())).font(.headline)
                Spacer()
                Button(action: onNext) { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)
            HStack {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
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
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                Circle().fill(marked ? Color.accentColor : Color.clear).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var weekdaySymbols: [String] {
        let s = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    /// 当月日期，前面用 nil 占位对齐周首。
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

// MARK: - 单动作历史曲线

/// 有历史记录的动作列表 → 进入曲线。
private struct ExerciseTrendListView: View {
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil && $0.endedAt != nil })
    private var workouts: [Workout]

    /// 归并出有记录的动作（key → 展示名 + 出现次数），按最近训练时间排序。
    private var exercises: [(key: String, name: String, lastDate: Date)] {
        var latest: [String: (name: String, date: Date)] = [:]
        for w in workouts {
            for ex in w.exercises where ex.sets.contains(where: { $0.weightKg != nil }) {
                let cur = latest[ex.historyKey]
                if cur == nil || w.startedAt > cur!.date {
                    latest[ex.historyKey] = (ex.exerciseName, w.startedAt)
                }
            }
        }
        return latest.map { (key: $0.key, name: $0.value.name, lastDate: $0.value.date) }
            .sorted { $0.lastDate > $1.lastDate }
    }

    var body: some View {
        List {
            if exercises.isEmpty {
                ContentUnavailableView("还没有可统计的记录", systemImage: "chart.xyaxis.line",
                                       description: Text("记录带重量的训练后这里会出现趋势曲线"))
            } else {
                ForEach(exercises, id: \.key) { ex in
                    NavigationLink {
                        ExerciseHistoryChartView(exerciseKey: ex.key, exerciseName: ex.name)
                    } label: {
                        Text(ex.name)
                    }
                }
            }
        }
    }
}

/// 单动作历史曲线：默认展示每次训练的最大重量趋势（spec：默认重量趋势）。
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

    /// 每次训练取该动作的最大重量（重算，不持久化）。
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
        List {
            Section("重量趋势") {
                if points.count < 2 {
                    Text("至少需要两次记录才能画出趋势").foregroundStyle(.secondary)
                } else {
                    Chart(points) { p in
                        LineMark(x: .value("日期", p.date, unit: .day),
                                 y: .value("重量", p.maxWeight))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("日期", p.date, unit: .day),
                                  y: .value("重量", p.maxWeight))
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
                        Spacer()
                        Text("\(formatKg(p.maxWeight)) kg").bold()
                    }
                    .font(.subheadline)
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
