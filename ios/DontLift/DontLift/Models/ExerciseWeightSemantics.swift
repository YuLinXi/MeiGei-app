import Foundation

/// 固定动作规则；不按名称猜测，也不改变保存的公斤数。
nonisolated enum ExerciseWeightSemantics {
    static func isAssisted(_ code: String?) -> Bool { code == "ASSISTED_PULL_UP" }

    static let assistanceHint = "此动作记录辅助重量，辅助越小，难度越大。"

    static func volume(weight: Double?, reps: Int?, assisted: Bool) -> Double {
        assisted ? 0 : (weight ?? 0) * Double(reps ?? 0)
    }

    static func isBetter(_ weight: Double, than other: Double, assisted: Bool) -> Bool {
        assisted ? weight < other : weight > other
    }

    struct Performance: Equatable, Sendable {
        let weight: Double
        let reps: Int

        var isValid: Bool { weight.isFinite && weight >= 0 && reps > 0 }
    }

    /// 必须改善一条旧成绩，同时不能被另一条旧成绩覆盖；同场数据不进入 prior。
    static func isAssistanceBreakthrough(_ current: Performance, prior: [Performance]) -> Bool {
        guard current.isValid else { return false }
        let valid = prior.filter(\.isValid)
        return valid.contains { $0.weight > current.weight && $0.reps <= current.reps }
            && !valid.contains { $0.weight <= current.weight && $0.reps >= current.reps }
    }
}

extension BuiltinExercise {
    var isAssistedWeight: Bool { ExerciseWeightSemantics.isAssisted(code) }
}

@MainActor extension WorkoutExercise {
    var isAssistedWeight: Bool { ExerciseWeightSemantics.isAssisted(builtinExerciseCode) }

    var assistancePerformances: [ExerciseWeightSemantics.Performance] {
        sets.flatMap(\.statEntries).compactMap { entry in
            guard let weight = entry.weightKg, let reps = entry.reps else { return nil }
            let value = ExerciseWeightSemantics.Performance(weight: weight, reps: reps)
            return value.isValid ? value : nil
        }
    }
}
