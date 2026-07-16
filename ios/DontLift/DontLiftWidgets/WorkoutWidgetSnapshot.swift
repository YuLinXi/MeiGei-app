import Foundation
import WidgetKit

/// 训练摘要 Widget 的最小共享快照。
///
/// 这是主 App 写给 Widget extension 的派生展示缓存，不是同步真相源。
struct WorkoutWidgetSnapshot: Codable, Equatable {
    static let widgetKind = "WorkoutSummaryWidget"
    static let suiteName = "group.com.yulinxi.app.DontLift"
    static let defaultURL = URL(string: "dontlift://workout")!
    static let liveURL = URL(string: "dontlift://workout/live")!

    struct WeekStats: Codable, Equatable {
        var volumeKg: Double
        var sessionCount: Int
        var setCount: Int
        var repCount: Int
    }

    struct Day: Codable, Equatable, Identifiable {
        var date: Date
        var label: String
        var sessionCount: Int
        var isToday: Bool

        var id: Date { date }
        var isCompleted: Bool { sessionCount > 0 }
    }

    struct RecentWorkout: Codable, Equatable {
        var title: String
        var startedAt: Date
        var setCount: Int
        var volumeKg: Double
    }

    struct ActiveWorkout: Codable, Equatable {
        var title: String
        var startedAt: Date
        var timerStartedAt: Date?
    }

    var generatedAt: Date
    var todayCompletedWorkoutCount: Int
    var currentTrainingStreakDays: Int
    var weekStats: WeekStats
    var weekDays: [Day]
    var recentWorkout: RecentWorkout?
    var activeWorkout: ActiveWorkout?

    static let empty = WorkoutWidgetSnapshot(
        generatedAt: .distantPast,
        todayCompletedWorkoutCount: 0,
        currentTrainingStreakDays: 0,
        weekStats: WeekStats(volumeKg: 0, sessionCount: 0, setCount: 0, repCount: 0),
        weekDays: [],
        recentWorkout: nil,
        activeWorkout: nil
    )

    var destinationURL: URL {
        activeWorkout == nil ? Self.defaultURL : Self.liveURL
    }

    var hasAnyWorkoutSignal: Bool {
        weekStats.sessionCount > 0 || todayCompletedWorkoutCount > 0 || activeWorkout != nil
    }

    func normalized(for date: Date, calendar: Calendar = .current) -> WorkoutWidgetSnapshot {
        var snapshot = self

        if let todayIndex = weekDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            snapshot.weekDays = weekDays.enumerated().map { index, day in
                var day = day
                day.isToday = index == todayIndex
                return day
            }
            snapshot.todayCompletedWorkoutCount = weekDays[todayIndex].sessionCount
            if !calendar.isDate(generatedAt, inSameDayAs: date), snapshot.todayCompletedWorkoutCount == 0 {
                snapshot.currentTrainingStreakDays = 0
            }
            return snapshot
        }

        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        let today = calendar.startOfDay(for: date)
        let daysSinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        snapshot.todayCompletedWorkoutCount = 0
        snapshot.currentTrainingStreakDays = 0
        snapshot.weekStats = WeekStats(volumeKg: 0, sessionCount: 0, setCount: 0, repCount: 0)
        snapshot.weekDays = labels.enumerated().compactMap { index, label in
            guard let day = calendar.date(byAdding: .day, value: index, to: monday) else { return nil }
            return Day(date: day, label: label, sessionCount: 0, isToday: calendar.isDate(day, inSameDayAs: today))
        }
        snapshot.recentWorkout = nil
        return snapshot
    }
}

enum WorkoutWidgetSnapshotStore {
    private static let snapshotKey = "dontlift.workout.widget.snapshot"

    static func read() -> WorkoutWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: WorkoutWidgetSnapshot.suiteName),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func write(_ snapshot: WorkoutWidgetSnapshot, reloadTimelines: Bool = true) {
        guard let defaults = UserDefaults(suiteName: WorkoutWidgetSnapshot.suiteName),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: snapshotKey)
        if reloadTimelines {
            WidgetCenter.shared.reloadTimelines(ofKind: WorkoutWidgetSnapshot.widgetKind)
        }
    }
}
