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
}
