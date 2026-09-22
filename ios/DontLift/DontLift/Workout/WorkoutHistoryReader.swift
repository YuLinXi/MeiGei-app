import Foundation
import SwiftData

/// 后台 reader 连续提取持久化字段；只有这些 Sendable 值可以离开执行器。
nonisolated struct HistoryExerciseIdentity: Hashable, Sendable {
    var code: String?
    var name: String
    var customId: UUID?
    var primaryMuscle: String?
}

nonisolated struct HistoryExerciseMetadata: Sendable {
    var key: String
    var name: String
    var bucket: ExerciseCategory??

    @MainActor static func resolve(_ identity: HistoryExerciseIdentity) -> Self {
        let resolved = ExerciseLibrary.resolve(code: identity.code, name: identity.name)
        let raw = identity.primaryMuscle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = raw.flatMap { ExerciseCategory(rawValue: ExerciseCategory.collapseL1($0)) }
            ?? resolved.flatMap { ExerciseCategory(rawValue: ExerciseCategory.collapseL1($0.category)) }
        let bucket: ExerciseCategory??
        if let category { bucket = category.isAnatomical ? .some(category) : nil }
        else { bucket = .some(nil) }
        return Self(key: ExerciseLibrary.canonicalHistoryKey(code: identity.code, name: identity.name, customId: identity.customId),
                    name: ExerciseLibrary.displayName(code: identity.code, snapshotName: identity.name),
                    bucket: bucket)
    }
}

nonisolated struct HistorySet: Sendable {
    var localId: UUID
    var setIndex: Int
    var weightKg: Double?
    var reps: Int?
    var completed: Bool
    var setTypeRaw: String
    var isWarmup: Bool
    var segments: [WorkoutSetSegment]
    var isAssistedWeight: Bool

    init(_ set: WorkoutSet, assisted: Bool) {
        localId = set.localId
        setIndex = set.setIndex
        weightKg = set.weightKg
        reps = set.reps
        completed = set.completed
        setTypeRaw = set.setTypeRaw
        isWarmup = set.isWarmup
        segments = set.segments
        isAssistedWeight = assisted
    }
    var isWarmupEffective: Bool { isWarmup || setTypeRaw == "warmup" }
    var countsForStats: Bool { completed && !isWarmupEffective }
    var isDropSet: Bool { setTypeRaw == "drop" }
    var effectiveSegments: [WorkoutSetSegment] {
        segments.sorted { $0.segmentIndex < $1.segmentIndex }.filter { $0.weightKg != nil || $0.reps != nil }
    }
    var statEntries: [WorkoutSetStatEntry] {
        guard countsForStats else { return [] }
        if isDropSet {
            return effectiveSegments.map { WorkoutSetStatEntry(setId: localId, segmentId: $0.segmentId,
                weightKg: $0.weightKg, reps: $0.reps, isAssistedWeight: isAssistedWeight) }
        }
        return [WorkoutSetStatEntry(setId: localId, segmentId: nil, weightKg: weightKg, reps: reps, isAssistedWeight: isAssistedWeight)]
    }
    var summaryWeightReps: (weightKg: Double?, reps: Int?) {
        let entries = statEntries
        let top = isAssistedWeight
            ? entries.filter { $0.weightKg != nil }.min { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
            : entries.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
        if let top { return (top.weightKg, top.reps) }
        if isDropSet, let first = effectiveSegments.first { return (first.weightKg, first.reps) }
        return (weightKg, reps)
    }
}

nonisolated struct HistoryExercise: Sendable {
    var localId: UUID
    var identity: HistoryExerciseIdentity
    var orderIndex: Int
    var planItemId: UUID?
    var sets: [HistorySet]
    var metadata: HistoryExerciseMetadata?
    var historyKey: String { metadata!.key }
    var displayExerciseName: String { metadata!.name }
    var isAssistedWeight: Bool { ExerciseWeightSemantics.isAssisted(identity.code) }
    var assistancePerformances: [ExerciseWeightSemantics.Performance] {
        sets.flatMap(\.statEntries).compactMap {
            guard let weight = $0.weightKg, let reps = $0.reps else { return nil }
            let value = ExerciseWeightSemantics.Performance(weight: weight, reps: reps)
            return value.isValid ? value : nil
        }
    }
    init(_ exercise: WorkoutExercise) {
        localId = exercise.localId
        orderIndex = exercise.orderIndex
        planItemId = exercise.planItemId
        identity = HistoryExerciseIdentity(code: exercise.builtinExerciseCode, name: exercise.exerciseName,
                                           customId: exercise.customExerciseId, primaryMuscle: exercise.primaryMuscle)
        sets = exercise.sets.map { HistorySet($0, assisted: ExerciseWeightSemantics.isAssisted(exercise.builtinExerciseCode)) }
    }
}

/// 只解码历史索引所需的单元字段，不引入计划或模型引用。
nonisolated struct HistoryUnit: Decodable, Sendable {
    var kindRaw: String
    var orderIndex: Int
    var singleExerciseId: UUID?
    var superset: Superset?
    var kind: WorkoutUnitKind { WorkoutUnitKind(rawValue: kindRaw) ?? .singleExercise }
    struct Superset: Decodable, Sendable {
        var roundCount: Int
        var members: [Member]
        struct Member: Decodable, Sendable { var exerciseId: UUID }
    }
}

nonisolated struct HistoryWorkout: Sendable {
    var localId: UUID
    var planId: UUID?
    var title: String?
    var startedAt: Date
    var timerStartedAt: Date?
    var endedAt: Date?
    var deletedAt: Date?
    var syncStatusRaw: String
    var exercises: [HistoryExercise]
    var trainingUnits: [HistoryUnit]
    var isFinished: Bool { deletedAt == nil && endedAt != nil }
    var isActive: Bool { deletedAt == nil && endedAt == nil }
    var completedStatEntryCount: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.countsForStats).count } }
    func exercise(id: UUID) -> HistoryExercise? { exercises.first { $0.localId == id } }

    init(_ workout: Workout) {
        localId = workout.localId
        planId = workout.planId
        title = workout.title
        startedAt = workout.startedAt
        timerStartedAt = workout.timerStartedAt
        endedAt = workout.endedAt
        deletedAt = workout.deletedAt
        syncStatusRaw = workout.syncStatusRaw
        exercises = workout.exercises.map(HistoryExercise.init)
        let decoded = workout.unitsJSON.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([HistoryUnit].self, from: $0) } ?? []
        let ids = Set(exercises.map(\.localId))
        let valid = decoded.filter { unit in
            switch unit.kind {
            case .singleExercise, .dropSet: return unit.singleExerciseId.map { ids.contains($0) } ?? false
            case .superset: return unit.superset?.members.count == 2 && unit.superset?.members.allSatisfy { ids.contains($0.exerciseId) } == true
            }
        }
        let referenced = Set(valid.flatMap { $0.kind == .superset ? ($0.superset?.members.map(\.exerciseId) ?? []) : ($0.singleExerciseId.map { [$0] } ?? []) })
        let missing = exercises.filter { !referenced.contains($0.localId) }.sorted { $0.orderIndex < $1.orderIndex }
        trainingUnits = (valid + missing.enumerated().map { offset, exercise in
            HistoryUnit(kindRaw: "singleExercise", orderIndex: (valid.map(\.orderIndex).max() ?? -1) + offset + 1,
                        singleExerciseId: exercise.localId)
        }).sorted { $0.orderIndex < $1.orderIndex }
    }

    @MainActor static func resolved(_ workouts: [Workout]) -> [Self] {
        resolve(workouts.map(Self.init))
    }

    @MainActor static func metadata(for values: [Self]) -> [HistoryExerciseIdentity: HistoryExerciseMetadata] {
        Dictionary(uniqueKeysWithValues: Set(values.flatMap { $0.exercises.map(\.identity) }).map { ($0, HistoryExerciseMetadata.resolve($0)) })
    }

    static func applying(_ metadata: [HistoryExerciseIdentity: HistoryExerciseMetadata], to values: [Self]) -> [Self] {
        values.map { value in
            var result = value
            result.exercises = value.exercises.map { exercise in
                var result = exercise
                result.metadata = metadata[exercise.identity]
                return result
            }
            return result
        }
    }

    @MainActor private static func resolve(_ values: [Self]) -> [Self] {
        applying(metadata(for: values), to: values)
    }
}

@ModelActor
actor WorkoutHistoryReader {
    func read() throws -> [HistoryWorkout] {
        assert(!Thread.isMainThread)
        return try WorkoutPerformanceMonitor.measure("history.read.values") {
            let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.deletedAt == nil },
                                                       sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
            return try modelContext.fetch(descriptor).map(HistoryWorkout.init)
        }
    }
}
