import SwiftUI

/// 训练结算与生涯成就庆祝弹窗 App 级调度中心（注入根环境）
@Observable
final class BadgeCelebrationCenter {
    /// 结算增量达成的新徽章（非 nil 触发结算高光弹窗）
    var incrementalCandidates: [BadgeGrantCandidate]?
    var workoutSummary: String = ""

    /// 存量老用户生涯回顾弹窗数据（非 nil 且无活跃训练时触发）
    var careerReviewGrants: [BadgeGrant]?
    var careerReviewTotalTonnage: Double = 0
    var careerReviewWorkoutCount: Int = 0
    var careerReviewBig3: (bench: Double?, squat: Double?, deadlift: Double?) = (nil, nil, nil)

    /// 唤起训练结算成就弹窗
    func presentIncremental(_ candidates: [BadgeGrantCandidate], workoutSummary: String) {
        guard !candidates.isEmpty else { return }
        self.workoutSummary = workoutSummary
        self.incrementalCandidates = candidates
    }

    /// 唤起老用户生涯成就回顾弹窗
    func presentCareerReview(
        grants: [BadgeGrant],
        totalTonnage: Double,
        workoutCount: Int,
        big3: (bench: Double?, squat: Double?, deadlift: Double?)
    ) {
        guard !grants.isEmpty else { return }
        self.careerReviewTotalTonnage = totalTonnage
        self.careerReviewWorkoutCount = workoutCount
        self.careerReviewBig3 = big3
        self.careerReviewGrants = grants
    }

    /// 关闭生涯回顾并清空
    func dismissCareerReview() {
        self.careerReviewGrants = nil
    }

    /// 关闭结算高光庆祝并清空
    func dismissIncremental() {
        self.incrementalCandidates = nil
    }
}
