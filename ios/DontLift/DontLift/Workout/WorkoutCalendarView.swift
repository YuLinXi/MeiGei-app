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
    @State private var showingMonthArchive = false

    private let calendar = Calendar.currentMondayFirst
    private let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }()
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var month: WorkoutCalendarMonthSnapshot {
        historyStore.calendarMonth(containing: displayedMonth, calendar: calendar)
    }

    private var selectedSummary: WorkoutCalendarDaySummary? {
        historyStore.calendarDay(for: selectedDate, calendar: calendar)
    }

    private var showTodayButton: Bool {
        !calendar.isDate(selectedDate, inSameDayAs: .now)
            || !calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private var monthSummaryText: String {
        "\(month.workoutCount) 次训练 · \(formatTons(month.volumeKg)) t · \(month.setCount) 正式组"
    }

    private func layoutMetrics(for size: CGSize) -> WorkoutCalendarLayoutMetrics {
        let compact = size.height < 780
        let sectionSpacing: CGFloat = compact ? 8 : 12
        let topPadding: CGFloat = compact ? 2 : Theme.Spacing.sm
        let bottomPadding: CGFloat = 10
        let headerEstimate: CGFloat = compact ? 96 : 112
        let workoutCount = selectedSummary?.workouts.count ?? 0
        let drawerRows = workoutCount == 0 ? 0 : min(workoutCount, compact ? 1 : 2)
        let drawerHeight: CGFloat
        switch drawerRows {
        case 0:
            drawerHeight = compact ? 112 : 124
        case 1:
            drawerHeight = compact ? 128 : 142
        default:
            drawerHeight = compact ? 172 : 188
        }

        let reservedDrawerHeight: CGFloat = compact ? 128 : 188
        let calendarAvailable = size.height
            - topPadding
            - bottomPadding
            - headerEstimate
            - reservedDrawerHeight
            - sectionSpacing * 2
        let calendarChrome: CGFloat = 16 + 16 + 6 + 25
        let rawCellHeight = floor((calendarAvailable - calendarChrome) / 6)
        let dayCellHeight = min(max(rawCellHeight, compact ? 44 : 48), compact ? 54 : 58)
        return WorkoutCalendarLayoutMetrics(
            sectionSpacing: sectionSpacing,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            dayCellHeight: dayCellHeight,
            drawerHeight: drawerHeight,
            drawerRows: drawerRows
        )
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            GeometryReader { proxy in
                let metrics = layoutMetrics(for: proxy.size)
                VStack(spacing: metrics.sectionSpacing) {
                    monthHeader
                    calendarGrid(dayCellHeight: metrics.dayCellHeight)
                        .layoutPriority(1)
                    selectedDayDrawer(maxRows: metrics.drawerRows)
                        .frame(height: metrics.drawerHeight, alignment: .top)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .paperToolbar(title: "历史", onBack: { dismiss() })
        .sheet(isPresented: $showingMonthArchive) {
            MonthArchiveSheet(
                initialMonth: displayedMonth,
                yearGroups: historyStore.calendarArchiveYearGroups(calendar: calendar),
                calendar: calendar
            ) { pickedMonth in
                applyPickedMonth(pickedMonth)
            }
        }
        .navigationDestination(item: $openedWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .onAppear {
            WorkoutPerformanceMonitor.event("history.calendar.open")
            historyStore.ensureLoaded(reason: .manual)
            displayedMonth = monthStart(for: selectedDate)
        }
    }

    private var monthHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("训练日历").eyebrowStyle()
            HStack(spacing: 8) {
                Text(monthTitle(month.monthStart))
                    .font(Theme.Font.display(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                CircleIconButton(systemName: "calendar", size: 34, active: true) {
                    Theme.Haptics.selection()
                    showingMonthArchive = true
                }
                .accessibilityLabel("选择月份")
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    CircleIconButton(systemName: "chevron.left", size: 34, action: { shiftMonth(-1) })
                        .accessibilityLabel("上个月")
                    CircleIconButton(systemName: "chevron.right", size: 34, action: { shiftMonth(1) })
                        .accessibilityLabel("下个月")
                }
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text(monthSummaryText)
                    .font(Theme.Font.body(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: Theme.Spacing.sm)
                todayButtonSlot
            }
            .frame(height: 30)
        }
    }

    @ViewBuilder
    private var todayButtonSlot: some View {
        if showTodayButton {
            Button(action: jumpToToday) {
                Text("今天")
                    .font(Theme.Font.body(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 58, height: 30)
                    .background(Theme.Color.accentSoft, in: Capsule())
                    .overlay(Capsule().stroke(Theme.Color.accentSofter, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("回到今天")
        } else {
            Color.clear
                .frame(width: 58, height: 30)
                .accessibilityHidden(true)
        }
    }

    private func calendarGrid(dayCellHeight: CGFloat) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(month.days) { day in
                    dayCell(day, height: dayCellHeight)
                }
            }
        }
        .cardStyle(padding: 8)
    }

    private func selectedDayDrawer(maxRows: Int) -> some View {
        let hiddenCount = max((selectedSummary?.workouts.count ?? 0) - maxRows, 0)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(selectedDate))
                        .font(Theme.Font.body(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(selectedSummary.map { "\($0.workoutCount) 次训练 · \($0.setCount) 正式组 · \(formatTons($0.volumeKg)) t" } ?? "没有训练记录")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: Theme.Spacing.sm)
                HStack(spacing: 6) {
                    if hiddenCount > 0 {
                        Text("+\(hiddenCount)")
                            .font(Theme.Font.mono(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Color.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Color.accentSoft, in: Capsule())
                    }
                    if selectedSummary?.hasPR == true {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 8, weight: .heavy))
                            Text("PR")
                                .font(Theme.Font.mono(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Theme.Color.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Color.accentSofter, in: Capsule())
                    }
                }
            }

            if let summary = selectedSummary, !summary.workouts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(summary.workouts.prefix(maxRows))) { row in
                        Button { openWorkout(row.id) } label: {
                            workoutRow(row, compact: true)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            } else {
                Text("选一个有标记的日期，查看那天练了什么。")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
        .cardStyle(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.lg)
        .paperShadow(.lg, cornerRadius: Theme.Radius.lg)
    }

    private func dayCell(_ day: WorkoutCalendarDayCell, height: CGFloat) -> some View {
        let selected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let trained = day.summary != nil
        let summary = day.summary
        let compact = height < 54
        return Button {
            Theme.Haptics.selection()
            selectedDate = day.date
            if !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = monthStart(for: day.date)
            }
        } label: {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(Theme.Font.number(size: compact ? 13 : 15, weight: trained ? .bold : .semibold))
                    .foregroundStyle(dayTextColor(day, selected: selected))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let summary {
                    Text(dayTrainingTitle(summary))
                        .font(Theme.Font.body(size: compact ? 9.4 : 10.8, weight: .bold))
                        .foregroundStyle(selected ? Theme.Color.bg.opacity(0.9) : Theme.Color.fg2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Spacer(minLength: 0)
                    if day.isToday {
                        Circle()
                            .fill(Theme.Color.accentSofter)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(.horizontal, compact ? 5 : 7)
            .padding(.vertical, compact ? 4 : 7)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(dayBackground(day, selected: selected), in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(dayBorder(day, selected: selected), lineWidth: selected || day.isToday ? 1 : 0)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func dayTrainingTitle(_ summary: WorkoutCalendarDaySummary) -> String {
        let title = summary.workouts.first?.title ?? "训练"
        guard summary.workoutCount > 1 else { return title }
        return "\(title) +\(summary.workoutCount - 1)"
    }

    private func workoutRow(_ row: WorkoutRowSummary, compact: Bool = false) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: 2) {
                Text(timeText(row.startedAt))
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

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        WorkoutPerformanceMonitor.event("history.calendar.monthSwitch")
        displayedMonth = monthStart(for: next)
        if !calendar.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) {
            selectedDate = displayedMonth
        }
    }

    private func jumpToToday() {
        Theme.Haptics.selection()
        let today = calendar.startOfDay(for: .now)
        selectedDate = today
        displayedMonth = monthStart(for: today)
    }

    private func applyPickedMonth(_ monthStart: Date) {
        Theme.Haptics.selection()
        WorkoutPerformanceMonitor.event("history.calendar.monthPick")
        displayedMonth = monthStart
        if calendar.isDate(monthStart, equalTo: .now, toGranularity: .month) {
            selectedDate = calendar.startOfDay(for: .now)
        } else if let firstWorkoutDay = historyStore
            .calendarMonth(containing: monthStart, calendar: calendar)
            .days
            .filter(\.isInDisplayedMonth)
            .compactMap({ $0.summary?.date })
            .sorted()
            .first {
            selectedDate = firstWorkoutDay
        } else {
            selectedDate = monthStart
        }
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

    private func monthTitle(_ date: Date) -> String {
        Self.monthFormatter.string(from: date)
    }

    private func dayTitle(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func timeText(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func dayTextColor(_ day: WorkoutCalendarDayCell, selected: Bool) -> Color {
        if selected { return Theme.Color.bg }
        if !day.isInDisplayedMonth { return Theme.Color.muted.opacity(0.55) }
        if day.summary != nil { return Theme.Color.fg }
        return Theme.Color.fg2
    }

    private func dayBackground(_ day: WorkoutCalendarDayCell, selected: Bool) -> Color {
        if selected { return Theme.Color.accent }
        if day.summary != nil { return Theme.Color.accentSoft }
        return Theme.Color.bg
    }

    private func dayBorder(_ day: WorkoutCalendarDayCell, selected: Bool) -> Color {
        if selected { return Theme.Color.accent }
        if day.isToday { return Theme.Color.accentSofter }
        return .clear
    }

    private func accessibilityLabel(for day: WorkoutCalendarDayCell) -> String {
        let title = dayTitle(day.date)
        if let summary = day.summary {
            return "\(title)，\(summary.workoutCount) 次训练"
        }
        return "\(title)，没有训练"
    }
}

private struct WorkoutCalendarLayoutMetrics {
    var sectionSpacing: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var dayCellHeight: CGFloat
    var drawerHeight: CGFloat
    var drawerRows: Int
}

private struct MonthArchiveSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialMonth: Date
    let yearGroups: [WorkoutCalendarYearArchiveGroup]
    let calendar: Calendar
    let onPick: (Date) -> Void
    private let topID = "month-archive-top"

    init(
        initialMonth: Date,
        yearGroups: [WorkoutCalendarYearArchiveGroup],
        calendar: Calendar,
        onPick: @escaping (Date) -> Void
    ) {
        self.initialMonth = initialMonth
        self.yearGroups = yearGroups
        self.calendar = calendar
        self.onPick = onPick
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "选择月份",
                cancelTitle: "完成",
                background: Theme.Color.bg,
                onCancel: { dismiss() }
            )
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            Color.clear.frame(height: 0).id(topID)
                            ForEach(yearGroups) { group in
                                yearHeader(group.year)
                                    .id(group.id)
                                ForEach(group.months) { item in
                                    monthArchiveRow(item)
                                        .id(item.id)
                                }
                            }
                        }
                        .padding(.leading, Theme.Spacing.lg)
                        .padding(.trailing, Theme.Spacing.xl + 22)
                        .padding(.vertical, Theme.Spacing.lg)
                    }
                    .background(Theme.Color.bg)

                    yearIndex(proxy)
                        .padding(.trailing, 7)
                        .padding(.vertical, Theme.Spacing.lg)
                        .frame(maxHeight: .infinity, alignment: .topTrailing)
                }
                .onAppear {
                    scrollToInitialMonth(proxy)
                }
            }
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func yearHeader(_ year: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(year)")
                .font(Theme.Font.display(size: 22, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
            Rectangle()
                .fill(Theme.Color.border)
                .frame(height: 1)
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .accessibilityAddTraits(.isHeader)
    }

    private func yearIndex(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 7) {
            Button {
                Theme.Haptics.selection()
                withAnimation(.snappy) {
                    proxy.scrollTo(topID, anchor: .top)
                }
            } label: {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 26, height: 26)
                    .background(Theme.Color.accentSoft, in: Circle())
                    .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("回到顶部")

            ForEach(yearGroups) { group in
                Button {
                    Theme.Haptics.selection()
                    withAnimation(.snappy) {
                        proxy.scrollTo(group.id, anchor: .top)
                    }
                } label: {
                    Text(String(String(group.year).suffix(2)))
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(isInitialYear(group.year) ? Theme.Color.accent : Theme.Color.muted)
                        .frame(width: 26, height: 24)
                        .background(isInitialYear(group.year) ? Theme.Color.accentSoft : Theme.Color.surface, in: Capsule())
                        .overlay(Capsule().stroke(isInitialYear(group.year) ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("跳转到\(group.year)年")
            }
        }
    }

    private func isInitialYear(_ year: Int) -> Bool {
        calendar.component(.year, from: initialMonth) == year
    }

    private func monthArchiveRow(_ item: WorkoutCalendarMonthArchiveItem) -> some View {
        let selected = calendar.isDate(item.monthStart, equalTo: initialMonth, toGranularity: .month)
        return Button {
            onPick(item.monthStart)
            dismiss()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text("\(calendar.component(.month, from: item.monthStart))月")
                            .font(Theme.Font.body(size: 18, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                        if item.trainingDayCount > 0 {
                            Text("\(item.trainingDayCount)天")
                                .font(Theme.Font.body(size: 12, weight: .bold))
                                .foregroundStyle(Theme.Color.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Color.accentSoft, in: Capsule())
                        }
                    }
                    monthDensityStrip(item)
                }
                Spacer(minLength: Theme.Spacing.sm)
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.workoutCount > 0 ? "\(item.workoutCount)次" : "—")
                            .font(Theme.Font.mono(size: 12, weight: .bold))
                            .foregroundStyle(item.workoutCount > 0 ? Theme.Color.fg2 : Theme.Color.muted)
                        Text(item.volumeKg > 0 ? formatTons(item.volumeKg) + "t" : "—")
                            .font(Theme.Font.mono(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Color.muted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(selected ? Theme.Color.accentSoft : Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(selected ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(monthAccessibilityLabel(item))
    }

    private func monthDensityStrip(_ item: WorkoutCalendarMonthArchiveItem) -> some View {
        HStack(spacing: 2) {
            ForEach(1...31, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(densityColor(day: day, item: item))
                    .frame(width: 4, height: 8)
                    .opacity(day <= daysInMonth(item.monthStart) ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func densityColor(day: Int, item: WorkoutCalendarMonthArchiveItem) -> Color {
        item.activeDayNumbers.contains(day) ? Theme.Color.accent : Theme.Color.border
    }

    private func daysInMonth(_ monthStart: Date) -> Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 31
    }

    private func scrollToInitialMonth(_ proxy: ScrollViewProxy) {
        let target = yearGroups
            .flatMap(\.months)
            .first { calendar.isDate($0.monthStart, equalTo: initialMonth, toGranularity: .month) }?
            .id
        guard let target else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func monthAccessibilityLabel(_ item: WorkoutCalendarMonthArchiveItem) -> String {
        let year = calendar.component(.year, from: item.monthStart)
        let month = calendar.component(.month, from: item.monthStart)
        if item.trainingDayCount > 0 {
            return "\(year)年\(month)月，\(item.trainingDayCount)天有训练，\(item.workoutCount)次训练"
        }
        return "\(year)年\(month)月，没有训练"
    }
}
