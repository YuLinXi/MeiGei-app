import Foundation
import SwiftData

extension Notification.Name {
    /// 一轮 `syncAll()` 完成（push/pull 走完一遍）后广播；供服务端权威域（如 Team 今日动态）据此重拉，
    /// 保证「删训练 → 同步后端撤销 checkin → Team feed 反映移除」的有序刷新。
    static let dontliftSyncCompleted = Notification.Name("dontlift.sync.completed")
    /// workout 域完整 push/pull 且本地落盘成功后广播；用于重放依赖服务端 workout 已存在的队列任务。
    static let dontliftWorkoutSyncSucceeded = Notification.Name("dontlift.sync.workouts.succeeded")
}

/// 离线优先同步引擎（design.md D2/D3/D4）。
///
/// 流程：每个域先 push 本地待同步项（带幂等键），再按 since 水位 pull 增量。
/// 冲突按 updatedAt last-write-wins：服务端较新则采纳服务端值并产生人工提示；
/// push 失败的项保持 pending 状态，下次同步自动重试（即「重试队列」）。
@MainActor
@Observable
final class SyncEngine {
    private let modelContext: ModelContext
    private let api: APIClient
    private let watermarkDefaults: UserDefaults
    private let canSync: () -> Bool
    private let saveContext: () throws -> Void
    private(set) var isSyncing = false
    private(set) var lastResult: SyncResult?
    @ObservationIgnored private var resultGeneration = 0
    @ObservationIgnored private var syncingGeneration: Int?
    private var needsFollowUpSync = false
    private var scheduledSyncTask: Task<Void, Never>?
    /// 最近一次同步产生的「本地修改被覆盖」提示，供 UI 展示后清空。
    private(set) var pendingConflictNotices: [ConflictNotice] = []

    init(modelContext: ModelContext, api: APIClient = .shared, watermarkDefaults: UserDefaults = .standard,
         canSync: @escaping () -> Bool = { true }, save: (() throws -> Void)? = nil) {
        self.modelContext = modelContext
        self.api = api
        self.watermarkDefaults = watermarkDefaults
        self.canSync = canSync
        self.saveContext = save ?? { try LocalModelSave.save(modelContext) }
    }

    func clearConflictNotices() { pendingConflictNotices = [] }

    func resetResult() {
        resultGeneration += 1
        syncingGeneration = nil
        isSyncing = false
        needsFollowUpSync = false
        scheduledSyncTask?.cancel()
        scheduledSyncTask = nil
        pendingConflictNotices = []
        lastResult = nil
    }

    /// 延迟触发一轮全域同步；短时间内重复调用会合并为最后一次。
    func scheduleSyncAll(after delay: TimeInterval = 2) {
        scheduledSyncTask?.cancel()
        scheduledSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncAll()
        }
    }

    /// 轻量检查本地是否存在待同步项；回前台门控使用，避免无条件触发全量同步。
    func hasPendingLocalChanges(excludingWorkoutId: UUID? = nil) -> Bool {
        (try? hasPendingCustomExercises()) == true
        || (try? hasPendingWorkoutPlanGroups()) == true
        || (try? hasPendingWorkoutPlans()) == true
        || (try? hasPendingWorkouts(excluding: excludingWorkoutId)) == true
    }

    /// 串行同步全部域。单域失败不阻断其余域，失败项留待下次重试。
    func syncAll() async {
        guard canSync(), !Task.isCancelled else { return }
        if isSyncing {
            needsFollowUpSync = true
            return
        }
        let generation = resultGeneration
        syncingGeneration = generation
        isSyncing = true
        defer {
            if syncingGeneration == generation {
                syncingGeneration = nil
                isSyncing = false
            }
        }
        prepareWatermarksForCurrentStore()
        repeat {
            needsFollowUpSync = false
            await syncOnce(generation: generation)
        } while needsFollowUpSync && isCurrentCycle(generation)
    }

    private func prepareWatermarksForCurrentStore() {
        let stores = modelContext.container.configurations.filter { !$0.isStoredInMemoryOnly }
        guard !stores.isEmpty else { return }
        let identity = stores.map { configuration in
            let url = configuration.url.standardizedFileURL.resolvingSymlinksInPath()
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileNumber = (attributes?[.systemFileNumber] as? NSNumber)?.stringValue ?? ""
            // 路径识别 App Group／容器切换，文件号识别同一路径下的数据库重建。
            return url.absoluteString + "#" + fileNumber
        }.sorted().joined(separator: "|")
        SyncDomain.prepareWatermarks(for: identity, in: watermarkDefaults)
    }

    private func syncOnce(generation: Int) async {
        guard isCurrentCycle(generation) else { return }
        WorkoutPerformanceMonitor.event("syncAll.started")
        let customExercisesTime = await runSafely { try await self.syncCustomExercises(generation: generation) }
        await Task.yield()
        guard isCurrentCycle(generation) else { return }
        let planGroupsTime = await runSafely { try await self.syncWorkoutPlanGroups(generation: generation) }
        await Task.yield()
        guard isCurrentCycle(generation) else { return }
        let plansTime = await runSafely { try await self.syncWorkoutPlans(generation: generation) }
        await Task.yield()
        guard isCurrentCycle(generation) else { return }
        let workoutsTime = await runSafely { try await self.syncWorkouts(generation: generation) }
        await Task.yield()
        guard isCurrentCycle(generation) else { return }
        let completedPulls: [(SyncDomain, Date?)] = [
            (.customExercises, customExercisesTime.serverTime), (.workoutPlanGroups, planGroupsTime.serverTime),
            (.workoutPlans, plansTime.serverTime), (.workouts, workoutsTime.serverTime)
        ]
        let batchSaveFailed = customExercisesTime.localSaveFailed || planGroupsTime.localSaveFailed
            || plansTime.localSaveFailed || workoutsTime.localSaveFailed
        let saved: Bool
        do {
            try saveContext()
            saved = !batchSaveFailed
        } catch {
            saved = false
        }
        guard isCurrentCycle(generation) else { return }
        // 中途批次失败不能被最终保存成功掩盖；全部本地提交可靠完成后才推进水位。
        if saved {
            for (domain, time) in completedPulls {
                if let time { domain.setWatermark(time, in: watermarkDefaults) }
            }
        }
        lastResult = SyncResult(failedDomains: completedPulls.compactMap { domain, time in
            time == nil ? domain : nil
        }, localSaveSucceeded: saved)
        // 同步周期完成：广播给服务端权威域刷新（失败项仍 pending，下轮再播）。
        WorkoutPerformanceMonitor.event("syncAll.completed")
        NotificationCenter.default.post(name: .dontliftSyncCompleted, object: nil)
        if workoutsTime.serverTime != nil && saved {
            NotificationCenter.default.post(name: .dontliftWorkoutSyncSucceeded, object: nil)
        }
    }

    private enum LocalSaveFailure: Error { case batch }

    private func runSafely(_ op: () async throws -> Date) async -> (serverTime: Date?, localSaveFailed: Bool) {
        do {
            return (try await op(), false)
        } catch is LocalSaveFailure {
            return (nil, true)
        } catch {
            // 失败项保持 pending，下次重试。
            return (nil, false)
        }
    }

    private func isCurrentCycle(_ generation: Int) -> Bool {
        generation == resultGeneration && canSync() && !Task.isCancelled
    }

    private func checkCycle(_ generation: Int) throws {
        guard isCurrentCycle(generation) else { throw CancellationError() }
    }

    private func hasPendingCustomExercises() throws -> Bool {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        var descriptor = FetchDescriptor<CustomExercise>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private func hasPendingWorkoutPlanGroups() throws -> Bool {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        var descriptor = FetchDescriptor<WorkoutPlanGroup>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private func hasPendingWorkoutPlans() throws -> Bool {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        var descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private func hasPendingWorkouts(excluding workoutId: UUID?) throws -> Bool {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        var descriptor: FetchDescriptor<Workout>
        if let workoutId {
            descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate {
                    ($0.syncStatusRaw == pendingCreate
                     || $0.syncStatusRaw == pendingUpdate
                     || $0.syncStatusRaw == pendingDelete)
                    && $0.localId != workoutId
                }
            )
        } else {
            descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate {
                    $0.syncStatusRaw == pendingCreate
                    || $0.syncStatusRaw == pendingUpdate
                    || $0.syncStatusRaw == pendingDelete
                }
            )
        }
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    // MARK: - 通用 push / pull

    private func push<DTO: Codable>(_ domain: SyncDomain, _ items: [DTO], idParts: [String], generation: Int) async throws -> SyncPushResult<DTO> {
        try checkCycle(generation)
        let key = IdempotencyKey.forBatch(domain: domain, parts: idParts)
        let result: SyncPushResult<DTO> = try await api.send("POST", domain.pushPath,
                                  body: SyncPushRequest(items: items),
                                  idempotencyKey: key)
        try checkCycle(generation)
        return result
    }

    private func pull<DTO: Decodable>(_ domain: SyncDomain, generation: Int) async throws -> SyncPullResult<DTO> {
        try checkCycle(generation)
        var query: [URLQueryItem] = []
        if let since = domain.watermark(in: watermarkDefaults) {
            query.append(URLQueryItem(name: "since", value: JSONCoding.string(from: since)))
        }
        let result: SyncPullResult<DTO> = try await api.send("GET", domain.pullPath, query: query)
        try checkCycle(generation)
        return result
    }

    // MARK: - CustomExercise

    private func syncCustomExercises(generation: Int) async throws -> Date {
        let pending = try fetchPendingCustomExercises()
        if !pending.isEmpty {
            let dtos = pending.map(dto(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let pushedUpdatedAt = pendingById.mapValues(\.updatedAt)
            let res: SyncPushResult<CustomExerciseDTO> = try await push(
                .customExercises, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" }, generation: generation)
            applyPushResult(res, domain: .customExercises, pushedUpdatedAt: pushedUpdatedAt,
                                lookup: { id in pendingById[id] }, apply: applyServer(_:to:))
        }
        let pulled: SyncPullResult<CustomExerciseDTO> = try await pull(.customExercises, generation: generation)
        for dto in pulled.changes { upsert(dto) }
        return pulled.serverTime
    }

    private func fetchPendingCustomExercises() throws -> [CustomExercise] {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        let descriptor = FetchDescriptor<CustomExercise>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func dto(from m: CustomExercise) -> CustomExerciseDTO {
        CustomExerciseDTO(id: m.localId, userId: nil, name: m.name,
                          primaryMuscle: m.primaryMuscle, equipmentType: m.equipmentType,
                          createdAt: nil, updatedAt: m.updatedAt, deletedAt: m.deletedAt, version: m.version)
    }

    private func applyServer(_ dto: CustomExerciseDTO, to m: CustomExercise) {
        m.name = dto.name
        m.primaryMuscle = dto.primaryMuscle
        m.equipmentType = dto.equipmentType
        m.updatedAt = dto.updatedAt
        m.deletedAt = dto.deletedAt
        m.version = dto.version ?? m.version
        m.serverId = dto.id
        m.syncStatus = .synced
    }

    private func upsert(_ dto: CustomExerciseDTO) {
        if let local = findCustomExercise(localId: dto.id) {
            if dto.deletedAt != nil { modelContext.delete(local); return }
            if SyncClock.isNewer(dto.updatedAt, than: local.updatedAt) { applyServer(dto, to: local) }
        } else if dto.deletedAt == nil {
            let m = CustomExercise(localId: dto.id, name: dto.name,
                                   primaryMuscle: dto.primaryMuscle, equipmentType: dto.equipmentType,
                                   now: dto.updatedAt)
            applyServer(dto, to: m)
            modelContext.insert(m)
        }
    }

    private func findCustomExercise(localId: UUID) -> CustomExercise? {
        var descriptor = FetchDescriptor<CustomExercise>(
            predicate: #Predicate { $0.localId == localId }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - WorkoutPlanGroup

    private func syncWorkoutPlanGroups(generation: Int) async throws -> Date {
        let pending = try fetchPendingWorkoutPlanGroups()
        if !pending.isEmpty {
            let dtos = pending.map(dto(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let pushedUpdatedAt = pendingById.mapValues(\.updatedAt)
            let res: SyncPushResult<WorkoutPlanGroupDTO> = try await push(
                .workoutPlanGroups, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" }, generation: generation)
            applyPushResult(res, domain: .workoutPlanGroups, pushedUpdatedAt: pushedUpdatedAt,
                                lookup: { id in pendingById[id] }, apply: applyServer(_:to:))
        }
        let pulled: SyncPullResult<WorkoutPlanGroupDTO> = try await pull(.workoutPlanGroups, generation: generation)
        for dto in pulled.changes { upsert(dto) }
        return pulled.serverTime
    }

    private func fetchPendingWorkoutPlanGroups() throws -> [WorkoutPlanGroup] {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        let descriptor = FetchDescriptor<WorkoutPlanGroup>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func dto(from m: WorkoutPlanGroup) -> WorkoutPlanGroupDTO {
        WorkoutPlanGroupDTO(id: m.localId, userId: nil, name: m.name,
                            sortOrder: m.sortOrder,
                            createdAt: nil, updatedAt: m.updatedAt, deletedAt: m.deletedAt, version: m.version)
    }

    private func applyServer(_ dto: WorkoutPlanGroupDTO, to m: WorkoutPlanGroup) {
        m.name = dto.name
        m.sortOrder = dto.sortOrder ?? 0
        m.updatedAt = dto.updatedAt
        m.deletedAt = dto.deletedAt
        m.version = dto.version ?? m.version
        m.serverId = dto.id
        m.syncStatus = .synced
    }

    private func upsert(_ dto: WorkoutPlanGroupDTO) {
        if let local = findWorkoutPlanGroup(localId: dto.id) {
            if dto.deletedAt != nil { modelContext.delete(local); return }
            if SyncClock.isNewer(dto.updatedAt, than: local.updatedAt) { applyServer(dto, to: local) }
        } else if dto.deletedAt == nil {
            let m = WorkoutPlanGroup(localId: dto.id, name: dto.name,
                                     sortOrder: dto.sortOrder ?? 0,
                                     now: dto.updatedAt)
            applyServer(dto, to: m)
            modelContext.insert(m)
        }
    }

    private func findWorkoutPlanGroup(localId: UUID) -> WorkoutPlanGroup? {
        var descriptor = FetchDescriptor<WorkoutPlanGroup>(
            predicate: #Predicate { $0.localId == localId }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - WorkoutPlan

    private func syncWorkoutPlans(generation: Int) async throws -> Date {
        let pending = try fetchPendingWorkoutPlans()
        if !pending.isEmpty {
            let dtos = pending.map(dto(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let pushedUpdatedAt = pendingById.mapValues(\.updatedAt)
            let res: SyncPushResult<WorkoutPlanDTO> = try await push(
                .workoutPlans, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" }, generation: generation)
            applyPushResult(res, domain: .workoutPlans, pushedUpdatedAt: pushedUpdatedAt,
                                lookup: { id in pendingById[id] }, apply: applyServer(_:to:))
        }
        let pulled: SyncPullResult<WorkoutPlanDTO> = try await pull(.workoutPlans, generation: generation)
        for dto in pulled.changes { upsert(dto) }
        return pulled.serverTime
    }

    private func fetchPendingWorkoutPlans() throws -> [WorkoutPlan] {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        let descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func dto(from m: WorkoutPlan) -> WorkoutPlanDTO {
        let itemsJSON = (try? String(data: JSONCoding.encoder.encode(m.items), encoding: .utf8)) ?? "[]"
        return WorkoutPlanDTO(id: m.localId, userId: nil, name: m.name, note: m.note, items: itemsJSON,
                              mode: m.modeRaw,
                              forkedFrom: m.forkedFrom,
                              forkedFromShareVersionId: m.forkedFromShareVersionId,
                              sharedToTeamId: m.sharedToTeamId,
                              groupId: m.groupId, sortOrder: m.sortOrder,
                              createdAt: nil, updatedAt: m.updatedAt, deletedAt: m.deletedAt, version: m.version)
    }

    private func applyServer(_ dto: WorkoutPlanDTO, to m: WorkoutPlan) {
        m.name = dto.name
        m.note = dto.note
        m.items = decodeItems(dto.items)
        // 解码缺失/未识别值兜底 adaptive（兼容旧后端、旧数据）。
        m.modeRaw = dto.mode.flatMap(WorkoutPlanMode.init(rawValue:))?.rawValue ?? WorkoutPlanMode.adaptive.rawValue
        m.forkedFrom = dto.forkedFrom
        m.forkedFromShareVersionId = dto.forkedFromShareVersionId
        m.sharedToTeamId = dto.sharedToTeamId
        m.groupId = dto.groupId
        m.sortOrder = dto.sortOrder ?? 0
        m.updatedAt = dto.updatedAt
        m.deletedAt = dto.deletedAt
        m.version = dto.version ?? m.version
        m.serverId = dto.id
        m.syncStatus = .synced
    }

    private func decodeItems(_ json: String) -> [PlanItem] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONCoding.decoder.decode([PlanItem].self, from: data)) ?? []
    }

    private func upsert(_ dto: WorkoutPlanDTO) {
        if let local = findWorkoutPlan(localId: dto.id) {
            if dto.deletedAt != nil { modelContext.delete(local); return }
            if SyncClock.isNewer(dto.updatedAt, than: local.updatedAt) { applyServer(dto, to: local) }
        } else if dto.deletedAt == nil {
            let m = WorkoutPlan(localId: dto.id, name: dto.name, now: dto.updatedAt)
            applyServer(dto, to: m)
            modelContext.insert(m)
        }
    }

    private func findWorkoutPlan(localId: UUID) -> WorkoutPlan? {
        var descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate { $0.localId == localId }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Workout（聚合树）

    private func syncWorkouts(generation: Int) async throws -> Date {
        let pending = try fetchPendingWorkouts()
        if !pending.isEmpty {
            let dtos = pending.map(tree(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let pushedUpdatedAt = pendingById.mapValues(\.updatedAt)
            let res: SyncPushResult<WorkoutTreeDTO> = try await push(
                .workouts, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" }, generation: generation)
            applyPushResult(res,
                            domain: .workouts,
                            pushedUpdatedAt: pushedUpdatedAt,
                            idOf: { $0.workout.id },
                            nameOf: { $0.workout.title ?? "训练" },
                            lookup: { id in pendingById[id] },
                            apply: applyServer(tree:to:))
        }
        let pulled: SyncPullResult<WorkoutTreeDTO> = try await pull(.workouts, generation: generation)
        for start in stride(from: 0, to: pulled.changes.count, by: 32) {
            let end = min(start + 32, pulled.changes.count)
            let trees = pulled.changes[start..<end]
            let ids = trees.map { $0.workout.id }
            let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { ids.contains($0.localId) })
            // 根查询也限制窗口，避免一次物化数千个已有模型；前一窗口已可靠保存。
            var existing = Dictionary(uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.localId, $0) })
            var pendingNodes = 0
            for tree in trees {
                var nodes = 1 + (tree.workout.deletedAt == nil
                    ? tree.exercises.reduce(0) { $0 + 1 + $1.sets.count } : 0)
                if let local = existing[tree.workout.id], tree.workout.deletedAt != nil
                    || (local.syncStatus == .synced && SyncClock.isNewer(tree.workout.updatedAt, than: local.updatedAt)) {
                    nodes += local.exercises.reduce(0) { $0 + 1 + $1.sets.count }
                }
                // 聚合保持完整；限制每次落盘规模，避免把所有子节点堆到周期最终保存。
                if pendingNodes > 0 && pendingNodes + nodes > 128 {
                    try await saveWorkoutBatch(generation: generation)
                    pendingNodes = 0
                }
                existing[tree.workout.id] = upsert(tree, existing: existing[tree.workout.id])
                pendingNodes += nodes
            }
            if end < pulled.changes.count { try await saveWorkoutBatch(generation: generation) }
        }
        return pulled.serverTime
    }

    private func saveWorkoutBatch(generation: Int) async throws {
        do { try saveContext() } catch { throw LocalSaveFailure.batch }
        await Task.yield()
        try checkCycle(generation)
    }

    private func fetchPendingWorkouts() throws -> [Workout] {
        let pendingCreate = SyncStatus.pendingCreate.rawValue
        let pendingUpdate = SyncStatus.pendingUpdate.rawValue
        let pendingDelete = SyncStatus.pendingDelete.rawValue
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate {
                $0.syncStatusRaw == pendingCreate
                || $0.syncStatusRaw == pendingUpdate
                || $0.syncStatusRaw == pendingDelete
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func tree(from m: Workout) -> WorkoutTreeDTO {
        let nodes = m.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { ex in
            WorkoutTreeDTO.ExerciseNode(
                exercise: WorkoutExerciseDTO(id: ex.localId, workoutId: m.localId, userId: nil,
                                             builtinExerciseCode: ex.builtinExerciseCode,
                                             customExerciseId: ex.customExerciseId,
                                             exerciseName: ex.exerciseName, primaryMuscle: ex.primaryMuscle,
                                             orderIndex: ex.orderIndex, note: ex.note,
                                             planItemId: ex.planItemId),
                sets: ex.sets.sorted { $0.setIndex < $1.setIndex }.map { st in
                    if st.isDropSet { st.syncDropSummaryFromSegments() }
                    return WorkoutSetDTO(id: st.localId, workoutExerciseId: ex.localId, setIndex: st.setIndex,
                                         weightKg: st.weightKg, reps: st.reps, completed: st.completed, note: st.note,
                                         plannedRestSeconds: st.plannedRestSeconds,
                                         actualRestSeconds: st.actualRestSeconds,
                                         setType: st.setTypeRaw,
                                         isWarmup: st.isWarmupEffective,
                                         segments: Self.encodeSegments(st.segments))
                })
        }
        let w = WorkoutDTO(id: m.localId, userId: nil, planId: m.planId,
                           sourceShareId: m.sourceShareId,
                           sourceShareVersionId: m.sourceShareVersionId,
                           sourcePlanNameSnapshot: m.sourcePlanNameSnapshot,
                           title: m.title,
                           startedAt: m.startedAt, endedAt: m.endedAt,
                           bodyWeightKgAtCompletion: m.bodyWeightKgAtCompletion, note: m.note,
                           units: m.unitsJSON,
                           createdAt: nil, updatedAt: m.updatedAt, deletedAt: m.deletedAt, version: m.version)
        return WorkoutTreeDTO(workout: w, exercises: nodes)
    }

    private func applyServer(tree dto: WorkoutTreeDTO, to m: Workout) {
        let w = dto.workout
        m.planId = w.planId
        m.sourceShareId = w.sourceShareId
        m.sourceShareVersionId = w.sourceShareVersionId
        m.sourcePlanNameSnapshot = w.sourcePlanNameSnapshot
        m.title = w.title
        if let s = w.startedAt { m.startedAt = s }
        m.endedAt = w.endedAt
        m.bodyWeightKgAtCompletion = w.bodyWeightKgAtCompletion
        m.note = w.note
        m.unitsJSON = w.units
        m.updatedAt = w.updatedAt; m.deletedAt = w.deletedAt
        m.version = w.version ?? m.version
        m.serverId = w.id; m.syncStatus = .synced
        replaceChildren(of: m, with: dto.exercises)
    }

    private func replaceChildren(of m: Workout, with nodes: [WorkoutTreeDTO.ExerciseNode]) {
        // 相同唯一ID原位更新，避免旧系统在删除后重建时丢失组关系。
        var existingExercises = Dictionary(uniqueKeysWithValues: m.exercises.map { ($0.localId, $0) })
        m.exercises = nodes.map { node in
            let existing = existingExercises.removeValue(forKey: node.exercise.id)
            let ex = existing ?? WorkoutExercise(localId: node.exercise.id,
                                                  exerciseName: node.exercise.exerciseName,
                                                  orderIndex: node.exercise.orderIndex)
            ex.builtinExerciseCode = node.exercise.builtinExerciseCode
            ex.customExerciseId = node.exercise.customExerciseId
            ex.exerciseName = node.exercise.exerciseName
            ex.primaryMuscle = node.exercise.primaryMuscle
            ex.orderIndex = node.exercise.orderIndex
            ex.note = node.exercise.note
            ex.planItemId = node.exercise.planItemId
            var existingSets = Dictionary(uniqueKeysWithValues: (existing?.sets ?? []).map { ($0.localId, $0) })
            ex.sets = node.sets.map {
                // 解码缺失/未识别值兜底 working（兼容旧后端、旧数据、跨版本扩展类型）。
                let type = $0.setType.flatMap(WorkoutSetType.init(rawValue:)) ?? .working
                let segments = Self.decodeSegments($0.segments)
                let isWarmup = ($0.isWarmup ?? false) || type == .warmup
                if let set = existingSets.removeValue(forKey: $0.id) {
                    set.setIndex = $0.setIndex
                    set.weightKg = $0.weightKg
                    set.reps = $0.reps
                    set.completed = $0.completed ?? false
                    set.note = $0.note
                    set.plannedRestSeconds = $0.plannedRestSeconds
                    set.actualRestSeconds = $0.actualRestSeconds
                    set.setType = type
                    set.isWarmup = isWarmup
                    set.segments = segments
                    set.syncDropSummaryFromSegments()
                    return set
                }
                return WorkoutSet(localId: $0.id, setIndex: $0.setIndex, weightKg: $0.weightKg,
                                  reps: $0.reps, completed: $0.completed ?? false, note: $0.note,
                                  plannedRestSeconds: $0.plannedRestSeconds,
                                  actualRestSeconds: $0.actualRestSeconds,
                                  setType: type,
                                  isWarmup: isWarmup,
                                  segments: segments)
            }
            for set in existingSets.values { modelContext.delete(set) }
            return ex
        }
        for exercise in existingExercises.values { modelContext.delete(exercise) }
    }

    private static func encodeSegments(_ segments: [WorkoutSetSegment]) -> String {
        guard !segments.isEmpty,
              let data = try? JSONCoding.encoder.encode(segments),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeSegments(_ json: String?) -> [WorkoutSetSegment] {
        guard let json,
              let data = json.data(using: .utf8),
              let segments = try? JSONCoding.decoder.decode([WorkoutSetSegment].self, from: data) else {
            return []
        }
        return segments.sorted { $0.segmentIndex < $1.segmentIndex }
    }

    private func upsert(_ dto: WorkoutTreeDTO, existing local: Workout?) -> Workout? {
        if let local {
            // 本地仍有未推送改动时不整棵替换：replaceChildren 会删除正在被界面/后台读取遍历的子节点，
            // 墓碑同样不能抢先删除输入；留待下轮 push 由服务端 LWW 裁决。
            guard local.syncStatus == .synced else { return local }
            if dto.workout.deletedAt != nil { modelContext.delete(local); return nil }
            if SyncClock.isNewer(dto.workout.updatedAt, than: local.updatedAt) { applyServer(tree: dto, to: local) }
            return local
        } else if dto.workout.deletedAt == nil {
            let m = Workout(localId: dto.workout.id, now: dto.workout.updatedAt)
            applyServer(tree: dto, to: m)
            modelContext.insert(m)
            return m
        }
        return nil
    }

    // MARK: - push 结果落地（applied / conflicts）

    /// 信封型实体（id 即 localId）。
    private func applyPushResult<DTO: Decodable, M: AnyObject>(
        _ res: SyncPushResult<DTO>,
        domain: SyncDomain,
        pushedUpdatedAt: [UUID: Date],
        lookup: (UUID) -> M?,
        apply: (DTO, M) -> Void
    ) where DTO: HasEnvelopeId {
        applyPushResult(res, domain: domain, pushedUpdatedAt: pushedUpdatedAt,
                            idOf: { $0.envelopeId }, nameOf: { $0.envelopeName },
                            lookup: lookup, apply: apply)
    }

    private func applyPushResult<DTO: Decodable, M: AnyObject>(
        _ res: SyncPushResult<DTO>,
        domain: SyncDomain,
        pushedUpdatedAt: [UUID: Date],
        idOf: (DTO) -> UUID,
        nameOf: (DTO) -> String,
        lookup: (UUID) -> M?,
        apply: (DTO, M) -> Void
    ) {
        // push 在途期间（await 网络）本地又被编辑过的对象：服务端收到的是旧快照，
        // 不能标 synced（否则较新的本地改动永不上传），也不能用服务端值覆盖本地。
        let modifiedDuringPush = Set(pushedUpdatedAt.compactMap { id, pushedAt -> UUID? in
            guard let m = lookup(id) as? (any Syncable), m.updatedAt != pushedAt else { return nil }
            return id
        })
        applyTimestampAdjustments(res.timestampAdjustments.filter { !modifiedDuringPush.contains($0.id) },
                                  domain: domain, lookup: lookup)
        for id in res.applied {
            guard let m = lookup(id) as? (any Syncable) else { continue }
            if modifiedDuringPush.contains(id) {
                // 服务端已落库：补记 serverId，状态保持待上传，下轮推送最新值。
                m.serverId = m.localId
                if m.syncStatus == .pendingCreate { m.syncStatus = .pendingUpdate }
                continue
            }
            if m.syncStatus == .pendingDelete {
                if let obj = m as? PersistentModel { modelContext.delete(obj) }
            } else {
                m.serverId = m.localId
                m.syncStatus = .synced
            }
        }
        for conflict in res.conflicts {
            guard !modifiedDuringPush.contains(conflict.id), let m = lookup(conflict.id) else { continue }
            apply(conflict.serverValue, m)
            pendingConflictNotices.append(
                ConflictNotice(id: conflict.id, domain: domain, name: nameOf(conflict.serverValue)))
        }
    }

    private func applyTimestampAdjustments<M: AnyObject>(
        _ adjustments: [SyncTimestampAdjustmentDTO],
        domain: SyncDomain,
        lookup: (UUID) -> M?
    ) {
        for adjustment in adjustments {
            guard let m = lookup(adjustment.id) as? (any Syncable) else { continue }
            m.updatedAt = adjustment.adjustedAt
            if let deletedAt = m.deletedAt, deletedAt > adjustment.adjustedAt {
                m.deletedAt = adjustment.adjustedAt
            }
            pendingConflictNotices.append(
                ConflictNotice(id: adjustment.id, domain: domain, name: "设备时间已校正"))
        }
    }
}

/// 让信封型 DTO 暴露 id/name，复用 push 结果落地逻辑。
protocol HasEnvelopeId {
    var envelopeId: UUID { get }
    var envelopeName: String { get }
}
extension CustomExerciseDTO: HasEnvelopeId {
    var envelopeId: UUID { id }; var envelopeName: String { name }
}
extension WorkoutPlanGroupDTO: HasEnvelopeId {
    var envelopeId: UUID { id }; var envelopeName: String { name }
}
extension WorkoutPlanDTO: HasEnvelopeId {
    var envelopeId: UUID { id }; var envelopeName: String { name }
}
