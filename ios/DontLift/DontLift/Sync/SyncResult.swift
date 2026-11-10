import Foundation

/// 最近一次同步的结果，仅用于反馈，不作为实体或增量水位的真相来源。
struct SyncResult: Equatable {
    enum Status { case success, partialFailure, failure, localSaveFailed }

    let failedDomains: [SyncDomain]
    let localSaveSucceeded: Bool

    var status: Status {
        if !localSaveSucceeded { return .localSaveFailed }
        if failedDomains.isEmpty { return .success }
        return failedDomains.count == SyncDomain.allCases.count ? .failure : .partialFailure
    }

    var summary: String {
        switch status {
        case .success: return "上次同步成功"
        case .partialFailure: return "上次部分失败"
        case .failure: return "上次同步失败"
        case .localSaveFailed: return "本地保存失败"
        }
    }

    var recoveryHint: String? {
        switch status {
        case .success: return nil
        case .partialFailure, .failure:
            let names = failedDomains.map { domain in
                switch domain {
                case .customExercises: "自定义动作"
                case .workoutPlanGroups: "计划分组"
                case .workoutPlans: "个人计划"
                case .workouts: "训练记录"
                }
            }.joined(separator: "、")
            return "\(names)尚未同步，本机已保存的记录不受影响。点按重试。"
        case .localSaveFailed:
            return "本地保存尚未完成，请点按重试。"
        }
    }
}
