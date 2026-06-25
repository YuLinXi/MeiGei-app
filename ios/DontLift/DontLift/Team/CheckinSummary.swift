import Foundation

/// 训练打卡的结构化快照。客户端在打卡时上报，服务端原样存为 jsonb；
/// 队友端据此渲染「摘要 + 每组详情」，海报也复用同一份数据（design.md D8：服务端只给结构化数据）。
struct CheckinSummary: Codable, Hashable, Identifiable {
    /// 仅用于 `.sheet(item:)` 呈现；同内容稳定。
    var id: Int { hashValue }
    var title: String?
    var startedAt: Date?
    var endedAt: Date?
    var exerciseCount: Int
    var totalSets: Int
    /// 已完成组的总容量（Σ 重量×次数），kg。
    var totalVolumeKg: Double
    var exercises: [ExerciseSummary]

    struct ExerciseSummary: Codable, Hashable, Identifiable {
        var name: String
        var sets: [SetSummary]
        var id: String { name }
    }

    struct SetSummary: Codable, Hashable {
        var weightKg: Double?
        var reps: Int?
    }
}

extension CheckinSummary {
    /// 由本地训练记录构建快照（仅取已完成的组参与容量统计，全部组进详情）。
    init(workout: Workout) {
        let exs = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        var totalSets = 0
        var volume = 0.0
        let summaries: [ExerciseSummary] = exs.map { ex in
            let sets = ex.sets.sorted { $0.setIndex < $1.setIndex }
            totalSets += sets.count
            for s in sets where s.completed {
                volume += (s.weightKg ?? 0) * Double(s.reps ?? 0)
            }
            return ExerciseSummary(
                name: ex.displayExerciseName,
                sets: sets.map { SetSummary(weightKg: $0.weightKg, reps: $0.reps) })
        }
        self.init(
            title: workout.title,
            startedAt: workout.startedAt,
            endedAt: workout.endedAt,
            exerciseCount: exs.count,
            totalSets: totalSets,
            totalVolumeKg: volume,
            exercises: summaries)
    }

    /// 列表行用的一句话摘要。
    var headline: String {
        var parts = ["\(exerciseCount)个动作", "\(totalSets)组"]
        if totalVolumeKg > 0 { parts.append("\(formatKg(totalVolumeKg)) kg 容量") }
        return parts.joined(separator: " · ")
    }
}
