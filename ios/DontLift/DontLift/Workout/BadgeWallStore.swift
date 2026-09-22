import Foundation
import SwiftData
import Observation

extension Notification.Name {
    static let badgeBodyWeightChanged = Notification.Name("dontlift.badge.bodyWeightChanged")
}

/// 会话内共享值快照；页面生命周期不再承担历史扫描。
@MainActor
@Observable
final class BadgeWallStore {
    private(set) var progress: [BadgeProgress] = []
    private(set) var sections: [BadgeCategory: [BadgeProgress]] = [:]
    private(set) var isReady = false
    private(set) var completedRefreshCount = 0
    private(set) var historyReadCount = 0
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var userId: UUID?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var needsRefresh = true
    @ObservationIgnored private var cachedWorkouts: [BadgeWorkoutSnapshot]?
    @ObservationIgnored private var isBackfilling = false
    @ObservationIgnored private let readHistory: @Sendable (ModelContainer) async throws -> [BadgeWorkoutSnapshot]

    init(readHistory: @escaping @Sendable (ModelContainer) async throws -> [BadgeWorkoutSnapshot] = { container in
        try await Task.detached(priority: .utility) {
            try await BadgeHistoryReader(modelContainer: container).readWorkouts()
        }.value
    }) {
        self.readHistory = readHistory
    }

    func configure(context: ModelContext, userId: UUID?) {
        guard self.context == nil || self.userId != userId else { ensureLoaded(); return }
        refreshTask?.cancel()
        refreshTask = nil
        revision += 1
        sessionGeneration += 1
        self.context = context
        self.userId = userId
        cachedWorkouts = nil
        progress = []
        sections = [:]
        isReady = false
        isBackfilling = false
        needsRefresh = true
        guard userId != nil else { return }
        // 冷启动只读轻量授予表；百分比准备好之前不显示虚假的零进度。
        let grants = (try? context.fetch(FetchDescriptor<BadgeGrant>())) ?? []
        publish(BadgeEngine.calculateProgress(workouts: [], grants: grants.map(BadgeEngine.grantSnapshot), currentWeight: nil))
        ensureLoaded()
    }

    func invalidate(historyChanged: Bool = true) {
        revision += 1
        needsRefresh = true
        if historyChanged { cachedWorkouts = nil }
        refreshTask?.cancel()
        ensureLoaded()
    }

    func ensureLoaded() {
        guard needsRefresh, refreshTask == nil, let context, userId != nil else { return }
        let generation = revision
        let session = sessionGeneration
        let existing = cachedWorkouts
        let container = context.container
        WorkoutPerformanceMonitor.event("badgeWall.refresh.requested")
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let workouts: [BadgeWorkoutSnapshot]
                if let existing { workouts = existing } else {
                    self.historyReadCount += 1
                    // 在 detached 中创建 ModelActor，避免执行器绑定主线程。
                    workouts = try await self.readHistory(container)
                }
                try Task.checkCancellation()
                guard self.revision == generation else { throw CancellationError() }
                if existing == nil {
                    self.isBackfilling = true
                    let scope = self.userId!.uuidString
                    await BadgeEngine.runBackfillIfNeeded(in: context, workoutSnapshots: workouts, ruleScope: scope)
                    if self.sessionGeneration == session { self.isBackfilling = false }
                    guard UserDefaults.standard.bool(forKey: "badge.assistedWeightRules.v1.\(scope)") else {
                        throw CancellationError()
                    }
                }
                try Task.checkCancellation()
                let grants = try context.fetch(FetchDescriptor<BadgeGrant>()).map(BadgeEngine.grantSnapshot)
                let weight = WorkoutCaloriePreferences.current().bodyWeightKg
                let result = await Task.detached(priority: .utility) {
                    BadgeEngine.calculateProgress(workouts: workouts, grants: grants, currentWeight: weight)
                }.value
                try Task.checkCancellation()
                guard self.revision == generation else { throw CancellationError() }
                self.cachedWorkouts = workouts
                self.publish(result)
                self.isReady = true
                self.needsRefresh = false
                self.completedRefreshCount += 1
                WorkoutPerformanceMonitor.event("badgeWall.refresh.completed")
            } catch {
                // 保留旧内容，下一次数据事件或页面进入时重试。
                WorkoutPerformanceMonitor.event("badgeWall.refresh.discarded")
            }
            guard self.sessionGeneration == session else { return }
            self.refreshTask = nil
            if self.revision != generation { self.ensureLoaded() }
        }
    }

    func waitUntilLoaded() async {
        ensureLoaded()
        while let task = refreshTask { await task.value }
    }

    private func publish(_ values: [BadgeProgress]) {
        progress = values
        sections = Dictionary(grouping: values, by: { $0.definition.category }).mapValues {
            $0.sorted {
                if $0.isUnlocked != $1.isUnlocked { return $0.isUnlocked }
                return $0.definition.orderIndex < $1.definition.orderIndex
            }
        }
    }

    func saved(_ notification: Notification) {
        guard let source = notification.object as? ModelContext, source === context else { return }
        func identifiers(_ key: ModelContext.NotificationKey) -> [PersistentIdentifier] {
            (notification.userInfo?[key.rawValue] as? [PersistentIdentifier]) ?? []
        }
        let changed = identifiers(.insertedIdentifiers) + identifiers(.updatedIdentifiers)
        let deleted = identifiers(.deletedIdentifiers)
        let historyNames: Set<String> = ["Workout", "WorkoutExercise", "WorkoutSet", "WorkoutPlan"]
        // 删除后归属可能已不可读，保守失效；其余只按变更标识查所属训练，不扫描历史。
        let historyChanged = deleted.contains { historyNames.contains($0.entityName) } || changed.contains { id in
            guard historyNames.contains(id.entityName) else { return false }
            let workout: Workout?
            switch id.entityName {
            case "Workout": workout = source.model(for: id) as? Workout
            case "WorkoutExercise": workout = (source.model(for: id) as? WorkoutExercise)?.workout
            case "WorkoutSet": workout = (source.model(for: id) as? WorkoutSet)?.exercise?.workout
            default: return true
            }
            guard let workout else { return true }
            return workout.endedAt != nil || workout.deletedAt != nil
        }
        if historyChanged {
            invalidate()
        } else if (changed + deleted).contains(where: { $0.entityName == "BadgeGrant" }), !isBackfilling {
            invalidate(historyChanged: false)
        }
    }
}
