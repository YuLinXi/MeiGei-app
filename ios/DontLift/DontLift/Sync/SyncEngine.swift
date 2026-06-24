import Foundation
import SwiftData

extension Notification.Name {
    /// 一轮 `syncAll()` 完成（push/pull 走完一遍）后广播；供服务端权威域（如 Team 今日动态）据此重拉，
    /// 保证「删训练 → 同步后端撤销 checkin → Team feed 反映移除」的有序刷新。
    static let dontliftSyncCompleted = Notification.Name("dontlift.sync.completed")
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
    private(set) var isSyncing = false
    /// 最近一次同步产生的「本地修改被覆盖」提示，供 UI 展示后清空。
    private(set) var pendingConflictNotices: [ConflictNotice] = []

    init(modelContext: ModelContext, api: APIClient = .shared) {
        self.modelContext = modelContext
        self.api = api
    }

    func clearConflictNotices() { pendingConflictNotices = [] }

    /// 串行同步全部域。单域失败不阻断其余域，失败项留待下次重试。
    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await runSafely { try await self.syncCustomExercises() }
        await runSafely { try await self.syncWorkoutPlanGroups() }
        await runSafely { try await self.syncWorkoutPlans() }
        await runSafely { try await self.syncWorkouts() }
        try? modelContext.save()
        // 同步周期完成：广播给服务端权威域刷新（失败项仍 pending，下轮再播）。
        WorkoutPerformanceMonitor.event("syncAll.completed")
        NotificationCenter.default.post(name: .dontliftSyncCompleted, object: nil)
    }

    private func runSafely(_ op: () async throws -> Void) async {
        do { try await op() } catch { /* 失败项保持 pending，下次重试 */ }
    }

    // MARK: - 通用 push / pull

    private func push<DTO: Codable>(_ domain: SyncDomain, _ items: [DTO], idParts: [String]) async throws -> SyncPushResult<DTO> {
        let key = IdempotencyKey.forBatch(domain: domain, parts: idParts)
        return try await api.send("POST", domain.pushPath,
                                  body: SyncPushRequest(items: items),
                                  idempotencyKey: key)
    }

    private func pull<DTO: Decodable>(_ domain: SyncDomain) async throws -> SyncPullResult<DTO> {
        var query: [URLQueryItem] = []
        if let since = domain.since {
            query.append(URLQueryItem(name: "since", value: JSONCoding.string(from: since)))
        }
        return try await api.send("GET", domain.pullPath, query: query)
    }

    // MARK: - CustomExercise

    private func syncCustomExercises() async throws {
        let pending = try fetchPendingCustomExercises()
        if !pending.isEmpty {
            let dtos = pending.map(dto(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let res: SyncPushResult<CustomExerciseDTO> = try await push(
                .customExercises, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" })
            applyPushResult(res, domain: .customExercises, lookup: { id in pendingById[id] }, apply: applyServer(_:to:))
        }
        let pulled: SyncPullResult<CustomExerciseDTO> = try await pull(.customExercises)
        for dto in pulled.changes { upsert(dto) }
        SyncDomain.customExercises.since = pulled.serverTime
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
            if dto.updatedAt > local.updatedAt { applyServer(dto, to: local) }
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

    private func syncWorkoutPlanGroups() async throws {
        let pending = try fetchPendingWorkoutPlanGroups()
        if !pending.isEmpty {
            let dtos = pending.map(dto(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let res: SyncPushResult<WorkoutPlanGroupDTO> = try await push(
                .workoutPlanGroups, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" })
            applyPushResult(res, domain: .workoutPlanGroups, lookup: { id in pendingById[id] }, apply: applyServer(_:to:))
        }
        let pulled: SyncPullResult<WorkoutPlanGroupDTO> = try await pull(.workoutPlanGroups)
        for dto in pulled.changes { upsert(dto) }
        SyncDomain.workoutPlanGroups.since = pulled.serverTime
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
            if dto.updatedAt > local.updatedAt { applyServer(dto, to: local) }
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

    private func syncWorkoutPlans() async throws {
        let pending = try fetchPendingWorkoutPlans()
        if !pending.isEmpty {
            let dtos = pending.map(dto(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let res: SyncPushResult<WorkoutPlanDTO> = try await push(
                .workoutPlans, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" })
            applyPushResult(res, domain: .workoutPlans, lookup: { id in pendingById[id] }, apply: applyServer(_:to:))
        }
        let pulled: SyncPullResult<WorkoutPlanDTO> = try await pull(.workoutPlans)
        for dto in pulled.changes { upsert(dto) }
        SyncDomain.workoutPlans.since = pulled.serverTime
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
        return WorkoutPlanDTO(id: m.localId, userId: nil, name: m.name, items: itemsJSON,
                              mode: m.modeRaw,
                              forkedFrom: m.forkedFrom, sharedToTeamId: m.sharedToTeamId,
                              groupId: m.groupId, sortOrder: m.sortOrder,
                              createdAt: nil, updatedAt: m.updatedAt, deletedAt: m.deletedAt, version: m.version)
    }

    private func applyServer(_ dto: WorkoutPlanDTO, to m: WorkoutPlan) {
        m.name = dto.name
        m.items = decodeItems(dto.items)
        // 解码缺失/未识别值兜底 adaptive（兼容旧后端、旧数据）。
        m.modeRaw = dto.mode.flatMap(WorkoutPlanMode.init(rawValue:))?.rawValue ?? WorkoutPlanMode.adaptive.rawValue
        m.forkedFrom = dto.forkedFrom
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
            if dto.updatedAt > local.updatedAt { applyServer(dto, to: local) }
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

    private func syncWorkouts() async throws {
        let pending = try fetchPendingWorkouts()
        if !pending.isEmpty {
            let dtos = pending.map(tree(from:))
            let pendingById = Dictionary(uniqueKeysWithValues: pending.map { ($0.localId, $0) })
            let res: SyncPushResult<WorkoutTreeDTO> = try await push(
                .workouts, dtos, idParts: pending.map { "\($0.localId):\($0.updatedAt.timeIntervalSince1970)" })
            applyPushResult(res,
                            domain: .workouts,
                            idOf: { $0.workout.id },
                            nameOf: { $0.workout.title ?? "训练" },
                            lookup: { id in pendingById[id] },
                            apply: applyServer(tree:to:))
        }
        let pulled: SyncPullResult<WorkoutTreeDTO> = try await pull(.workouts)
        for tree in pulled.changes { upsert(tree) }
        SyncDomain.workouts.since = pulled.serverTime
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
                    WorkoutSetDTO(id: st.localId, workoutExerciseId: ex.localId, setIndex: st.setIndex,
                                  weightKg: st.weightKg, reps: st.reps, completed: st.completed, note: st.note,
                                  setType: st.setTypeRaw)
                })
        }
        let w = WorkoutDTO(id: m.localId, userId: nil, planId: m.planId, title: m.title,
                           startedAt: m.startedAt, endedAt: m.endedAt, note: m.note,
                           createdAt: nil, updatedAt: m.updatedAt, deletedAt: m.deletedAt, version: m.version)
        return WorkoutTreeDTO(workout: w, exercises: nodes)
    }

    private func applyServer(tree dto: WorkoutTreeDTO, to m: Workout) {
        let w = dto.workout
        m.planId = w.planId; m.title = w.title
        if let s = w.startedAt { m.startedAt = s }
        m.endedAt = w.endedAt; m.note = w.note
        m.updatedAt = w.updatedAt; m.deletedAt = w.deletedAt
        m.version = w.version ?? m.version
        m.serverId = w.id; m.syncStatus = .synced
        replaceChildren(of: m, with: dto.exercises)
    }

    private func replaceChildren(of m: Workout, with nodes: [WorkoutTreeDTO.ExerciseNode]) {
        for ex in m.exercises { modelContext.delete(ex) }
        m.exercises = nodes.map { node in
            let ex = WorkoutExercise(localId: node.exercise.id,
                                     builtinExerciseCode: node.exercise.builtinExerciseCode,
                                     customExerciseId: node.exercise.customExerciseId,
                                     exerciseName: node.exercise.exerciseName,
                                     primaryMuscle: node.exercise.primaryMuscle,
                                     orderIndex: node.exercise.orderIndex, note: node.exercise.note,
                                     planItemId: node.exercise.planItemId)
            ex.sets = node.sets.map {
                // 解码缺失/未识别值兜底 working（兼容旧后端、旧数据、跨版本扩展类型）。
                let type = $0.setType.flatMap(WorkoutSetType.init(rawValue:)) ?? .working
                return WorkoutSet(localId: $0.id, setIndex: $0.setIndex, weightKg: $0.weightKg,
                                  reps: $0.reps, completed: $0.completed ?? false, note: $0.note, setType: type)
            }
            return ex
        }
    }

    private func upsert(_ dto: WorkoutTreeDTO) {
        if let local = findWorkout(localId: dto.workout.id) {
            if dto.workout.deletedAt != nil { modelContext.delete(local); return }
            if dto.workout.updatedAt > local.updatedAt { applyServer(tree: dto, to: local) }
        } else if dto.workout.deletedAt == nil {
            let m = Workout(localId: dto.workout.id, now: dto.workout.updatedAt)
            applyServer(tree: dto, to: m)
            modelContext.insert(m)
        }
    }

    private func findWorkout(localId: UUID) -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.localId == localId }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - push 结果落地（applied / conflicts）

    /// 信封型实体（id 即 localId）。
    private func applyPushResult<DTO: Decodable, M: AnyObject>(
        _ res: SyncPushResult<DTO>,
        domain: SyncDomain,
        lookup: (UUID) -> M?,
        apply: (DTO, M) -> Void
    ) where DTO: HasEnvelopeId {
        applyPushResult(res, domain: domain, idOf: { $0.envelopeId }, nameOf: { $0.envelopeName },
                        lookup: lookup, apply: apply)
    }

    private func applyPushResult<DTO: Decodable, M: AnyObject>(
        _ res: SyncPushResult<DTO>,
        domain: SyncDomain,
        idOf: (DTO) -> UUID,
        nameOf: (DTO) -> String,
        lookup: (UUID) -> M?,
        apply: (DTO, M) -> Void
    ) {
        applyTimestampAdjustments(res.timestampAdjustments, domain: domain, lookup: lookup)
        for id in res.applied {
            guard let m = lookup(id) as? (any Syncable) else { continue }
            if m.syncStatus == .pendingDelete {
                if let obj = m as? PersistentModel { modelContext.delete(obj) }
            } else {
                m.serverId = m.localId
                m.syncStatus = .synced
            }
        }
        for conflict in res.conflicts {
            guard let m = lookup(conflict.id) else { continue }
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
