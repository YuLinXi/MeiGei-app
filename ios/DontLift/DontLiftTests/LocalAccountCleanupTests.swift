import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct LocalAccountCleanupTests {
    private struct SaveFailure: Error {}

    @Test func failedCleanupSurvivesRestartBlocksLoginAndRetryClearsEveryModel() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let suite = "AccountCleanupRetry.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let originalToken = Keychain.get("jwt")
        defer {
            defaults.removePersistentDomain(forName: suite)
            if let originalToken { Keychain.set(originalToken, for: "jwt") }
        }
        let session = SessionStore(modelContext: context, profileDefaults: defaults)
        session.uitestInjectFakeSession()
        context.insert(CustomExercise(name: "原动作"))
        context.insert(WorkoutPlanGroup(name: "原分组", sortOrder: 0))
        context.insert(WorkoutPlan(name: "原计划"))
        context.insert(Workout(exercises: [WorkoutExercise(exerciseName: "卧推", orderIndex: 0,
                                                          sets: [WorkoutSet(setIndex: 0, reps: 8)])]))
        context.insert(BadgeGrant(badgeCode: "test.cleanup"))
        try context.save()
        for domain in SyncDomain.allCases { domain.setWatermark(.now, in: defaults) }
        defaults.set(true, forKey: "profile.pushPending")

        session.beginDeletedAccountCleanup()
        #expect(session.requiresLocalCleanup && !session.isLoggedIn)
        #expect(!session.retryLocalCleanup(persist: { _ in throw SaveFailure() }))
        #expect(session.localCleanupFailed && defaults.bool(forKey: SessionStore.localCleanupPendingKey))
        for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) != nil) }

        let restarted = SessionStore(modelContext: ModelContext(container), profileDefaults: defaults)
        #expect(restarted.requiresLocalCleanup && !restarted.isLoggedIn)
        restarted.uitestInjectFakeSession()
        await restarted.handleLogin(.init(token: "blocked", userId: UUID(), newUser: false),
                                    appleSub: nil, email: nil, displayName: nil)
        #expect(!restarted.isLoggedIn && restarted.currentUserId == nil)
        #expect(restarted.ensureProfile() == nil)
        #expect(restarted.retryLocalCleanup())
        #expect(!restarted.requiresLocalCleanup && !restarted.localCleanupFailed)
        #expect(!defaults.bool(forKey: SessionStore.localCleanupPendingKey))
        #expect(!defaults.bool(forKey: "profile.pushPending"))
        for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
        let reread = ModelContext(container)
        #expect(try reread.fetchCount(FetchDescriptor<UserProfile>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<CustomExercise>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<WorkoutPlanGroup>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<WorkoutPlan>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<Workout>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<WorkoutExercise>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<WorkoutSet>()) == 0)
        #expect(try reread.fetchCount(FetchDescriptor<BadgeGrant>()) == 0)
        #expect(restarted.retryLocalCleanup())
        let cleanRestart = SessionStore(modelContext: reread, profileDefaults: defaults)
        #expect(!cleanRestart.requiresLocalCleanup)
    }

    @Test func ordinaryLogoutKeepsCacheAndDoesNotRequireCleanup() throws {
        let container = AppModelContainer.make(inMemory: true)
        let suite = "AccountOrdinaryLogout.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let originalToken = Keychain.get("jwt")
        defer {
            defaults.removePersistentDomain(forName: suite)
            if let originalToken { Keychain.set(originalToken, for: "jwt") }
        }
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults)
        session.uitestInjectFakeSession()
        container.mainContext.insert(Workout(title: "退出后保留"))
        try container.mainContext.save()
        session.logout()
        #expect(!session.requiresLocalCleanup)
        #expect(!defaults.bool(forKey: SessionStore.localCleanupPendingKey))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
    }

    @Test func readonlyCleanupReportsFailureAndKeepsPersistentGate() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "AccountCleanup-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "readonly.store")
        let writable = try ModelContainer(for: AppModelContainer.schema, configurations: [
            ModelConfiguration(schema: AppModelContainer.schema, url: url, cloudKitDatabase: .none)
        ])
        writable.mainContext.insert(UserProfile(serverUserId: UUID(), appleSub: "test"))
        try writable.mainContext.save()
        let readonly = try ModelContainer(for: AppModelContainer.schema, configurations: [
            ModelConfiguration(schema: AppModelContainer.schema, url: url, allowsSave: false, cloudKitDatabase: .none)
        ])
        let suite = "AccountCleanupReadonly.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let originalToken = Keychain.get("jwt")
        defer {
            defaults.removePersistentDomain(forName: suite)
            if let originalToken { Keychain.set(originalToken, for: "jwt") }
        }
        let session = SessionStore(modelContext: readonly.mainContext, profileDefaults: defaults)
        session.beginDeletedAccountCleanup()
        #expect(!session.retryLocalCleanup())
        #expect(!session.isLoggedIn && session.requiresLocalCleanup && session.localCleanupFailed)
        #expect(defaults.bool(forKey: SessionStore.localCleanupPendingKey))
        withExtendedLifetime(writable) {}
    }
}
