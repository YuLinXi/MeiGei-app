import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct SyncCrashRegressionTests {
    @Test func newCycleStartsWhileOldResponseIsPendingAndOldCompletionCannotClearBusyState() async throws {
        try await withFixture { _, engine, _, server in
            let gates = SyncCycleResponseGates()
            server.setBeforeResponse { gates.wait() }
            defer { gates.old.release(); gates.current.release() }
            let oldSync = Task { await engine.syncAll() }
            while !gates.old.hasEntered { await Task.yield() }
            engine.resetResult()
            let currentSync = Task { await engine.syncAll() }
            while !engine.isSyncing { await Task.yield() }
            gates.old.release()
            while !gates.current.hasEntered { await Task.yield() }
            await oldSync.value
            #expect(engine.isSyncing && engine.lastResult == nil)
            gates.current.release()
            await currentSync.value
            #expect(!engine.isSyncing && engine.lastResult?.status == .success)
        }
    }
    @Test func sessionLogoutInvalidatesPendingPushBeforeDeletedModelsAreRead() async throws {
        try await withHTTPFixture { api, server, defaults in
            let container = AppModelContainer.make(inMemory: true)
            let context = container.mainContext
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults)
            let session = SessionStore(modelContext: context, profileDefaults: defaults)
            session.uitestInjectFakeSession()
            session.onSessionInvalidated = { engine.resetResult() }
            context.insert(Workout(title: "旧会话待传", exercises: [
                WorkoutExercise(exerciseName: "卧推", orderIndex: 0, sets: [WorkoutSet(setIndex: 0, reps: 8)])
            ]))
            try context.save()
            let gate = SyncResponseGate()
            server.setBeforeResponse(for: .workouts) { gate.waitForRelease() }
            defer { gate.release() }
            let oldSync = Task { await engine.syncAll() }
            while !gate.hasEntered { await Task.yield() }
            session.beginDeletedAccountCleanup()
            #expect(!engine.isSyncing)
            #expect(session.retryLocalCleanup())
            gate.release()
            await oldSync.value
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 0)
            #expect(engine.lastResult == nil && engine.pendingConflictNotices.isEmpty)
            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
        }
    }

    @Test(arguments: [false, true])
    func discardedPendingPushCannotRestoreOldSession(replacing: Bool) async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "discard-in-flight.store")
            let container = try makeStore(at: url)
            let context = container.mainContext
            let old = Workout(title: "上传途中丢弃", exercises: [
                WorkoutExercise(exerciseName: "卧推", orderIndex: 0, sets: [WorkoutSet(setIndex: 0, reps: 8)])
            ])
            old.updatedAt = Date(timeIntervalSince1970: 1_790_000_000.1236)
            context.insert(old)
            try context.save()
            let oldId = old.localId
            try #require(old.serverId == nil)
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults)
            let gate = SyncResponseGate()
            server.setBeforeResponse(for: .workouts) { gate.waitForRelease() }
            defer { gate.release() }
            let sync = Task { await engine.syncAll() }
            let deadline = ContinuousClock.now + .seconds(10)
            while !gate.hasEntered {
                try #require(ContinuousClock.now < deadline, "未进入训练上传响应闸门")
                await Task.yield()
            }
            var expectedIds: Set<UUID> = []
            if replacing {
                let replacement = try WorkoutSession.start({ Workout(title: "替换后的训练") },
                                                           replacing: old, in: context)
                expectedIds.insert(replacement.localId)
            } else {
                try WorkoutSession.discard(old, in: context)
            }
            gate.release()
            await sync.value
            for cycle in 0..<3 {
                if cycle > 0 { await engine.syncAll() }
                let reopened = try makeStore(at: url, allowsSave: false)
                let stored = try reopened.mainContext.fetch(FetchDescriptor<Workout>())
                let visible = stored.filter { $0.deletedAt == nil }
                #expect(!visible.contains { $0.localId == oldId })
                #expect(Set(visible.map(\.localId)) == expectedIds)
                if cycle == 0 {
                    let tombstone = try #require(stored.first { $0.localId == oldId })
                    #expect(tombstone.deletedAt != nil && tombstone.syncStatus == .pendingDelete)
                    #expect(tombstone.exercises.first?.sets.first?.reps == 8)
                } else {
                    #expect(!stored.contains { $0.localId == oldId })
                }
            }
            let remote: SyncPullResult<WorkoutTreeDTO> = try await api.send("GET", SyncDomain.workouts.pullPath)
            let deleted = try #require(remote.changes.first { $0.workout.id == oldId })
            #expect(deleted.workout.deletedAt != nil)
            #expect(engine.lastResult?.status == .success)
        }
    }

    @Test func unavailableSessionSkipsSyncAndValidSessionCanResume() async throws {
        try await withHTTPFixture { api, server, defaults in
            let container = AppModelContainer.make(inMemory: true)
            var available = false
            let engine = SyncEngine(modelContext: container.mainContext, api: api, watermarkDefaults: defaults,
                                    canSync: { available })
            server.seedWorkout()
            await engine.syncAll()
            #expect(engine.lastResult == nil && !engine.isSyncing)
            for domain in SyncDomain.allCases { #expect(server.pullSinceValues(for: domain.rawValue).isEmpty) }
            available = true
            await engine.syncAll()
            #expect(engine.lastResult?.status == .success)
            let count = try container.mainContext.fetchCount(FetchDescriptor<Workout>())
            #expect(count == 1)
        }
    }
    @Test func invalidatedPullCannotRefillClearedStoreOrCommitWatermarks() async throws {
        try await withHTTPFixture { api, server, defaults in
            let container = AppModelContainer.make(inMemory: true)
            let context = container.mainContext
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults)
            server.seedWorkout()
            let gate = SyncResponseGate()
            server.setBeforeResponse(for: .workouts) { gate.waitForRelease() }
            defer { gate.release() }
            let oldSync = Task { await engine.syncAll() }
            while !gate.hasEntered { await Task.yield() }
            engine.resetResult()
            try context.delete(model: Workout.self)
            try context.save()
            gate.release()
            await oldSync.value
            #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 0)
            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
            #expect(engine.lastResult == nil)
        }
    }
    @Test func partialFailureIsVisibleAndRetryReplacesItWithSuccess() async throws {
        try await withFixture { context, engine, _, server in
            let workout = Workout(title: "待重试训练")
            context.insert(workout)
            try context.save()
            server.setFailure(500, for: .workouts)

            await engine.syncAll()

            #expect(engine.lastResult?.status == .partialFailure)
            #expect(engine.lastResult?.recoveryHint?.contains("训练记录尚未同步") == true)
            #expect(engine.lastResult?.failedDomains == [.workouts])
            #expect(engine.lastResult?.localSaveSucceeded == true)
            #expect(workout.syncStatus == .pendingCreate)
            #expect(engine.lastResult?.recoveryHint != nil)
            server.setFailure(nil, for: .workouts)

            await engine.syncAll()

            #expect(engine.lastResult?.status == .success)
            #expect(engine.lastResult?.recoveryHint == nil)
            #expect(workout.syncStatus == .synced)
            #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
        }
    }

    @Test func allDomainsFailWithoutPretendingToSucceed() async throws {
        try await withFixture { _, engine, _, server in
            for domain in SyncDomain.allCases { server.setFailure(503, for: domain) }
            await engine.syncAll()
            #expect(engine.lastResult?.status == .failure)
            #expect(engine.lastResult?.failedDomains == SyncDomain.allCases)
        }
    }

    @Test func oldSyncCannotPublishResultAfterSessionReset() async throws {
        try await withFixture { _, engine, _, server in
            let gate = SyncResponseGate()
            server.setBeforeResponse { gate.waitForRelease() }
            defer { gate.release() }
            let oldSync = Task { await engine.syncAll() }
            while !gate.hasEntered { await Task.yield() }
            engine.resetResult()
            gate.release()
            await oldSync.value
            #expect(engine.lastResult == nil)

            await engine.syncAll()
            #expect(engine.lastResult?.status == .success)
        }
    }

    @Test(arguments: [false, true])
    func unauthorizedResponseOnlyExpiresTheRequestSession(tokenChanges: Bool) async throws {
        try await withHTTPFixture { api, server, _ in
            let state = SyncTokenState()
            await api.setTokenProvider { state.token }
            await api.setUnauthorizedHandler { state.recordUnauthorized() }
            server.setFailure(401, for: .workouts)
            if tokenChanges { server.setBeforeResponse { state.replaceToken() } }
            do {
                try await api.sendVoid("GET", SyncDomain.workouts.pullPath)
                Issue.record("401 应抛出会话失效")
            } catch APIError.unauthorized {
                #expect(state.unauthorizedCount == (tokenChanges ? 0 : 1))
            }
        }
    }

    /// 1.1(5) 结束训练闪退回归：毫秒编码四舍五入后，刚推送的训练被原样拉回时「看起来更新」，
    /// 曾触发 replaceChildren 删除整棵子树，与后台勋章读取并发即 SwiftData 断言崩溃。
    @Test func echoedPushWithRoundedUpTimestampKeepsLocalChildren() async throws {
        try await withFixture { context, engine, _, _ in
            let workout = Workout(title: "同步回声回归")
            let exercise = WorkoutExercise(exerciseName: "卧推", orderIndex: 0)
            exercise.sets = [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true)]
            workout.exercises = [exercise]
            // .1236 编码为 .124，回传后比本地晚 0.4ms。
            workout.updatedAt = Date(timeIntervalSince1970: 1_790_000_000.1236)
            context.insert(workout)
            try context.save()
            let exerciseIds = workout.exercises.map(\.persistentModelID)
            let setIds = workout.exercises.flatMap(\.sets).map(\.persistentModelID)

            await engine.syncAll()

            #expect(workout.syncStatus == .synced)
            #expect(workout.exercises.map(\.persistentModelID) == exerciseIds)
            #expect(workout.exercises.flatMap(\.sets).map(\.persistentModelID) == setIds)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == setIds.count)
        }
    }

    @Test func syncClockIgnoresSubMillisecondTransportRounding() throws {
        let local = Date(timeIntervalSince1970: 1_790_000_000.1236)
        let echoed = try #require(JSONCoding.date(from: JSONCoding.string(from: local)))
        #expect(echoed > local)
        #expect(!SyncClock.isNewer(echoed, than: local))
        #expect(SyncClock.isNewer(local.addingTimeInterval(0.002), than: local))
    }

    @Test func newLocalStorePullsHistoryInsteadOfReusingPreviousStoreWatermark() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            server.seedWorkout()
            let first = try makeStore(at: directory.appending(path: "first.store"))
            await SyncEngine(modelContext: first.mainContext, api: api, watermarkDefaults: defaults).syncAll()
            #expect(try first.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            #expect(SyncDomain.workouts.watermark(in: defaults) != nil)

            let replacement = try makeStore(at: directory.appending(path: "replacement.store"))
            await SyncEngine(modelContext: replacement.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            #expect(try replacement.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            #expect(server.pullSinceValues(for: "workouts") == [nil, nil])
        }
    }

    @Test func sameLocalStoreKeepsIncrementalWatermarkAcrossEngineRestarts() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            server.seedWorkout()
            let store = try makeStore(at: directory.appending(path: "history.store"))
            await SyncEngine(modelContext: store.mainContext, api: api, watermarkDefaults: defaults).syncAll()
            await SyncEngine(modelContext: store.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            #expect(try store.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            let requests = server.pullSinceValues(for: "workouts")
            try #require(requests.count == 2)
            #expect(requests[0] == nil)
            #expect(requests[1] != nil)
        }
    }

    @Test func legacyWatermarkWithoutStoreIdentityCannotSkipRestoringHistory() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            server.seedWorkout()
            for domain in SyncDomain.allCases { domain.setWatermark(.now, in: defaults) }
            let store = try makeStore(at: directory.appending(path: "empty.store"))

            await SyncEngine(modelContext: store.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            #expect(try store.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            #expect(server.pullSinceValues(for: "workouts") == [nil])
        }
    }

    @Test func failedLocalSaveDoesNotAdvancePullWatermarks() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "readonly.store")
            let writable = try makeStore(at: url)
            try writable.mainContext.save()
            server.seedWorkout()
            let readonly = try makeStore(at: url, allowsSave: false)

            await SyncEngine(modelContext: readonly.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
            withExtendedLifetime(writable) {}
        }
    }

    @Test func localSaveFailureIsReportedSeparatelyFromNetwork() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "readonly-feedback.store")
            let writable = try makeStore(at: url)
            try writable.mainContext.save()
            server.seedWorkout()
            let readonly = try makeStore(at: url, allowsSave: false)
            let engine = SyncEngine(modelContext: readonly.mainContext, api: api, watermarkDefaults: defaults)

            await engine.syncAll()

            #expect(engine.lastResult?.status == .localSaveFailed)
            #expect(engine.lastResult?.localSaveSucceeded == false)
            #expect(engine.lastResult?.recoveryHint?.contains("尚未完成") == true)
            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
            withExtendedLifetime(writable) {}
        }
    }

    @Test(arguments: [false, true])
    func batchesCommitCompleteWorkoutTrees(longWorkout: Bool) async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "batches.store"))
            let context = ModelContext(container)
            let exercises = longWorkout ? 20 : 6
            let sets = longWorkout ? 5 : 4
            server.seedWorkouts(count: 9, exercisesPerWorkout: exercises, setsPerExercise: sets)
            var savedCounts: [Int] = []
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults, save: {
                try context.save()
                let persisted = try ModelContext(container).fetch(FetchDescriptor<Workout>())
                savedCounts.append(persisted.count)
                for workout in persisted {
                    #expect(workout.exercises.count == exercises)
                    #expect(workout.exercises.allSatisfy { $0.sets.count == sets })
                }
            })

            await engine.syncAll()

            #expect(savedCounts.contains { $0 > 0 && $0 < 9 })
            #expect(savedCounts.last == 9)
            #expect(engine.lastResult?.status == .success)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 9 * exercises)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 9 * exercises * sets)
            for set in try context.fetch(FetchDescriptor<WorkoutSet>()) {
                #expect(set.completed && set.weightKg == 60 && set.reps == 10)
                #expect(set.plannedRestSeconds == 90 && set.actualRestSeconds == 60)
            }
        }
    }

    @Test func batchSaveFailureRemainsVisibleWhenFinalSaveRecoversAndReplayIsIdempotent() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "retry.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 32)
            let notifications = SyncSuccessCounter()
            let observer = NotificationCenter.default.addObserver(
                forName: .dontliftWorkoutSyncSucceeded, object: nil, queue: nil) { _ in notifications.record() }
            defer { NotificationCenter.default.removeObserver(observer) }
            var saves = 0
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults, save: {
                saves += 1
                if saves == 2 { throw SyncBatchSaveError.injected }
                try context.save()
            })

            await engine.syncAll()

            #expect(saves >= 3)
            #expect(engine.lastResult?.status == .localSaveFailed)
            #expect(engine.lastResult?.failedDomains == [.workouts])
            #expect(engine.lastResult?.localSaveSucceeded == false)
            #expect(notifications.count == 0)
            let partialCount = try ModelContext(container).fetchCount(FetchDescriptor<Workout>())
            #expect(partialCount > 0 && partialCount < 32)
            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }

            await engine.syncAll()

            #expect(engine.lastResult?.status == .success && notifications.count == 1)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 32)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 32 * 6)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 32 * 24)
            let childIds = Set(try context.fetch(FetchDescriptor<WorkoutSet>()).map(\.localId))
            for domain in SyncDomain.allCases { domain.setWatermark(nil, in: defaults) }
            await engine.syncAll()
            #expect(engine.lastResult?.status == .success && notifications.count == 2)
            #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 32)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 32 * 6)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 32 * 24)
            #expect(Set(try context.fetch(FetchDescriptor<WorkoutSet>()).map(\.localId)) == childIds)
        }
    }

    @Test func invalidatedBatchCannotRefillStoreAfterQueuedCleanup() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "cleanup.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 32)
            let notifications = SyncSuccessCounter()
            let observer = NotificationCenter.default.addObserver(
                forName: .dontliftWorkoutSyncSucceeded, object: nil, queue: nil) { _ in notifications.record() }
            defer { NotificationCenter.default.removeObserver(observer) }
            weak var currentEngine: SyncEngine?
            var firstSavedCount: Int?
            var cleanup: Task<Void, Error>?
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults, save: {
                try context.save()
                if firstSavedCount == nil {
                    firstSavedCount = try ModelContext(container).fetchCount(FetchDescriptor<Workout>())
                    cleanup = Task { @MainActor in
                        currentEngine?.resetResult()
                        try context.delete(model: Workout.self)
                        try context.save()
                    }
                }
            })
            currentEngine = engine

            await engine.syncAll()
            if let cleanup { try await cleanup.value }

            let count = try #require(firstSavedCount)
            #expect(count > 0 && count < 32)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
            #expect(engine.lastResult == nil && !engine.isSyncing && notifications.count == 0)
            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
        }
    }

    @Test func oldBatchCompletionCannotClearNewCycleBusyState() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "new-cycle.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 32)
            let gate = SyncResponseGate()
            defer { gate.release() }
            weak var currentEngine: SyncEngine?
            var replacement: Task<Void, Never>?
            var currentSync: Task<Void, Never>?
            var firstSavedCount: Int?
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults, save: {
                try context.save()
                if firstSavedCount == nil {
                    firstSavedCount = try ModelContext(container).fetchCount(FetchDescriptor<Workout>())
                    replacement = Task { @MainActor in
                        currentEngine?.resetResult()
                        server.setBeforeResponse(for: .workouts) { gate.waitForRelease() }
                        currentSync = Task { await currentEngine?.syncAll() }
                    }
                }
            })
            currentEngine = engine
            let oldSync = Task { await engine.syncAll() }
            await oldSync.value
            if let replacement { await replacement.value }
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while !gate.hasEntered && ContinuousClock.now < deadline { await Task.yield() }
            try #require(gate.hasEntered)
            let count = try #require(firstSavedCount)
            #expect(count > 0 && count < 32)
            #expect(engine.isSyncing && engine.lastResult == nil)
            gate.release()
            if let currentSync { await currentSync.value }
            #expect(!engine.isSyncing && engine.lastResult?.status == .success)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 32)
        }
    }

    @Test(arguments: [false, true])
    func queuedLocalEditBetweenBatchesKeepsPendingInputAndOriginalChildren(remoteDeleted: Bool) async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "editing.store"))
            let context = ModelContext(container)
            let count = 65
            server.seedWorkouts(count: count, lastDeleted: remoteDeleted)
            let request = URLRequest(url: try #require(URL(string: "https://fixture.invalid/sync/workouts/pull")))
            let response = try server.respond(request)
            let pull = try JSONCoding.decoder.decode(SyncPullResult<WorkoutTreeDTO>.self, from: response.1)
            let remote = try #require(pull.changes.last?.workout)
            let exercise = WorkoutExercise(exerciseName: "本地动作", orderIndex: 0,
                                           sets: [WorkoutSet(setIndex: 0, weightKg: 42, reps: 7)])
            let local = Workout(localId: remote.id, title: "编辑前", exercises: [exercise],
                                now: remote.updatedAt.addingTimeInterval(-120))
            local.serverId = remote.id
            local.syncStatus = .synced
            context.insert(local)
            try context.save()
            let exerciseId = exercise.localId
            let setId = try #require(exercise.sets.first?.localId)
            var edit: Task<Void, Error>?
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults, save: {
                try context.save()
                if edit == nil {
                    edit = Task { @MainActor in
                        local.title = "批次之间输入"
                        local.updatedAt = remote.updatedAt.addingTimeInterval(-30)
                        local.syncStatus = .pendingUpdate
                        try context.save()
                    }
                }
            })

            await engine.syncAll()
            if let edit { try await edit.value }

            #expect(engine.lastResult?.status == .success)
            let localId = remote.id
            let retained = try ModelContext(container).fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.localId == localId }))
            try #require(retained.count == 1, "远端墓碑不能抢先删除批次之间产生的待推送输入")
            #expect(local.title == "批次之间输入" && local.syncStatus == .pendingUpdate)
            #expect(local.exercises.map(\.localId) == [exerciseId])
            #expect(local.exercises.flatMap(\.sets).map(\.localId) == [setId])
            #expect(local.exercises.first?.sets.first?.weightKg == 42)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == count)
        }
    }

    @Test func serverTombstoneRemovesSyncedWorkoutChildren() async throws {
        try await withFixture { context, engine, _, server in
            server.seedWorkouts(count: 1, lastDeleted: true)
            let request = URLRequest(url: try #require(URL(string: "https://fixture.invalid/sync/workouts/pull")))
            let response = try server.respond(request)
            let pull = try JSONCoding.decoder.decode(SyncPullResult<WorkoutTreeDTO>.self, from: response.1)
            let remote = try #require(pull.changes.first?.workout)
            let local = Workout(localId: remote.id, title: "已同步的待删除训练", exercises: [
                WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推", orderIndex: 0,
                                sets: [WorkoutSet(setIndex: 0, weightKg: 60, reps: 10, completed: true)])
            ], now: remote.updatedAt)
            local.serverId = remote.id
            local.syncStatus = .synced
            context.insert(local)
            try context.save()

            await engine.syncAll()

            #expect(engine.lastResult?.status == .success)
            let reader = ModelContext(context.container)
            #expect(try reader.fetchCount(FetchDescriptor<Workout>()) == 0)
            #expect(try reader.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
            #expect(try reader.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
        }
    }

    @Test(arguments: ["warmup", "drop", "future-type"])
    func updatedWorkoutReconcilesChildrenAndAllSetFields(setType: String) async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "updated-children.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 1, exercisesPerWorkout: 2, setsPerExercise: 3)
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults)
            await engine.syncAll()
            try #require(engine.lastResult?.status == .success)
            let remote: SyncPullResult<WorkoutTreeDTO> = try await api.send("GET", SyncDomain.workouts.pullPath)
            var tree = try #require(remote.changes.first)
            var exercise = try #require(tree.exercises.first)
            var set = try #require(exercise.sets.first)
            set.setIndex = 5
            set.weightKg = nil; set.reps = nil; set.completed = nil
            set.note = "同步后的组备注"
            set.plannedRestSeconds = 45; set.actualRestSeconds = 32
            set.setType = setType; set.isWarmup = false
            set.segments = "[{\"segmentId\":\"\(UUID())\",\"segmentIndex\":0,\"weightKg\":50,\"reps\":8}]"
            var addedSet = set
            addedSet.id = UUID(); addedSet.setIndex = 6
            exercise.exercise.exerciseName = "更新后的动作"
            exercise.exercise.note = "同步后的动作备注"
            exercise.exercise.planItemId = UUID()
            exercise.sets = [set, addedSet]
            var addedExercise = exercise
            addedExercise.exercise.id = UUID(); addedExercise.exercise.orderIndex = 1
            addedExercise.sets = []
            tree.exercises = [exercise, addedExercise]
            tree.workout.updatedAt = tree.workout.updatedAt.addingTimeInterval(1)
            tree.workout.version = 2
            try server.replaceWorkout(tree)
            SyncDomain.workouts.setWatermark(nil, in: defaults)

            await engine.syncAll()

            try #require(engine.lastResult?.status == .success)
            let reader = ModelContext(container)
            let stored = try #require(reader.fetch(FetchDescriptor<Workout>()).first)
            #expect(Set(stored.exercises.map(\.localId)) == Set(tree.exercises.map { $0.exercise.id }))
            #expect(try reader.fetchCount(FetchDescriptor<WorkoutExercise>()) == 2)
            #expect(try reader.fetchCount(FetchDescriptor<WorkoutSet>()) == 2)
            let retained = try #require(stored.exercises.first { $0.localId == exercise.exercise.id })
            #expect(retained.exerciseName == exercise.exercise.exerciseName)
            #expect(retained.note == exercise.exercise.note && retained.planItemId == exercise.exercise.planItemId)
            #expect(Set(retained.sets.map(\.localId)) == Set(exercise.sets.map(\.id)))
            for storedSet in retained.sets {
                #expect(storedSet.setIndex == (storedSet.localId == set.id ? 5 : 6))
                #expect(storedSet.weightKg == (setType == "drop" ? 50 : nil))
                #expect(storedSet.reps == (setType == "drop" ? 8 : nil))
                #expect(!storedSet.completed && storedSet.note == set.note)
                #expect(storedSet.plannedRestSeconds == 45 && storedSet.actualRestSeconds == 32)
                #expect(storedSet.setType == (setType == "drop" ? .drop : .working))
                #expect(storedSet.isWarmupEffective == (setType == "warmup"))
                #expect(storedSet.segments.count == 1 && storedSet.segments.first?.weightKg == 50)
            }
        }
    }

    @Test func concurrentWorkoutReplacementKeepsSnapshotReadersValid() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "concurrent-readers.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 64)
            let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults)
            await engine.syncAll()
            try #require(engine.lastResult?.status == .success)
            let reading = Task.detached {
                var counts: [Int] = []
                var complete = true
                var examples: [String] = []
                for iteration in 0..<30 {
                    // 每轮新建读取器，区分跨执行器删除竞争与复用旧 context 的缓存问题。
                    let badges = try await BadgeHistoryReader(modelContainer: container).readWorkouts()
                    let history = try await WorkoutHistoryReader(modelContainer: container).read()
                    counts += [badges.count, history.count]
                    let completeBadges = await MainActor.run {
                        badges.allSatisfy { $0.exercises.count == 6 && $0.exercises.allSatisfy { $0.sets.count == 4 } }
                    }
                    let completeHistory = history.allSatisfy {
                        $0.exercises.count == 6 && $0.exercises.allSatisfy { $0.sets.count == 4 }
                    }
                    complete = complete && completeBadges && completeHistory
                    if (!completeBadges || !completeHistory) && examples.count < 6 {
                        let badgeExamples = await MainActor.run {
                            badges.filter { $0.exercises.count != 6 || $0.exercises.contains { $0.sets.count != 4 } }
                                .prefix(2).map { "badge:\(iteration):\($0.id) ex=\($0.exercises.count) sets=\($0.exercises.map { $0.sets.count })" }
                        }
                        let historyExamples = history.filter {
                            $0.exercises.count != 6 || $0.exercises.contains { $0.sets.count != 4 }
                        }.prefix(2).map { "history:\(iteration):\($0.localId) ex=\($0.exercises.count) sets=\($0.exercises.map { $0.sets.count })" }
                        examples += Array((badgeExamples + historyExamples).prefix(6 - examples.count))
                    }
                }
                return (counts, complete, examples)
            }
            defer { reading.cancel() }
            for revision in 1...10 {
                server.reviseWorkouts(revision: revision)
                SyncDomain.workouts.setWatermark(nil, in: defaults)
                await engine.syncAll()
                #expect(engine.lastResult?.status == .success)
            }
            let result = try await reading.value
            #expect(result.0.count == 60 && result.0.allSatisfy { $0 == 64 })
            #expect(result.1, "\(result.2)")
            let finalHistory = try await WorkoutHistoryReader(modelContainer: container).read()
            #expect(finalHistory.count == 64)
            #expect(finalHistory.allSatisfy {
                $0.exercises.count == 6 && $0.exercises.allSatisfy { $0.sets.count == 4 }
            }, "并发写入结束后的新读取器也必须得到完整聚合")
        }
    }

    @Test func snapshotValuesSurviveRootsDeletedBetweenCaptureWindows() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "snapshot-cleanup.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 64)
            await SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults).syncAll()
            var clearing: Task<Void, Error>?
            let snapshots: [HistoryWorkout] = try await WorkoutSnapshotCapture.read(
                from: container, completedOnly: false, order: .forward) { workout in
                    if clearing == nil {
                        clearing = Task { @MainActor in
                            try context.delete(model: Workout.self)
                            try context.save()
                        }
                    }
                    return HistoryWorkout(workout)
                }
            if let clearing { try await clearing.value }
            #expect(!snapshots.isEmpty && snapshots.count < 64)
            #expect(Set(snapshots.map(\.localId)).count == snapshots.count)
            #expect(snapshots.allSatisfy {
                $0.exercises.count == 6 && $0.exercises.allSatisfy { $0.sets.count == 4 }
            })
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 0)
            #expect(try await WorkoutHistoryReader(modelContainer: container).read().isEmpty)
        }
    }

    @Test func cancelledSnapshotStopsBeforeNextCaptureWindow() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let container = try makeStore(at: directory.appending(path: "cancelled-snapshot.store"))
            let context = ModelContext(container)
            server.seedWorkouts(count: 64)
            await SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults).syncAll()
            let reading = Task { @MainActor in
                var copied = 0
                do {
                    let _: [UUID] = try await WorkoutSnapshotCapture.read(
                        from: container, completedOnly: false, order: .forward) { workout in
                            copied += 1
                            withUnsafeCurrentTask { $0?.cancel() }
                            return workout.localId
                        }
                    return (false, copied)
                } catch is CancellationError {
                    return (true, copied)
                }
            }
            let result = try await reading.value
            #expect(result.0 && result.1 > 0 && result.1 < 64)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == 64)
            #expect(try await WorkoutHistoryReader(modelContainer: container).read().count == 64)
        }
    }

    private func makeStoreDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "SyncHistoryRegression-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeStore(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                        allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: AppModelContainer.schema, configurations: [config])
    }

    /// 隔离 HTTP/SQLite 临时库的批量下拉探针。调度间隔不是触摸到屏幕的延迟或帧指标。
    @Test func workoutPullPerformanceProbe() async throws {
        try #require(UITestHooks.isFinishFlowUITest, "同步采样需使用隔离内存宿主参数")
        let environment = ProcessInfo.processInfo.environment
        let count = try #require(Int(environment["DONTLIFT_SYNC_WORKOUT_COUNT"] ?? "10"))
        let iterations = try #require(Int(environment["DONTLIFT_SYNC_ITERATIONS"] ?? "1"))
        let exercises = try #require(Int(environment["DONTLIFT_SYNC_EXERCISES"] ?? "6"))
        let sets = try #require(Int(environment["DONTLIFT_SYNC_SETS"] ?? "4"))
        let updating = environment["DONTLIFT_SYNC_MODE"] == "update"
        try #require(count >= 0 && iterations > 0 && exercises > 0 && sets > 0)
        for iteration in 0..<iterations {
            let storeDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("dontlift-sync-store-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            defer {
                if environment["DONTLIFT_SYNC_CAPTURE"] != "1" {
                    try? FileManager.default.removeItem(at: storeDirectory)
                }
            }
            try await withHTTPFixture { api, server, defaults in
                server.seedWorkouts(count: count, exercisesPerWorkout: exercises, setsPerExercise: sets)
                let configuration = ModelConfiguration(schema: AppModelContainer.schema,
                    url: storeDirectory.appendingPathComponent("SyncProbe.store"), cloudKitDatabase: .none)
                let container = try ModelContainer(for: AppModelContainer.schema, configurations: [configuration])
                let context = ModelContext(container)
                var saveTimes: [Double] = []
                let engine = SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults, save: {
                    let start = ContinuousClock.now
                    try context.save()
                    saveTimes.append(syncProbeMilliseconds(start.duration(to: .now)))
                })
                if updating {
                    await engine.syncAll()
                    try #require(engine.lastResult?.status == .success)
                    server.reviseWorkouts()
                    SyncDomain.workouts.setWatermark(nil, in: defaults)
                    saveTimes = []
                }
                let captureDirectory: URL?
                if environment["DONTLIFT_SYNC_CAPTURE"] == "1" {
                    let directory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("dontlift-sync-probe-" + UUID().uuidString)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let ready: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier,
                                              "workouts": count, "iteration": iteration,
                                              "store_url": configuration.url.path]
                    try JSONSerialization.data(withJSONObject: ready).write(to: directory.appendingPathComponent("ready.json"))
                    try await waitForSyncProbeSignal("go", in: directory)
                    captureDirectory = directory
                } else { captureDirectory = nil }

                var lastTick = ContinuousClock.now
                var gaps: [Double] = []
                let heartbeat = Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(5))
                        guard !Task.isCancelled else { break }
                        let now = ContinuousClock.now
                        gaps.append(syncProbeMilliseconds(lastTick.duration(to: now)))
                        lastTick = now
                    }
                }
                let start = ContinuousClock.now
                await engine.syncAll()
                let end = ContinuousClock.now
                gaps.append(syncProbeMilliseconds(lastTick.duration(to: end)))
                heartbeat.cancel()
                await heartbeat.value
                let result: [String: Any] = ["workouts": count, "iteration": iteration, "store": "sqlite",
                    "mode": updating ? "update" : "restore", "exercises_per_workout": exercises,
                    "sets_per_exercise": sets, "save_ms": saveTimes,
                    "elapsed_ms": syncProbeMilliseconds(start.duration(to: end)),
                    "main_actor_gap_ms": gaps, "max_main_actor_gap_ms": gaps.max() ?? 0]
                let resultData = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
                print("[S4-sync-pull] " + String(decoding: resultData, as: UTF8.self))
                #expect(engine.lastResult?.status == .success)
                #expect(try context.fetchCount(FetchDescriptor<Workout>()) == count)
                #expect(try context.fetchCount(FetchDescriptor<WorkoutExercise>()) == count * exercises)
                #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == count * exercises * sets)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Workout>()) == count)
                #expect(SyncDomain.workouts.watermark(in: defaults) != nil)
                if updating {
                    #expect(try context.fetch(FetchDescriptor<Workout>()).allSatisfy { $0.version == 2 })
                    #expect(try context.fetch(FetchDescriptor<WorkoutSet>()).allSatisfy { $0.reps == 11 })
                }
                if let captureDirectory {
                    try resultData.write(to: captureDirectory.appendingPathComponent("result.json"))
                    try await waitForSyncProbeSignal("stop", in: captureDirectory)
                }
                withExtendedLifetime(container) {}
            }
        }
    }

    private func syncProbeMilliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
    }

    private func waitForSyncProbeSignal(_ name: String, in directory: URL) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            try #require(ContinuousClock.now < deadline, "等待同步采样信号超时：\(name)")
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func withFixture(
        _ operation: (ModelContext, SyncEngine, APIClient, SyncCrashHTTPFixture) async throws -> Void) async throws {
        try await withHTTPFixture { api, server, defaults in
            let container = AppModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            try await operation(context, SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults), api, server)
            withExtendedLifetime(container) {}
        }
    }

    private func withHTTPFixture(
        _ operation: (APIClient, SyncCrashHTTPFixture, UserDefaults) async throws -> Void) async throws {
        let suite = "SyncCrashRegressionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let host = UUID().uuidString.lowercased() + ".invalid"
        let server = SyncCrashHTTPFixture()
        SyncCrashHTTPRegistry.shared.register(server, host: host)
        defer { SyncCrashHTTPRegistry.shared.remove(host) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncCrashURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = APIClient(baseURL: try #require(URL(string: "https://" + host)), session: session)
        try await operation(api, server, defaults)
    }
}

nonisolated private final class SyncCrashHTTPFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: [[String: Any]]] = [:]
    private var pullSince: [String: [String?]] = [:]
    private var failureStatuses: [String: Int] = [:]
    private var beforeResponse: (@Sendable () -> Void)?
    private var beforeResponseDomain: String?

    func setFailure(_ status: Int?, for domain: SyncDomain) {
        lock.lock()
        defer { lock.unlock() }
        failureStatuses[domain.rawValue] = status
    }

    func setBeforeResponse(for domain: SyncDomain? = nil, _ action: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        beforeResponse = action
        beforeResponseDomain = domain?.rawValue
    }

    func seedWorkout() {
        lock.lock()
        defer { lock.unlock() }
        items["workouts"] = [["workout": [
            "id": UUID().uuidString, "title": "待恢复历史", "version": 1,
            "startedAt": "2026-06-01T08:00:00.000Z",
            "endedAt": "2026-06-01T09:00:00.000Z",
            "updatedAt": "2026-06-01T09:00:00.000Z"
        ], "exercises": []]]
    }

    func seedWorkouts(count: Int, exercisesPerWorkout: Int = 6, setsPerExercise: Int = 4, lastDeleted: Bool = false) {
        let roots: [[String: Any]] = (0..<count).map { index in
            let workoutId = UUID().uuidString
            let exercises: [[String: Any]] = (0..<exercisesPerWorkout).map { exerciseIndex in
                let exerciseId = UUID().uuidString
                let sets: [[String: Any]] = (0..<setsPerExercise).map { setIndex in
                    ["id": UUID().uuidString, "workoutExerciseId": exerciseId, "setIndex": setIndex,
                     "weightKg": 60, "reps": 10, "completed": true, "setType": "working",
                     "plannedRestSeconds": 90, "actualRestSeconds": 60, "segments": "[]"]
                }
                return ["exercise": ["id": exerciseId, "workoutId": workoutId,
                    "builtinExerciseCode": "BB_BENCH_PRESS", "exerciseName": "杠铃卧推",
                    "orderIndex": exerciseIndex], "sets": sets]
            }
            var workout: [String: Any] = ["id": workoutId, "title": "同步性能历史 \(index)", "version": 1,
                "startedAt": "2026-06-01T08:00:00.000Z", "endedAt": "2026-06-01T09:00:00.000Z",
                "updatedAt": "2026-06-01T09:00:00.000Z"]
            if lastDeleted && index == count - 1 { workout["deletedAt"] = "2026-06-01T09:00:00.000Z" }
            return ["workout": workout, "exercises": exercises]
        }
        lock.withLock { items["workouts"] = roots }
    }

    func pullSinceValues(for domain: String) -> [String?] {
        lock.lock()
        defer { lock.unlock() }
        return pullSince[domain] ?? []
    }

    func reviseWorkouts(revision: Int = 0) {
        lock.withLock {
            items["workouts"] = (items["workouts"] ?? []).map { item in
                var revised = item
                var workout = item["workout"] as? [String: Any] ?? [:]
                workout["updatedAt"] = Date(timeIntervalSince1970: 1_780_390_800 + Double(revision))
                    .ISO8601Format(.init(includingFractionalSeconds: true))
                workout["version"] = 2 + revision
                revised["workout"] = workout
                revised["exercises"] = (item["exercises"] as? [[String: Any]] ?? []).map { exercise in
                    var node = exercise
                    node["sets"] = (exercise["sets"] as? [[String: Any]] ?? []).map { set in
                        var updated = set
                        updated["reps"] = 11
                        return updated
                    }
                    return node
                }
                return revised
            }
        }
    }

    func replaceWorkout(_ tree: WorkoutTreeDTO) throws {
        let object = try JSONSerialization.jsonObject(with: JSONCoding.encoder.encode(tree))
        let item = try #require(object as? [String: Any])
        lock.withLock { items["workouts"] = [item] }
    }

    func respond(_ request: URLRequest) throws -> (Int, Data) {
        lock.lock()
        defer { lock.unlock() }
        let path = request.url?.path ?? ""
        let body = Self.body(request)
        let domain = path.split(separator: "/").dropFirst().first.map(String.init) ?? ""
        if beforeResponseDomain == nil || beforeResponseDomain == domain { beforeResponse?() }
        if let status = failureStatuses[domain] {
            return (status, Data("{\"detail\":\"fixture failure\"}".utf8))
        }
        let time = Date().ISO8601Format(.init(includingFractionalSeconds: true))
        if path.hasSuffix("/pull") {
            let since = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "since" }?.value
            pullSince[domain, default: []].append(since)
            let changes = (items[domain] ?? []).filter { item in
                guard let since else { return true }
                let root = item["workout"] as? [String: Any] ?? item
                return (root["updatedAt"] as? String).map { $0 > since } ?? false
            }
            return (200, try JSONSerialization.data(withJSONObject: ["changes": changes, "serverTime": time]))
        }
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let incoming = object?["items"] as? [[String: Any]] ?? []
        items[domain] = incoming
        let ids = incoming.compactMap { ($0["id"] ?? ($0["workout"] as? [String: Any])?["id"]) as? String }
        return (200, try JSONSerialization.data(withJSONObject: ["applied": ids, "conflicts": [], "serverTime": time]))
    }

    private static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

private enum SyncBatchSaveError: Error { case injected }

nonisolated private final class SyncSuccessCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func record() { lock.withLock { value += 1 } }
}

nonisolated private final class SyncResponseGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var entered = false
    private var released = false

    var hasEntered: Bool {
        condition.lock()
        defer { condition.unlock() }
        return entered
    }

    func waitForRelease() {
        condition.lock()
        defer { condition.unlock() }
        entered = true
        while !released { condition.wait() }
    }

    func release() {
        condition.lock()
        defer { condition.unlock() }
        released = true
        condition.broadcast()
    }
}

nonisolated private final class SyncCycleResponseGates: @unchecked Sendable {
    let old = SyncResponseGate()
    let current = SyncResponseGate()
    private let lock = NSLock()
    private var count = 0

    func wait() {
        let index = lock.withLock { count += 1; return count }
        if index == 1 { old.waitForRelease() }
        if index == 2 { current.waitForRelease() }
    }
}

nonisolated private final class SyncTokenState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = "old-token"
    private var count = 0

    var token: String { lock.withLock { value } }
    var unauthorizedCount: Int { lock.withLock { count } }
    func replaceToken() { lock.withLock { value = "new-token" } }
    func recordUnauthorized() { lock.withLock { count += 1 } }
}

nonisolated private final class SyncCrashHTTPRegistry: @unchecked Sendable {
    static let shared = SyncCrashHTTPRegistry()
    private let lock = NSLock()
    private var fixtures: [String: SyncCrashHTTPFixture] = [:]
    func register(_ fixture: SyncCrashHTTPFixture, host: String) { lock.lock(); defer { lock.unlock() }; fixtures[host] = fixture }
    func remove(_ host: String) { lock.lock(); defer { lock.unlock() }; fixtures.removeValue(forKey: host) }
    func fixture(_ host: String) -> SyncCrashHTTPFixture? { lock.lock(); defer { lock.unlock() }; return fixtures[host] }
}

nonisolated private final class SyncCrashURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host.flatMap { SyncCrashHTTPRegistry.shared.fixture($0) } != nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let url = request.url, let host = url.host, let server = SyncCrashHTTPRegistry.shared.fixture(host),
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else { return }
            let (status, data) = try server.respond(request)
            let actual = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) ?? response
            client?.urlProtocol(self, didReceive: actual, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
