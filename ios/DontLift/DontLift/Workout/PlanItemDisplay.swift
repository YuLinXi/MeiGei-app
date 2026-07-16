import Foundation

struct PlanItemGroupValue: Equatable, Identifiable {
    let position: Int
    let weightKg: Double?
    let reps: Int?

    var id: Int { position }
}

struct PlanItemGroupDisplay: Equatable, Identifiable {
    enum Kind: Equatable {
        case warmup
        case working
        case drop
    }

    let position: Int
    let ordinal: Int
    let kind: Kind
    let values: [PlanItemGroupValue]

    var id: Int { position }

    var title: String {
        switch kind {
        case .warmup: "热身组 \(ordinal)"
        case .working: "正式组 \(ordinal)"
        case .drop: "递减组 \(ordinal)"
        }
    }
}

struct PlanSupersetMemberDisplay: Equatable, Identifiable {
    let id: UUID
    let name: String
    let weightKg: Double?
    let reps: Int?
}

/// 计划详情专用的纯展示派生；不持久化、不标脏，也不改变开始训练规则。
enum PlanItemDisplay {
    static func compactSummary(for item: PlanItem) -> String {
        if item.isSuperset {
            return "\(item.supersetRounds) 轮 · \(item.orderedSupersetMembers.count) 动作"
        }

        let groups = planGroups(for: item)
        let formal = groups.filter { $0.kind != .warmup }
        guard !formal.isEmpty else { return "未设置组次" }

        if item.isDropSet {
            let segmentCounts = Set(formal.map(\.values.count))
            if segmentCounts.count == 1, let count = segmentCounts.first, count > 0 {
                return "\(formal.count) 组 · 每组 \(count) 段"
            }
            return segmentCounts.isEmpty ? "\(formal.count) 组" : "\(formal.count) 组 · 段数不一"
        }

        let reps = formal.flatMap(\.values).map(\.reps)
        let configuredReps = Set(reps.compactMap { $0 })
        if configuredReps.count == 1,
           reps.allSatisfy({ $0 != nil }),
           let value = configuredReps.first {
            return "\(formal.count) 组 × \(value) 次"
        }
        if configuredReps.isEmpty { return "\(formal.count) 组" }
        return "\(formal.count) 组 · 次数不一"
    }

    static func planGroups(for item: PlanItem) -> [PlanItemGroupDisplay] {
        groups(from: PlanPrefill.plannedSets(for: item))
    }

    static func groups(from sets: [WorkoutSet]) -> [PlanItemGroupDisplay] {
        var warmupOrdinal = 0
        var formalOrdinal = 0

        return sets.sorted { $0.setIndex < $1.setIndex }.enumerated().map { position, set in
            let kind: PlanItemGroupDisplay.Kind
            let ordinal: Int
            if set.isDropSet {
                formalOrdinal += 1
                kind = .drop
                ordinal = formalOrdinal
            } else if set.isWarmupEffective {
                warmupOrdinal += 1
                kind = .warmup
                ordinal = warmupOrdinal
            } else {
                formalOrdinal += 1
                kind = .working
                ordinal = formalOrdinal
            }

            let values: [PlanItemGroupValue]
            if set.isDropSet {
                values = set.sortedSegments.enumerated().map { segmentPosition, segment in
                    PlanItemGroupValue(position: segmentPosition,
                                       weightKg: segment.weightKg,
                                       reps: segment.reps)
                }
            } else {
                values = [PlanItemGroupValue(position: 0,
                                             weightKg: set.weightKg,
                                             reps: set.reps)]
            }
            return PlanItemGroupDisplay(position: position,
                                        ordinal: ordinal,
                                        kind: kind,
                                        values: values)
        }
    }

    static func supersetMembers(for item: PlanItem) -> [PlanSupersetMemberDisplay] {
        item.orderedSupersetMembers.map {
            PlanSupersetMemberDisplay(id: $0.memberId,
                                      name: $0.displayExerciseName,
                                      weightKg: $0.suggestedWeightKg,
                                      reps: $0.suggestedReps)
        }
    }
}
