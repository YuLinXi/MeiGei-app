import SwiftUI
import SwiftData

/// 历史训练日历：月历扫视训练节奏，底部抽屉查看选中日期的训练记录。
struct WorkoutCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutHistoryStore.self) private var historyStore

    @State private var displayedMonth = Calendar.currentMondayFirst.startOfDay(for: .now)
    @State private var selectedDate = Calendar.currentMondayFirst.startOfDay(for: .now)
    @State private var openedWorkout: Workout?

    private let calendar = Calendar.currentMondayFirst
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var month: CalendarHistoryMonthSnapshot<WorkoutRowSummary> {
        historyStore.calendarMonth(containing: displayedMonth, calendar: calendar).calendarHistorySnapshot()
    }

    var body: some View {
        CalendarHistoryScaffold(
            displayedMonth: $displayedMonth,
            selectedDate: $selectedDate,
            eyebrow: "训练日历",
            month: month,
            archiveGroups: historyStore.calendarArchiveYearGroups(calendar: calendar).calendarHistoryGroups(),
            calendar: calendar,
            monthSummaryText: { month in
                "\(month.rowCount) 次训练 · \(formatTons(month.volumeKg)) t · \(month.setCount) 正式组"
            },
            selectedSummaryText: { summary in
                summary.map { "\($0.rowCount) 次训练 · \($0.setCount) 正式组 · \(formatTons($0.volumeKg)) t" } ?? "没有训练记录"
            },
            emptySelectedDayText: "选一个有标记的日期，查看那天练了什么。",
            daySummaryTitle: dayTrainingTitle,
            selectedBadges: { summary in
                summary.hasHighlight ? [CalendarHistoryBadge(text: "PR", systemName: "arrowtriangle.up.fill")] : []
            },
            rowContent: { row, compact in
                workoutRow(row, compact: compact)
            },
            onRowTap: { row in
                openWorkout(row.id)
            },
            selectedDateAfterPickingMonth: selectedDateAfterPickingMonth,
            onMonthChange: { _ in
                WorkoutPerformanceMonitor.event("history.calendar.monthSwitch")
            }
        )
        .paperToolbar(title: "历史", onBack: { dismiss() })
        .navigationDestination(item: $openedWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .onAppear {
            WorkoutPerformanceMonitor.event("history.calendar.open")
            historyStore.ensureLoaded(reason: .manual)
            displayedMonth = monthStart(for: selectedDate)
        }
    }

    private func selectedDateAfterPickingMonth(_ monthStart: Date) -> Date {
        WorkoutPerformanceMonitor.event("history.calendar.monthPick")
        if calendar.isDate(monthStart, equalTo: .now, toGranularity: .month) {
            return calendar.startOfDay(for: .now)
        }
        if let firstWorkoutDay = historyStore
            .calendarMonth(containing: monthStart, calendar: calendar)
            .days
            .filter(\.isInDisplayedMonth)
            .compactMap({ $0.summary?.date })
            .sorted()
            .first {
            return firstWorkoutDay
        }
        return monthStart
    }

    private func dayTrainingTitle(_ summary: CalendarHistoryDaySummary<WorkoutRowSummary>) -> String {
        let title = summary.rows.first?.title ?? "训练"
        guard summary.rowCount > 1 else { return title }
        return "\(title) +\(summary.rowCount - 1)"
    }

    private func workoutRow(_ row: WorkoutRowSummary, compact: Bool = false) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: 2) {
                Text(Self.timeFormatter.string(from: row.startedAt))
                    .font(Theme.Font.mono(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text(row.durationSec.map(formatMinutes) ?? "—")
                    .font(Theme.Font.mono(size: compact ? 8 : 9, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
            }
            .frame(width: compact ? 48 : 52, height: compact ? 40 : 46)
            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(Theme.Font.body(size: compact ? 13 : 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                Text("\(row.exerciseCount) 动作 · \(row.setCount) 组 · \(formatTons(row.volumeKg))t")
                    .font(Theme.Font.body(size: compact ? 10.5 : 11.5))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(compact ? 8 : 10)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func openWorkout(_ id: UUID) {
        if let workout = fetchWorkout(id) {
            openedWorkout = workout
        }
    }

    private func fetchWorkout(_ id: UUID) -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.localId == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func monthStart(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
    }
}

private extension WorkoutCalendarMonthSnapshot {
    func calendarHistorySnapshot() -> CalendarHistoryMonthSnapshot<WorkoutRowSummary> {
        CalendarHistoryMonthSnapshot(
            monthStart: monthStart,
            days: days.map { $0.calendarHistoryCell() },
            rowCount: workoutCount,
            setCount: setCount,
            volumeKg: volumeKg
        )
    }
}

private extension WorkoutCalendarDayCell {
    func calendarHistoryCell() -> CalendarHistoryDayCell<WorkoutRowSummary> {
        CalendarHistoryDayCell(
            date: date,
            isInDisplayedMonth: isInDisplayedMonth,
            isToday: isToday,
            summary: summary?.calendarHistorySummary()
        )
    }
}

private extension WorkoutCalendarDaySummary {
    func calendarHistorySummary() -> CalendarHistoryDaySummary<WorkoutRowSummary> {
        CalendarHistoryDaySummary(
            date: date,
            rows: workouts,
            setCount: setCount,
            volumeKg: volumeKg,
            hasHighlight: hasPR
        )
    }
}

private extension Array where Element == WorkoutCalendarYearArchiveGroup {
    func calendarHistoryGroups() -> [CalendarHistoryYearArchiveGroup] {
        map {
            CalendarHistoryYearArchiveGroup(
                year: $0.year,
                months: $0.months.map { $0.calendarHistoryItem() }
            )
        }
    }
}

private extension WorkoutCalendarMonthArchiveItem {
    func calendarHistoryItem() -> CalendarHistoryMonthArchiveItem {
        CalendarHistoryMonthArchiveItem(
            monthStart: monthStart,
            trainingDayCount: trainingDayCount,
            workoutCount: workoutCount,
            setCount: setCount,
            volumeKg: volumeKg,
            activeDayNumbers: activeDayNumbers
        )
    }
}
