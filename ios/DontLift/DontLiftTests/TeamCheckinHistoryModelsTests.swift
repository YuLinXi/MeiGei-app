import Foundation
import Testing
@testable import DontLift

struct TeamCheckinHistoryModelsTests {
    private var calendar: Calendar { .currentMondayFirst }

    private func month(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private func checkin(day: String, sets: Int = 3, volume: Double = 1200) -> TeamCheckinDTO {
        let summary = CheckinSummary(
            title: "训练",
            startedAt: nil,
            endedAt: nil,
            exerciseCount: 2,
            totalSets: sets,
            totalVolumeKg: volume,
            exercises: []
        )
        let data = try! JSONCoding.encoder.encode(summary)
        let summaryString = String(data: data, encoding: .utf8)!
        return TeamCheckinDTO(
            id: UUID(),
            teamId: UUID(),
            userId: UUID(),
            workoutId: UUID(),
            checkinDate: day,
            summary: summaryString,
            createdAt: nil
        )
    }

    @Test func archiveIncludesUnloadedCreatedMonth() {
        let june = month(2026, 6)
        let july = month(2026, 7)
        let loadedMonths = [
            july: TeamCheckinHistoryMonthData(monthStart: july, checkins: [], reactions: [])
        ]

        let groups = TeamCheckinHistoryModels.archiveGroups(
            currentMonth: july,
            earliestSelectableMonth: june,
            loadedMonths: loadedMonths,
            memberName: { _ in "队友" },
            calendar: calendar
        )
        let items = groups.flatMap(\.months)

        #expect(items.map(\.monthStart) == [july, june])
        #expect(items.first { $0.monthStart == june }?.isLoaded == false)
        #expect(items.first { $0.monthStart == july }?.isLoaded == true)
    }

    @Test func loadedMonthSummarizesRealCheckins() {
        let june = month(2026, 6)
        let loadedMonths = [
            june: TeamCheckinHistoryMonthData(
                monthStart: june,
                checkins: [
                    checkin(day: "2026-06-02", sets: 3, volume: 1000),
                    checkin(day: "2026-06-18", sets: 4, volume: 1500)
                ],
                reactions: []
            )
        ]

        let item = TeamCheckinHistoryModels.archiveGroups(
            currentMonth: june,
            earliestSelectableMonth: june,
            loadedMonths: loadedMonths,
            memberName: { _ in "队友" },
            calendar: calendar
        )
        .flatMap(\.months)
        .first!

        #expect(item.isLoaded)
        #expect(item.trainingDayCount == 2)
        #expect(item.workoutCount == 2)
        #expect(item.setCount == 7)
        #expect(item.volumeKg == 2500)
        #expect(item.activeDayNumbers == [2, 18])
    }

    @Test func loadedEmptyMonthDiffersFromUnloadedMonth() {
        let june = month(2026, 6)
        let july = month(2026, 7)
        let loadedMonths = [
            june: TeamCheckinHistoryMonthData(monthStart: june, checkins: [], reactions: [])
        ]

        let items = TeamCheckinHistoryModels.archiveGroups(
            currentMonth: july,
            earliestSelectableMonth: june,
            loadedMonths: loadedMonths,
            memberName: { _ in "队友" },
            calendar: calendar
        )
        .flatMap(\.months)

        let juneItem = items.first { $0.monthStart == june }
        let julyItem = items.first { $0.monthStart == july }

        #expect(juneItem?.isLoaded == true)
        #expect(juneItem?.workoutCount == 0)
        #expect(julyItem?.isLoaded == false)
    }
}
