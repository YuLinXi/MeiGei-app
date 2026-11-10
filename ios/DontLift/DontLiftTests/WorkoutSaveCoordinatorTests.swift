import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutSaveCoordinatorTests {
    private struct InjectedSaveError: Error {}

    @Test func rapidInputsCoalesceAndPersistTheLatestValues() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let set = WorkoutSet(setIndex: 0)
        let workout = Workout(exercises: [WorkoutExercise(exerciseName: "卧推", orderIndex: 0, sets: [set])])
        context.insert(workout)
        try context.save()
        let coordinator = WorkoutSaveCoordinator()
        var saves = 0
        var snapshots = 0
        let persist: (ModelContext) throws -> Void = { context in saves += 1; try context.save() }
        set.weightKg = 6
        coordinator.schedule(in: context, onSaved: { snapshots += 1 }, persist: persist)
        try await Task.sleep(for: .milliseconds(150))
        #expect(saves == 0 && snapshots == 0)
        set.weightKg = 65
        set.reps = 8
        set.completed = true
        coordinator.schedule(in: context, onSaved: { snapshots += 1 }, persist: persist)
        try await Task.sleep(for: .milliseconds(500))
        #expect(saves == 1 && snapshots == 1)
        #expect(!coordinator.hasFailure)
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(reread.weightKg == 65 && reread.reps == 8 && reread.completed)
    }

    @Test func failedSaveRetainsInputAndImmediateRetryCancelsDebounce() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let set = WorkoutSet(setIndex: 0, weightKg: 60, reps: 8)
        context.insert(set)
        try context.save()
        let coordinator = WorkoutSaveCoordinator()
        var snapshots = 0
        var saves = 0
        set.weightKg = 72.5
        coordinator.schedule(in: context, onSaved: { snapshots += 1 },
                             persist: { _ in throw InjectedSaveError() })
        try await Task.sleep(for: .milliseconds(500))
        #expect(coordinator.hasFailure)
        #expect(set.weightKg == 72.5 && snapshots == 0)
        set.reps = 6
        coordinator.schedule(in: context, onSaved: { snapshots += 1 },
                             persist: { _ in saves += 1 })
        #expect(coordinator.flush(in: context, onSaved: { snapshots += 1 }, persist: {
            saves += 1
            try $0.save()
        }))
        try await Task.sleep(for: .milliseconds(400))
        #expect(!coordinator.hasFailure)
        #expect(saves == 1 && snapshots == 1)
        let reread = try #require(try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(reread.weightKg == 72.5 && reread.reps == 6)
    }
}
