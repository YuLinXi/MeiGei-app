import Foundation
import SwiftUI
import Testing
import UIKit
@testable import DontLift

@MainActor
struct WorkoutPosterBackgroundTests {
    @Test func catalogContainsFiveBundledIllustrationAssets() {
        #expect(WorkoutPosterBackground.catalog == [
            .celebration,
            .energyTrail,
            .miniGym,
            .highFive,
            .equipmentWreath
        ])
        #expect(WorkoutPosterBackground.catalog.allSatisfy { UIImage(named: $0.assetName) != nil })
        #expect(Set(WorkoutPosterBackground.catalog.map(\.layoutKind)) == [
            .topCompact,
            .upperCenter,
            .centerReceipt
        ])
    }

    @Test func recommendationFollowsSemanticPriority() throws {
        let workoutId = try #require(UUID(uuidString: "019f6633-a0e0-74e0-a85f-ad7be94af459"))

        #expect(WorkoutPosterBackground.recommended(for: context(workoutId: workoutId,
                                                                  hasPersonalRecord: true,
                                                                  isFromTeamShare: true)) == .celebration)
        #expect(WorkoutPosterBackground.recommended(for: context(workoutId: workoutId,
                                                                  isFromTeamShare: true)) == .highFive)
        #expect(WorkoutPosterBackground.recommended(for: context(workoutId: workoutId,
                                                                  exerciseCount: 5)) == .miniGym)
        #expect(WorkoutPosterBackground.recommended(for: context(workoutId: workoutId,
                                                                  structuredUnitCount: 1)) == .miniGym)
        #expect(WorkoutPosterBackground.recommended(for: context(workoutId: workoutId,
                                                                  durationMinutes: 60)) == .energyTrail)
        #expect(WorkoutPosterBackground.recommended(for: context(workoutId: workoutId)) == .equipmentWreath)
    }

    @Test func richHighEffortTrainingUsesStableEnergyOrGymChoice() {
        let workoutIds = (0..<256).compactMap { value in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", value))
        }
        let firstPass = workoutIds.map {
            WorkoutPosterBackground.recommended(for: context(workoutId: $0,
                                                               durationMinutes: 60,
                                                               exerciseCount: 5))
        }
        let secondPass = workoutIds.map {
            WorkoutPosterBackground.recommended(for: context(workoutId: $0,
                                                               durationMinutes: 60,
                                                               exerciseCount: 5))
        }

        #expect(firstPass == secondPass)
        #expect(Set(firstPass) == [.energyTrail, .miniGym])
    }

    @Test func emptyChoiceAndUnknownRawValueFallBackToEquipmentWreath() throws {
        let workoutId = try #require(UUID(uuidString: "019f6633-a0e0-74e0-a85f-ad7be94af459"))

        #expect(WorkoutPosterBackground.stableChoice(for: workoutId, from: []) == .equipmentWreath)
        #expect(WorkoutPosterBackground.resolve(rawValue: "unknown") == .equipmentWreath)
        #expect(WorkoutPosterBackground.resolve(rawValue: nil) == .equipmentWreath)
    }

    @Test func posterDataDerivesRecommendationContextFromWorkout() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let shareId = try #require(UUID(uuidString: "019f6633-a0e0-74e0-a85f-ad7be94af460"))
        let workout = Workout(
            sourceShareId: shareId,
            title: "胸背训练",
            startedAt: startedAt,
            timerStartedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(75 * 60)
        )
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        exercise.sets = (0..<20).map {
            WorkoutSet(setIndex: $0, weightKg: 80, reps: 8, completed: true)
        }
        workout.exercises = [exercise]
        let record = PersonalRecord(exerciseName: "杠铃卧推",
                                    weightKg: 100,
                                    previousBestKg: 95)

        let data = WorkoutPosterData(
            workout: workout,
            personalRecords: [record],
            caloriePreferences: WorkoutCaloriePreferences(showsEstimates: false)
        )

        #expect(data.context.hasPersonalRecord)
        #expect(data.context.isFromTeamShare)
        #expect(data.context.durationMinutes == 75)
        #expect(data.context.totalVolumeKg == 12_800)
        #expect(data.context.setCount == 20)
        #expect(data.context.exerciseCount == 1)
        #expect(data.context.structuredUnitCount == 0)
        #expect(WorkoutPosterBackground.recommended(for: data.context) == .celebration)
    }

    @Test func previewAndExportUseSameExplicitBackgroundWithoutChangingPosterData() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let workoutId = try #require(UUID(uuidString: "019f6633-a0e0-74e0-a85f-ad7be94af459"))
        let workout = Workout(
            localId: workoutId,
            title: "胸背训练",
            startedAt: startedAt,
            timerStartedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(3_600)
        )
        let exercise = WorkoutExercise(exerciseName: "杠铃卧推", orderIndex: 0)
        exercise.sets = [WorkoutSet(setIndex: 0, weightKg: 80, reps: 8, completed: true)]
        workout.exercises = [exercise]
        let data = WorkoutPosterData(
            workout: workout,
            caloriePreferences: WorkoutCaloriePreferences(showsEstimates: false)
        )
        let originalData = data

        var exportedData: [Data] = []
        for background in WorkoutPosterBackground.catalog {
            let previewRenderer = ImageRenderer(
                content: WorkoutPosterCanvas(data: data, background: background)
                    .frame(width: 360, height: 640)
            )
            previewRenderer.scale = 3

            let previewImage = try #require(previewRenderer.uiImage)
            let exportedImage = try #require(
                WorkoutPosterImageRenderer.render(data: data, background: background)
            )
            let previewPNG = try #require(previewImage.pngData())
            let exportedPNG = try #require(exportedImage.pngData())
            #expect(previewPNG == exportedPNG)
            #expect(exportedImage.cgImage?.width == 1_080)
            #expect(exportedImage.cgImage?.height == 1_920)
            exportedData.append(exportedPNG)
        }

        #expect(Set(exportedData).count == WorkoutPosterBackground.catalog.count)
        #expect(data == originalData)
    }

    private func context(
        workoutId: UUID,
        hasPersonalRecord: Bool = false,
        isFromTeamShare: Bool = false,
        durationMinutes: Int = 45,
        totalVolumeKg: Double = 5_000,
        setCount: Int = 12,
        exerciseCount: Int = 3,
        structuredUnitCount: Int = 0
    ) -> WorkoutPosterContext {
        WorkoutPosterContext(
            workoutId: workoutId,
            hasPersonalRecord: hasPersonalRecord,
            isFromTeamShare: isFromTeamShare,
            durationMinutes: durationMinutes,
            totalVolumeKg: totalVolumeKg,
            setCount: setCount,
            exerciseCount: exerciseCount,
            structuredUnitCount: structuredUnitCount
        )
    }
}
