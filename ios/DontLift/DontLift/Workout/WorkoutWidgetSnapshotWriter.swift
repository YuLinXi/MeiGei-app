import Foundation

@MainActor
enum WorkoutWidgetSnapshotWriter {
    static func update(home: HomeWorkoutSnapshot, activeWorkout: Workout?) {
        WorkoutWidgetSnapshotStore.write(
            WorkoutWidgetSnapshot(
                generatedAt: .now,
                todayCompletedWorkoutCount: home.todayCompletedWorkoutCount,
                currentTrainingStreakDays: home.currentTrainingStreakDays,
                weekStats: .init(
                    volumeKg: home.currentWeekStats.volumeKg,
                    sessionCount: home.currentWeekStats.sessionCount,
                    setCount: home.currentWeekStats.setCount,
                    repCount: home.currentWeekStats.repCount
                ),
                weekDays: home.weekTrainingDays.map { day in
                    .init(
                        date: day.date,
                        label: weekdayLabel(day.weekdayIndex),
                        sessionCount: day.sessionCount,
                        isToday: day.isToday
                    )
                },
                recentWorkout: home.weekWorkouts.first.map { workout in
                    .init(
                        title: workout.title,
                        startedAt: workout.startedAt,
                        setCount: workout.setCount,
                        volumeKg: workout.volumeKg
                    )
                },
                activeWorkout: activeWorkout.map { workout in
                    .init(
                        title: workout.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "训练",
                        startedAt: workout.startedAt,
                        timerStartedAt: workout.timerStartedAt
                    )
                }
            )
        )
    }

    private static func weekdayLabel(_ index: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "日"][min(max(index, 0), 6)]
    }
}
