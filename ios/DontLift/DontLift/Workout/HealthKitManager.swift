import Foundation
import HealthKit

// MARK: - 3.11 HealthKit 写入

/// 将完成的训练作为力量训练 Workout 写入「健康」App（需用户授权）。
/// 仅写入；不读取健康数据（MVP 范围）。授权失败/不可用时静默跳过，绝不阻断训练保存。
@MainActor
@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 是否已授权写入 Workout（供「我的」页 HealthKit 行展示连接态）。
    var isAuthorized: Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// 请求写入 Workout 的授权。可重复调用（已授权时系统直接回调）。
    func requestAuthorization() async {
        guard isAvailable else { return }
        let types: Set<HKSampleType> = [HKObjectType.workoutType()]
        try? await store.requestAuthorization(toShare: types, read: [])
    }

    /// 写入一条力量训练 Workout，时长由 start/end 决定。
    /// 失败不抛给调用方——HealthKit 是增强项，本地训练记录才是真相来源。
    func saveStrengthWorkout(start: Date, end: Date) async {
        guard isAvailable, start < end else { return }
        // 未授权写入时直接返回，避免无谓的 builder 流程。
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // 忽略：写入失败不影响本地训练。
        }
    }
}
