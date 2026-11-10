import SwiftUI

struct CalendarHistoryDaySummary<Row: Identifiable & Hashable>: Identifiable, Equatable, Hashable {
    var date: Date
    var rows: [Row]
    var setCount: Int
    var volumeKg: Double
    var hasHighlight: Bool = false

    var id: Date { date }
    var rowCount: Int { rows.count }
}

struct CalendarHistoryDayCell<Row: Identifiable & Hashable>: Identifiable, Equatable, Hashable {
    var date: Date
    var isInDisplayedMonth: Bool
    var isToday: Bool
    var summary: CalendarHistoryDaySummary<Row>?

    var id: Date { date }
}

struct CalendarHistoryMonthSnapshot<Row: Identifiable & Hashable>: Equatable, Hashable {
    var monthStart: Date
    var days: [CalendarHistoryDayCell<Row>]
    var rowCount: Int
    var setCount: Int
    var volumeKg: Double

    static func empty(monthStart: Date) -> CalendarHistoryMonthSnapshot<Row> {
        CalendarHistoryMonthSnapshot(monthStart: monthStart, days: [], rowCount: 0, setCount: 0, volumeKg: 0)
    }
}

struct CalendarHistoryMonthArchiveItem: Identifiable, Equatable, Hashable {
    var monthStart: Date
    var isLoaded: Bool = true
    var trainingDayCount: Int
    var workoutCount: Int
    var setCount: Int
    var volumeKg: Double
    var activeDayNumbers: Set<Int>

    var id: Date { monthStart }
}

struct CalendarHistoryYearArchiveGroup: Identifiable, Equatable, Hashable {
    var year: Int
    var months: [CalendarHistoryMonthArchiveItem]

    var id: Int { year }
}

struct CalendarHistoryBadge: Identifiable, Equatable, Hashable {
    var id: String { text }
    var text: String
    var systemName: String?
}

/// 个人历史与 Team 历史共用的月历展示壳。数据源、行内容和详情目标由调用方注入。
struct CalendarHistoryScaffold<Row: Identifiable & Hashable, RowContent: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var dayNumeralWidth: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var dayNumberLineHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var daySummaryLineHeight: CGFloat = 13
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date

    let eyebrow: String
    let month: CalendarHistoryMonthSnapshot<Row>
    /// 月份归档只在选择器打开时生成，普通切月不重复汇总全部历史日期。
    let archiveGroups: () -> [CalendarHistoryYearArchiveGroup]
    let calendar: Calendar
    var minimumSelectableDate: Date? = nil
    var hasSnapshot = true
    var loadMessage: String? = nil
    var onRetry: (() -> Void)? = nil
    let monthSummaryText: (CalendarHistoryMonthSnapshot<Row>) -> String
    let selectedSummaryText: (CalendarHistoryDaySummary<Row>?) -> String
    let emptySelectedDayText: String
    let daySummaryTitle: (CalendarHistoryDaySummary<Row>) -> String
    let selectedBadges: (CalendarHistoryDaySummary<Row>) -> [CalendarHistoryBadge]
    let rowContent: (Row, Bool) -> RowContent
    let onRowTap: (Row) -> Void
    let selectedDateAfterPickingMonth: (Date) -> Date
    let onMonthChange: (Date) -> Void

    @State private var showingMonthArchive = false

    private let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    private var selectedSummary: CalendarHistoryDaySummary<Row>? {
        month.days.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }?.summary
    }

    private var showTodayButton: Bool {
        !calendar.isDate(selectedDate, inSameDayAs: .now)
            || !calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }
    private var minimumDay: Date? {
        minimumSelectableDate.map { calendar.startOfDay(for: $0) }
    }
    private var minimumMonthStart: Date? {
        minimumDay.map(monthStart(for:))
    }
    private var canGoPreviousMonth: Bool {
        guard let minimumMonthStart else { return true }
        return monthStart(for: displayedMonth) > minimumMonthStart
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            GeometryReader { proxy in
                let metrics = layoutMetrics(for: proxy.size)
                ScrollView {
                    VStack(spacing: metrics.sectionSpacing) {
                        monthHeader
                        loadFeedback
                        calendarGrid(dayCellHeight: metrics.dayCellHeight,
                                     availableWidth: proxy.size.width - Theme.Spacing.lg * 2)
                            .layoutPriority(1)
                        selectedDayDrawer(maxRows: metrics.drawerRows)
                            .frame(height: dynamicTypeSize >= .xxLarge ? nil : metrics.drawerHeight, alignment: .top)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, metrics.topPadding)
                    .padding(.bottom, metrics.bottomPadding)
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("calendar.history.scroll")
            }
        }
        .sheet(isPresented: $showingMonthArchive) {
            CalendarHistoryMonthArchiveSheet(
                initialMonth: displayedMonth,
                yearGroups: archiveGroups(),
                calendar: calendar,
                emptyMessage: hasSnapshot ? "暂无可查看的训练月份。" : "月份记录尚未就绪。"
            ) { pickedMonth in
                applyPickedMonth(pickedMonth)
            }
        }
    }

    private func layoutMetrics(for size: CGSize) -> CalendarHistoryLayoutMetrics {
        let compact = size.height < 780
        let sectionSpacing: CGFloat = compact ? 8 : 12
        let topPadding: CGFloat = compact ? 2 : Theme.Spacing.sm
        let bottomPadding: CGFloat = 10
        let headerEstimate: CGFloat = compact ? 96 : 112
        let rowCount = selectedSummary?.rows.count ?? 0
        let maxDrawerRows = compact ? 3 : 4
        let drawerRows = rowCount == 0 ? 0 : min(rowCount, maxDrawerRows)
        let drawerHeight = drawerFrameHeight(visibleRows: drawerRows, compact: compact)
        let reservedDrawerHeight = drawerFrameHeight(visibleRows: maxDrawerRows, compact: compact)

        let calendarAvailable = size.height
            - topPadding
            - bottomPadding
            - headerEstimate
            - reservedDrawerHeight
            - sectionSpacing * 2
        let calendarChrome: CGFloat = 16 + 16 + 6 + 25
        let rawCellHeight = floor((calendarAvailable - calendarChrome) / 6)
        let dayCellHeight = min(max(rawCellHeight, compact ? 44 : 48), compact ? 54 : 58)
        return CalendarHistoryLayoutMetrics(
            sectionSpacing: sectionSpacing,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            dayCellHeight: dayCellHeight,
            drawerHeight: drawerHeight,
            drawerRows: drawerRows
        )
    }

    private func drawerFrameHeight(visibleRows: Int, compact: Bool) -> CGFloat {
        guard visibleRows > 0 else { return compact ? 112 : 124 }
        let rowHeight: CGFloat = 56
        let rowSpacing: CGFloat = 8
        let headerHeight: CGFloat = compact ? 40 : 42
        let cardPadding = Theme.Spacing.md * 2
        let rowsHeight = CGFloat(visibleRows) * rowHeight + CGFloat(max(visibleRows - 1, 0)) * rowSpacing
        return cardPadding + headerHeight + Theme.Spacing.sm + rowsHeight
    }

    private var monthHeader: some View {
        let expanded = dynamicTypeSize >= .xxLarge
        let layout = expanded
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).eyebrowStyle()
            layout {
                Group {
                    if expanded {
                        let year = Text(String(calendar.component(.year, from: month.monthStart)) + "年").fixedSize()
                        let monthTitle = Text(String(calendar.component(.month, from: month.monthStart)) + "月").fixedSize()
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) { year; monthTitle }
                            VStack(alignment: .leading, spacing: 0) { year; monthTitle }
                        }
                    } else {
                        Text(CalendarHistoryFormatters.month.string(from: month.monthStart))
                            .lineLimit(1).minimumScaleFactor(0.78)
                    }
                }
                .font(Theme.Font.display(size: 30, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                HStack(spacing: 8) {
                    CircleIconButton(systemName: "calendar", size: 34, active: true) {
                        Theme.Haptics.selection()
                        showingMonthArchive = true
                    }
                    .accessibilityLabel("选择月份")
                    Spacer(minLength: 0)
                    CircleIconButton(systemName: "chevron.left", size: 34, action: { shiftMonth(-1) })
                        .disabled(!canGoPreviousMonth)
                        .opacity(canGoPreviousMonth ? 1 : 0.35)
                        .accessibilityLabel("上个月")
                    CircleIconButton(systemName: "chevron.right", size: 34, action: { shiftMonth(1) })
                        .accessibilityLabel("下个月")
                }
            }
            layout {
                Text(hasSnapshot ? monthSummaryText(month) : "训练记录尚未就绪")
                    .font(Theme.Font.body(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(expanded ? nil : 1)
                    .minimumScaleFactor(expanded ? 1 : 0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendar.month.summary")
                if !expanded { Spacer(minLength: Theme.Spacing.sm) }
                if showTodayButton || !expanded { todayButtonSlot }
            }
            .frame(minHeight: 30)
        }
    }

    @ViewBuilder private var loadFeedback: some View {
        if let loadMessage {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(loadMessage)
                    .font(Theme.Font.l4)
                    .foregroundStyle(Theme.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendar.history.status")
                if let onRetry {
                    Button(action: onRetry) {
                        Text("重试加载记录")
                            .font(Theme.Font.l3)
                            .foregroundStyle(Theme.Color.action)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("calendar.history.retry")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var todayButtonSlot: some View {
        if showTodayButton {
            Button(action: jumpToToday) {
                Text("今天")
                    .font(Theme.Font.body(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.action)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .frame(minWidth: 58, minHeight: 30)
                    .background(Theme.Color.accentSoft, in: Capsule())
                    .overlay(Capsule().stroke(Theme.Color.accentSofter, lineWidth: 1))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("回到今天")
        } else {
            Color.clear
                .frame(width: 58, height: 44)
                .accessibilityHidden(true)
        }
    }

    private func calendarGrid(dayCellHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let width = max(availableWidth, max(44, dayNumeralWidth + 14) * 7 + 30 + 16)
        let height = dynamicTypeSize >= .xxLarge
            ? max(dayCellHeight, dayNumberLineHeight + daySummaryLineHeight + 18) : dayCellHeight
        return VStack(alignment: .leading, spacing: 6) {
            if width > availableWidth {
                Text("左右滑动查看整周")
                    .font(Theme.Font.body(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            ScrollView(.horizontal) {
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
                        ForEach(month.days) { day in dayCell(day, height: height) }
                    }
                }
                .frame(width: width - 16)
                .cardStyle(padding: 8)
            }
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("calendar.grid")
        }
    }

    private func selectedDayDrawer(maxRows: Int) -> some View {
        let rows = selectedSummary?.rows ?? []
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            let layout = dynamicTypeSize >= .xxLarge
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CalendarHistoryFormatters.day.string(from: selectedDate))
                        .font(Theme.Font.body(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(hasSnapshot ? selectedSummaryText(selectedSummary) : "所选日期的记录尚未就绪")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                        .lineLimit(dynamicTypeSize >= .xxLarge ? nil : 1)
                        .minimumScaleFactor(dynamicTypeSize >= .xxLarge ? 1 : 0.8)
                        .accessibilityIdentifier("calendar.day.summary")
                }
                if dynamicTypeSize < .xxLarge { Spacer(minLength: Theme.Spacing.sm) }
                HStack(spacing: 6) {
                    ForEach(selectedSummary.map(selectedBadges) ?? []) { badge in
                        HStack(spacing: 4) {
                            if let systemName = badge.systemName {
                                Image(systemName: systemName)
                                    .font(.system(size: 8, weight: .heavy))
                            }
                            Text(badge.text)
                                .font(Theme.Font.mono(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Theme.Color.action)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Color.accentSofter, in: Capsule())
                    }
                }
            }

            if !hasSnapshot {
                Text("加载完成后，可在这里查看当天训练。")
                    .font(Theme.Font.l4)
                    .foregroundStyle(Theme.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !rows.isEmpty {
                selectedDayRows(rows, maxRows: maxRows)
            } else {
                Text(emptySelectedDayText)
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
        .cardStyle(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.lg)
        .paperShadow(.lg, cornerRadius: Theme.Radius.lg)
    }

    @ViewBuilder
    private func selectedDayRows(_ rows: [Row], maxRows: Int) -> some View {
        if rows.count > maxRows && dynamicTypeSize < .xxLarge {
            ScrollView {
                selectedDayRowButtons(rows)
            }
            .scrollIndicators(.hidden)
        } else {
            selectedDayRowButtons(rows)
        }
    }

    private func selectedDayRowButtons(_ rows: [Row]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(rows) { row in
                Button { onRowTap(row) } label: {
                    rowContent(row, true)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func dayCell(_ day: CalendarHistoryDayCell<Row>, height: CGFloat) -> some View {
        let selected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let trained = day.summary != nil
        let compact = height < 54
        let selectable = isSelectable(day.date)
        return Button {
            guard selectable else { return }
            Theme.Haptics.selection()
            var transaction = Transaction(animation: nil)
            // 相邻月份日期会同时重排月网格；避免按钮松手动画带着选中色块跨格移动。
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedDate = day.date
                if !calendar.isDate(day.date, equalTo: displayedMonth, toGranularity: .month) {
                    displayedMonth = monthStart(for: day.date)
                    onMonthChange(displayedMonth)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(Theme.Font.number(size: compact ? 13 : 15, weight: trained ? .bold : .semibold))
                    .foregroundStyle(dayTextColor(day, selected: selected))
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let summary = day.summary {
                    Text(daySummaryTitle(summary))
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
        .disabled(!selectable)
        .opacity(selectable ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityValue(selected ? "已选择" : "未选择")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        let nextMonth = clampedMonthStart(for: next)
        guard nextMonth != monthStart(for: displayedMonth) || delta > 0 else { return }
        displayedMonth = nextMonth
        if !calendar.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) {
            selectedDate = clampedSelectableDate(displayedMonth)
        }
        onMonthChange(displayedMonth)
    }

    private func jumpToToday() {
        Theme.Haptics.selection()
        let today = calendar.startOfDay(for: .now)
        selectedDate = clampedSelectableDate(today)
        displayedMonth = monthStart(for: selectedDate)
        onMonthChange(displayedMonth)
    }

    private func applyPickedMonth(_ pickedMonth: Date) {
        Theme.Haptics.selection()
        displayedMonth = clampedMonthStart(for: pickedMonth)
        selectedDate = clampedSelectableDate(selectedDateAfterPickingMonth(displayedMonth))
        onMonthChange(displayedMonth)
    }

    private func monthStart(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
    }

    private func clampedMonthStart(for date: Date) -> Date {
        let month = monthStart(for: date)
        guard let minimumMonthStart, month < minimumMonthStart else { return month }
        return minimumMonthStart
    }

    private func clampedSelectableDate(_ date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        guard let minimumDay, day < minimumDay else { return day }
        return minimumDay
    }

    private func isSelectable(_ date: Date) -> Bool {
        guard let minimumDay else { return true }
        return calendar.startOfDay(for: date) >= minimumDay
    }

    private func dayTextColor(_ day: CalendarHistoryDayCell<Row>, selected: Bool) -> Color {
        if !isSelectable(day.date) { return Theme.Color.muted.opacity(0.45) }
        if selected { return Theme.Color.bg }
        if !day.isInDisplayedMonth { return Theme.Color.muted }
        if day.summary != nil { return Theme.Color.fg }
        return Theme.Color.fg2
    }

    private func dayBackground(_ day: CalendarHistoryDayCell<Row>, selected: Bool) -> Color {
        if selected { return Theme.Color.action }
        if day.summary != nil { return Theme.Color.accentSoft }
        return Theme.Color.bg
    }

    private func dayBorder(_ day: CalendarHistoryDayCell<Row>, selected: Bool) -> Color {
        if selected { return Theme.Color.action }
        if day.isToday { return Theme.Color.accentSofter }
        return .clear
    }

    private func accessibilityLabel(for day: CalendarHistoryDayCell<Row>) -> String {
        let title = CalendarHistoryFormatters.day.string(from: day.date)
        guard hasSnapshot else { return "\(title)，训练记录尚未就绪" }
        if let summary = day.summary {
            return "\(title)，\(summary.rowCount) 次训练"
        }
        return "\(title)，没有训练"
    }
}

private enum CalendarHistoryFormatters {
    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
}

private struct CalendarHistoryLayoutMetrics {
    var sectionSpacing: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var dayCellHeight: CGFloat
    var drawerHeight: CGFloat
    var drawerRows: Int
}

private struct CalendarHistoryMonthArchiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let initialMonth: Date
    let yearGroups: [CalendarHistoryYearArchiveGroup]
    let calendar: Calendar
    var emptyMessage = "暂无可查看的训练月份。"
    let onPick: (Date) -> Void
    private let topID = "month-archive-top"

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetTitleHeader(title: "选择月份", background: Theme.Color.bg)
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            Color.clear.frame(height: 0).id(topID)
                            if yearGroups.isEmpty {
                                Text(emptyMessage)
                                    .font(Theme.Font.l4)
                                    .foregroundStyle(Theme.Color.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, Theme.Spacing.lg)
                                    .accessibilityIdentifier("calendar.archive.state")
                            }
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
                        .padding(.trailing, Theme.Spacing.xl + 44)
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
            Text(String(year))
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 7) {
                Button {
                    Theme.Haptics.selection()
                    withAnimation(.snappy) {
                        proxy.scrollTo(topID, anchor: .top)
                    }
                } label: {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.action)
                        .frame(width: 26, height: 26)
                        .background(Theme.Color.accentSoft, in: Circle())
                        .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
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
                            .foregroundStyle(isInitialYear(group.year) ? Theme.Color.action : Theme.Color.muted)
                            .frame(width: 26, height: 24)
                            .background(isInitialYear(group.year) ? Theme.Color.accentSoft : Theme.Color.surface, in: Capsule())
                            .overlay(Capsule().stroke(isInitialYear(group.year) ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("跳转到\(group.year)年")
                }
            }
        }
        .frame(width: 44)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func isInitialYear(_ year: Int) -> Bool {
        calendar.component(.year, from: initialMonth) == year
    }

    private func monthArchiveRow(_ item: CalendarHistoryMonthArchiveItem) -> some View {
        let selected = calendar.isDate(item.monthStart, equalTo: initialMonth, toGranularity: .month)
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
        return Button {
            onPick(item.monthStart)
            dismiss()
        } label: {
            layout {
                VStack(alignment: .leading, spacing: 7) {
                    let titleLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(spacing: 8))
                    titleLayout {
                        Text("\(calendar.component(.month, from: item.monthStart))月")
                            .font(Theme.Font.body(size: 18, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                        if !item.isLoaded {
                            Text("点按加载")
                                .font(Theme.Font.body(size: 12, weight: .bold))
                                .foregroundStyle(Theme.Color.fg2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Color.surface2, in: Capsule())
                        } else if item.trainingDayCount > 0 {
                            Text("\(item.trainingDayCount)天")
                                .font(Theme.Font.body(size: 12, weight: .bold))
                                .foregroundStyle(Theme.Color.action)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Color.accentSoft, in: Capsule())
                        }
                    }
                    monthDensityStrip(item)
                }
                if dynamicTypeSize < .xxLarge { Spacer(minLength: Theme.Spacing.sm) }
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(!item.isLoaded ? "加载" : (item.workoutCount > 0 ? "\(item.workoutCount)次" : "—"))
                            .font(Theme.Font.mono(size: 12, weight: .bold))
                            .foregroundStyle(!item.isLoaded || item.workoutCount > 0 ? Theme.Color.fg2 : Theme.Color.muted)
                        Text(!item.isLoaded ? "未加载" : (item.volumeKg > 0 ? formatTons(item.volumeKg) + "t" : "—"))
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func monthDensityStrip(_ item: CalendarHistoryMonthArchiveItem) -> some View {
        HStack(spacing: 2) {
            ForEach(1...31, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(monthDensityColor(item, day: day))
                    .frame(width: 4, height: 8)
                    .opacity(day <= daysInMonth(item.monthStart) ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthDensityColor(_ item: CalendarHistoryMonthArchiveItem, day: Int) -> Color {
        if !item.isLoaded {
            return day % 2 == 0 ? Theme.Color.surface2 : Theme.Color.accentSofter
        }
        return item.activeDayNumbers.contains(day) ? Theme.Color.accent : Theme.Color.border
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

    private func monthAccessibilityLabel(_ item: CalendarHistoryMonthArchiveItem) -> String {
        let year = calendar.component(.year, from: item.monthStart)
        let month = calendar.component(.month, from: item.monthStart)
        if !item.isLoaded {
            return "\(year)年\(month)月，尚未加载，点按加载"
        }
        if item.trainingDayCount > 0 {
            return "\(year)年\(month)月，\(item.trainingDayCount)天有训练，\(item.workoutCount)次训练"
        }
        return "\(year)年\(month)月，没有训练"
    }
}
