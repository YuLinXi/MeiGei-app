import Foundation
import Testing
@testable import DontLift

@MainActor
struct WorkoutPosterCalorieTests {
    @Test func posterDataIncludesCalorieEstimateWhenAvailable() throws {
        let workout = makeWorkout()

        let data = WorkoutPosterData(
            workout: workout,
            caloriePreferences: WorkoutCaloriePreferences(showsEstimates: true, bodyWeightKg: 70)
        )

        #expect(data.calorieValueText == "204")
    }

    @Test func posterDataHidesCaloriesWithoutBodyWeight() {
        let workout = makeWorkout()

        let data = WorkoutPosterData(
            workout: workout,
            caloriePreferences: WorkoutCaloriePreferences(showsEstimates: true, bodyWeightKg: nil)
        )

        #expect(data.calorieValueText == nil)
    }

    @Test func posterDataHidesCaloriesWhenDisabled() {
        let workout = makeWorkout()

        let data = WorkoutPosterData(
            workout: workout,
            caloriePreferences: WorkoutCaloriePreferences(showsEstimates: false, bodyWeightKg: 70)
        )

        #expect(data.calorieValueText == nil)
    }

    private func makeWorkout() -> Workout {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = Workout(title: "胸背训练",
                              startedAt: startedAt,
                              timerStartedAt: startedAt,
                              endedAt: startedAt.addingTimeInterval(60 * 60))
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        exercise.sets = (0..<12).map { index in
            WorkoutSet(setIndex: index, weightKg: 80, reps: 8, completed: true)
        }
        workout.exercises = [exercise]
        return workout
    }
}
