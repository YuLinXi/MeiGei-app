import SwiftUI

// MARK: - 3.10 PR 自动识别与庆祝

/// 一条个人记录：由原始训练记录重算得出，不持久化（design.md Non-Goals）。
struct PersonalRecord: Identifiable {
    let exerciseName: String
    let weightKg: Double
    /// 此前历史最大重量；nil 表示该动作首次有重量记录。
    let previousBestKg: Double?
    var id: String { exerciseName }
}

/// 比较本次训练各动作的最大重量与历史最大值，识别新 PR。
/// - Parameters:
///   - workout: 刚完成的训练。
///   - history: 用于比较的历史训练（应排除本次；只传已完成、未删除的）。
func detectPersonalRecords(in workout: Workout, history: [Workout]) -> [PersonalRecord] {
    // 历史各动作最大重量。
    var bestByKey: [String: Double] = [:]
    for w in history {
        for ex in w.exercises {
            guard let m = ex.sets.compactMap(\.weightKg).max() else { continue }
            bestByKey[ex.historyKey] = max(bestByKey[ex.historyKey] ?? m, m)
        }
    }
    var seen = Set<String>()
    var prs: [PersonalRecord] = []
    for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
        guard let sessionMax = ex.sets.compactMap(\.weightKg).max() else { continue }
        let key = ex.historyKey
        guard !seen.contains(key) else { continue }
        let prior = bestByKey[key]
        if prior == nil || sessionMax > prior! {
            prs.append(PersonalRecord(exerciseName: ex.exerciseName, weightKg: sessionMax, previousBestKg: prior))
            seen.insert(key)
        }
    }
    return prs
}

/// 庆祝弹窗：训练完成识别到新 PR 时展示。
struct PRCelebrationSheet: View {
    let records: [PersonalRecord]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("🎉").font(.system(size: 64))
            Text(records.count == 1 ? "新纪录！" : "\(records.count) 项新纪录！")
                .font(.title.bold())
            VStack(spacing: 12) {
                ForEach(records) { pr in
                    HStack {
                        Text(pr.exerciseName).font(.headline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(formatKg(pr.weightKg)) kg").font(.headline).foregroundStyle(.tint)
                            if let prev = pr.previousBestKg {
                                Text("旧 \(formatKg(prev)) kg").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("首次记录").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("太棒了").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
