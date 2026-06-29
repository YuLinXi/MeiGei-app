import Foundation
import Testing
@testable import DontLift

@MainActor
struct CustomExerciseDeletionTests {

    @Test func markDeletedCreatesPendingTombstone() {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let deletedAt = createdAt.addingTimeInterval(60)
        let id = UUID()
        let exercise = CustomExercise(localId: id, name: "临时动作", now: createdAt)
        exercise.serverId = id
        exercise.syncStatus = .synced

        exercise.markDeleted(now: deletedAt)

        #expect(exercise.deletedAt == deletedAt)
        #expect(exercise.updatedAt == deletedAt)
        #expect(exercise.syncStatus == .pendingDelete)
    }

    @Test func deletingCustomExerciseDoesNotRewriteExistingSnapshots() {
        let id = UUID()
        let exercise = CustomExercise(localId: id, name: "旧动作")
        let planItem = PlanItem(
            customExerciseId: id,
            exerciseName: "旧动作快照",
            primaryMuscle: "胸",
            equipmentType: "哑铃",
            orderIndex: 0
        )
        let workoutExercise = WorkoutExercise(
            customExerciseId: id,
            exerciseName: "旧训练记录",
            primaryMuscle: "胸",
            orderIndex: 0
        )

        exercise.markDeleted(now: Date(timeIntervalSince1970: 1_800_000_100))

        #expect(planItem.customExerciseId == id)
        #expect(planItem.displayExerciseName == "旧动作快照")
        #expect(workoutExercise.customExerciseId == id)
        #expect(workoutExercise.displayExerciseName == "旧训练记录")
    }
}
