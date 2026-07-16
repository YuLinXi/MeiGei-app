import Foundation
import Testing
@testable import DontLift

struct WorkoutWidgetSnapshotTests {
    @Test func activeWorkoutUsesLiveDeepLink() {
        var snapshot = WorkoutWidgetSnapshot.empty
        snapshot.activeWorkout = .init(title: "推日", startedAt: .now, timerStartedAt: .now)

        #expect(snapshot.destinationURL.absoluteString == "dontlift://workout/live")
        #expect(snapshot.hasAnyWorkoutSignal)
    }

    @Test func snapshotRoundTripsThroughJSON() throws {
        let snapshot = WorkoutWidgetSnapshot(
            generatedAt: .now,
            todayCompletedWorkoutCount: 1,
            currentTrainingStreakDays: 3,
            weekStats: .init(volumeKg: 1200, sessionCount: 2, setCount: 8, repCount: 60),
            weekDays: [.init(date: .now, label: "一", sessionCount: 1, isToday: true)],
            recentWorkout: .init(title: "腿日", startedAt: .now, setCount: 4, volumeKg: 1200),
            activeWorkout: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: data)

        #expect(decoded.weekStats.sessionCount == 2)
        #expect(decoded.recentWorkout?.title == "腿日")
        #expect(decoded.destinationURL.absoluteString == "dontlift://workout")
    }

    @Test func staleFridaySnapshotMovesTodayHighlightToSaturday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6)))
        let friday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 23, minute: 50)))
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 11, hour: 0, minute: 1)))
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        let days = try labels.enumerated().map { index, label in
            let date = try #require(calendar.date(byAdding: .day, value: index, to: monday))
            return WorkoutWidgetSnapshot.Day(
                date: date,
                label: label,
                sessionCount: index == 4 ? 1 : 0,
                isToday: index == 4
            )
        }
        let snapshot = WorkoutWidgetSnapshot(
            generatedAt: friday,
            todayCompletedWorkoutCount: 1,
            currentTrainingStreakDays: 3,
            weekStats: .init(volumeKg: 1200, sessionCount: 1, setCount: 4, repCount: 40),
            weekDays: days,
            recentWorkout: nil,
            activeWorkout: nil
        )

        let normalized = snapshot.normalized(for: saturday, calendar: calendar)

        #expect(normalized.weekDays[4].isToday == false)
        #expect(normalized.weekDays[5].isToday)
        #expect(normalized.todayCompletedWorkoutCount == 0)
        #expect(normalized.currentTrainingStreakDays == 0)
        #expect(normalized.weekStats == snapshot.weekStats)

        let nextMonday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
        let nextWeek = snapshot.normalized(for: nextMonday, calendar: calendar)
        #expect(nextWeek.weekDays.first?.isToday == true)
        #expect(nextWeek.weekDays.allSatisfy { $0.sessionCount == 0 })
        #expect(nextWeek.todayCompletedWorkoutCount == 0)
        #expect(nextWeek.weekStats.sessionCount == 0)
        #expect(nextWeek.recentWorkout == nil)
    }
}
