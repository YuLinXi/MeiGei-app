import Foundation

struct TeamCheckinHistoryRow: Identifiable, Equatable, Hashable {
    var checkin: TeamCheckinDTO
    var memberName: String
    var summary: CheckinSummary?
    var date: Date

    var id: UUID { checkin.id }

    var title: String {
        guard let summary else { return "训练快照不可用" }
        if let title = summary.title, !title.isEmpty { return title }
        return "训练"
    }

    var setCount: Int { summary?.totalSets ?? 0 }
    var exerciseCount: Int { summary?.exerciseCount ?? 0 }
    var volumeKg: Double { summary?.totalVolumeKg ?? 0 }
}

struct TeamCheckinHistoryMonthData: Equatable, Hashable {
    var monthStart: Date
    var checkins: [TeamCheckinDTO]
    var reactions: [CheckinReactionDTO]
}

enum TeamCheckinHistoryModels {
    static func monthSnapshot(
        monthStart: Date,
        cachedMonth: TeamCheckinHistoryMonthData?,
        memberName: (UUID) -> String,
        calendar: Calendar
    ) -> CalendarHistoryMonthSnapshot<TeamCheckinHistoryRow> {
        let rows = (cachedMonth?.checkins ?? []).compactMap { checkin -> TeamCheckinHistoryRow? in
            guard let date = dateOnlyFormatter.date(from: checkin.checkinDate) else { return nil }
            return TeamCheckinHistoryRow(
                checkin: checkin,
                memberName: memberName(checkin.userId),
                summary: checkin.decodedSummary,
                date: calendar.startOfDay(for: date)
            )
        }
        let grouped = Dictionary(grouping: rows, by: \.date)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let today = calendar.startOfDay(for: .now)
        let days = (0..<42).compactMap { offset -> CalendarHistoryDayCell<TeamCheckinHistoryRow>? in
            guard let rawDay = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let day = calendar.startOfDay(for: rawDay)
            let dayRows = grouped[day] ?? []
            let summary = dayRows.isEmpty ? nil : CalendarHistoryDaySummary(
                date: day,
                rows: dayRows,
                setCount: dayRows.reduce(0) { $0 + $1.setCount },
                volumeKg: dayRows.reduce(0) { $0 + $1.volumeKg }
            )
            return CalendarHistoryDayCell(
                date: day,
                isInDisplayedMonth: calendar.isDate(day, equalTo: monthStart, toGranularity: .month),
                isToday: calendar.isDate(day, inSameDayAs: today),
                summary: summary
            )
        }
        let inMonthSummaries = days
            .filter(\.isInDisplayedMonth)
            .compactMap(\.summary)
        return CalendarHistoryMonthSnapshot(
            monthStart: monthStart,
            days: days,
            rowCount: inMonthSummaries.reduce(0) { $0 + $1.rowCount },
            setCount: inMonthSummaries.reduce(0) { $0 + $1.setCount },
            volumeKg: inMonthSummaries.reduce(0) { $0 + $1.volumeKg }
        )
    }

    static func archiveGroups(
        currentMonth: Date,
        loadedMonths: [Date: TeamCheckinHistoryMonthData],
        memberName: (UUID) -> String,
        calendar: Calendar
    ) -> [CalendarHistoryYearArchiveGroup] {
        let earliest = loadedMonths.keys.min() ?? currentMonth
        var items: [CalendarHistoryMonthArchiveItem] = []
        var cursor = currentMonth
        while cursor >= earliest {
            let snapshot = monthSnapshot(
                monthStart: cursor,
                cachedMonth: loadedMonths[cursor],
                memberName: memberName,
                calendar: calendar
            )
            let activeDays = Set(snapshot.days.compactMap { day -> Int? in
                guard day.isInDisplayedMonth, day.summary != nil else { return nil }
                return calendar.component(.day, from: day.date)
            })
            items.append(CalendarHistoryMonthArchiveItem(
                monthStart: cursor,
                trainingDayCount: activeDays.count,
                workoutCount: snapshot.rowCount,
                setCount: snapshot.setCount,
                volumeKg: snapshot.volumeKg,
                activeDayNumbers: activeDays
            ))
            guard let previous = calendar.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = previous
        }
        let grouped = Dictionary(grouping: items) { item in
            calendar.component(.year, from: item.monthStart)
        }
        return grouped.keys.sorted(by: >).map { year in
            CalendarHistoryYearArchiveGroup(
                year: year,
                months: grouped[year]?.sorted { $0.monthStart > $1.monthStart } ?? []
            )
        }
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
