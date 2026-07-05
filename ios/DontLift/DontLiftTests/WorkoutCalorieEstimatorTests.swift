import Foundation
import Testing
@testable import DontLift

@MainActor
struct WorkoutCalorieEstimatorTests {
    @Test func moderateEstimateUsesMetFormula() throws {
        let estimate = try #require(WorkoutCalorieEstimator.estimate(
            durationSeconds: 60 * 60,
            bodyWeightKg: 70,
            completedSetCount: 12,
            containsSuperset: false
        ))

        #expect(estimate.intensity == .moderate)
        #expect(estimate.kcal == 331)
        #expect(estimate.fullText == "约 331 kcal · 常规强度")
    }

    @Test func highDensityEstimateUsesHighIntensity() throws {
        let estimate = try #require(WorkoutCalorieEstimator.estimate(
            durationSeconds: 60 * 60,
            bodyWeightKg: 70,
            completedSetCount: 24,
            containsSuperset: false
        ))

        #expect(estimate.intensity == .high)
        #expect(estimate.kcal == 426)
    }

    @Test func lowDensityEstimateUsesLowIntensity() throws {
        let estimate = try #require(WorkoutCalorieEstimator.estimate(
            durationSeconds: 60 * 60,
            bodyWeightKg: 70,
            completedSetCount: 4,
            containsSuperset: false
        ))

        #expect(estimate.intensity == .low)
        #expect(estimate.kcal == 257)
    }

    @Test func supersetEstimateUsesHighIntensity() throws {
        let estimate = try #require(WorkoutCalorieEstimator.estimate(
            durationSeconds: 45 * 60,
            bodyWeightKg: 70,
            completedSetCount: 6,
            containsSuperset: true
        ))

        #expect(estimate.intensity == .high)
    }

    @Test func missingBodyWeightReturnsNil() {
        let estimate = WorkoutCalorieEstimator.estimate(
            durationSeconds: 60 * 60,
            bodyWeightKg: nil,
            completedSetCount: 12,
            containsSuperset: false
        )

        #expect(estimate == nil)
    }

    @Test func invalidDurationReturnsNil() {
        let estimate = WorkoutCalorieEstimator.estimate(
            durationSeconds: 0,
            bodyWeightKg: 70,
            completedSetCount: 12,
            containsSuperset: false
        )

        #expect(estimate == nil)
    }

    @Test func disabledPreferencesHideWorkoutEstimate() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = Workout(startedAt: startedAt,
                              timerStartedAt: startedAt,
                              endedAt: startedAt.addingTimeInterval(60 * 60))

        let estimate = WorkoutCalorieEstimator.estimate(
            workout: workout,
            preferences: WorkoutCaloriePreferences(showsEstimates: false, bodyWeightKg: 70)
        )

        #expect(estimate == nil)
    }
}
