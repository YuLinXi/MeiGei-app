import Foundation

enum WorkoutCalorieIntensity: Equatable {
    case low
    case moderate
    case high

    var met: Double {
        switch self {
        case .low: return 3.5
        case .moderate: return 4.5
        case .high: return 5.8
        }
    }

    var displayName: String {
        switch self {
        case .low: return "低强度"
        case .moderate: return "常规强度"
        case .high: return "高强度"
        }
    }
}

struct WorkoutCalorieEstimate: Equatable {
    var kcal: Int
    var intensity: WorkoutCalorieIntensity

    var valueText: String { "约 \(kcal)" }
    var fullText: String { "\(valueText) kcal · \(intensity.displayName)" }
}

struct WorkoutCaloriePreferences: Equatable {
    static let minBodyWeightKg = 30.0
    static let maxBodyWeightKg = 250.0
    static let defaultBodyWeightKg = 70.0

    private static let showsEstimatesKey = "dontlift.workout.calorie.showsEstimates"
    private static let bodyWeightKgKey = "dontlift.workout.calorie.bodyWeightKg"

    var showsEstimates: Bool = true
    var bodyWeightKg: Double?

    init(showsEstimates: Bool = true, bodyWeightKg: Double? = nil) {
        self.showsEstimates = showsEstimates
        self.bodyWeightKg = Self.normalizedBodyWeight(bodyWeightKg)
    }

    static func current(defaults: UserDefaults = .standard) -> WorkoutCaloriePreferences {
        let shows = (defaults.object(forKey: showsEstimatesKey) as? Bool) ?? true
        let storedWeight = defaults.object(forKey: bodyWeightKgKey) as? Double
        return WorkoutCaloriePreferences(showsEstimates: shows, bodyWeightKg: storedWeight)
    }

    static func setShowsEstimates(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: showsEstimatesKey)
    }

    static func setBodyWeightKg(_ value: Double?, defaults: UserDefaults = .standard) {
        guard let normalized = normalizedBodyWeight(value) else {
            defaults.removeObject(forKey: bodyWeightKgKey)
            return
        }
        defaults.set(normalized, forKey: bodyWeightKgKey)
    }

    static func normalizedBodyWeight(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        guard value >= minBodyWeightKg, value <= maxBodyWeightKg else { return nil }
        return value
    }
}

enum WorkoutCalorieEstimator {
    static func estimate(
        durationSeconds: TimeInterval,
        bodyWeightKg: Double?,
        completedSetCount: Int,
        containsSuperset: Bool
    ) -> WorkoutCalorieEstimate? {
        guard durationSeconds > 0 else { return nil }
        guard let bodyWeightKg = WorkoutCaloriePreferences.normalizedBodyWeight(bodyWeightKg) else { return nil }

        let durationMinutes = durationSeconds / 60
        let intensity = intensity(durationMinutes: durationMinutes,
                                  completedSetCount: completedSetCount,
                                  containsSuperset: containsSuperset)
        let kcal = intensity.met * 3.5 * bodyWeightKg / 200 * durationMinutes
        return WorkoutCalorieEstimate(kcal: max(1, Int(kcal.rounded())), intensity: intensity)
    }

    static func estimate(
        workout: Workout,
        preferences: WorkoutCaloriePreferences = .current()
    ) -> WorkoutCalorieEstimate? {
        guard preferences.showsEstimates, let endedAt = workout.endedAt else { return nil }
        let startedAt = workout.timerStartedAt ?? workout.startedAt
        return estimate(durationSeconds: endedAt.timeIntervalSince(startedAt),
                        bodyWeightKg: preferences.bodyWeightKg,
                        completedSetCount: workout.completedStatEntryCount,
                        containsSuperset: workout.trainingUnits.contains { $0.kind == .superset })
    }

    static func intensity(
        durationMinutes: Double,
        completedSetCount: Int,
        containsSuperset: Bool
    ) -> WorkoutCalorieIntensity {
        guard durationMinutes > 0 else { return .moderate }
        if containsSuperset { return .high }

        let setDensity = Double(max(0, completedSetCount)) / durationMinutes
        if setDensity >= 0.35 { return .high }
        if durationMinutes >= 30, setDensity < 0.12 { return .low }
        return .moderate
    }
}
