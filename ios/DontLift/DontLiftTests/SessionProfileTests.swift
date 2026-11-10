import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct SessionProfileTests {
    @Test func staleCompletionResponseCannotOverwriteNewSession() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let suite = "SessionCompletionRegression.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var continuation: CheckedContinuation<ProfileDTO, any Error>?
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults,
                                   updateProfile: { _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        })
        session.uitestInjectFakeSession(profileResolved: false)
        let submit = Task { try await session.submitProfileCompletion(displayName: "旧称呼", sex: .female) }
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        let response = try #require(continuation)
        session.logout()
        session.uitestInjectFakeSession()
        let currentUserId = session.currentUserId
        defaults.set(true, forKey: "profile.pushPending")
        response.resume(returning: ProfileDTO(userId: UUID(), displayName: "迟到的旧称呼", sex: "female", email: nil))

        await #expect(throws: CancellationError.self) { try await submit.value }
        #expect(session.currentUserId == currentUserId)
        #expect(session.ensureProfile()?.displayName == "测试用户")
        #expect(session.ensureProfile()?.sex == .male)
        #expect(defaults.bool(forKey: "profile.pushPending"))
    }

    @Test func unnamedOfflineProfileStopsRetryingAndOffersRecovery() async throws {
        let container = AppModelContainer.make(inMemory: true)
        container.mainContext.insert(Workout(title: "失败恢复仍保留"))
        try container.mainContext.save()
        let pending = UserDefaults.standard.object(forKey: "profile.pushPending")
        UserDefaults.standard.removeObject(forKey: "profile.pushPending")
        defer { UserDefaults.standard.set(pending, forKey: "profile.pushPending") }
        var attempts = 0
        let session = SessionStore(modelContext: container.mainContext, loadProfile: {
            attempts += 1
            throw URLError(.notConnectedToInternet)
        })
        session.uitestInjectFakeSession(profileResolved: false)

        await session.resolveProfile(retryDelay: .zero)

        #expect(attempts == 5)
        #expect(session.profileLoadFailed)
        #expect(session.needsProfileCompletion == nil)
        #expect(session.isLoggedIn)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
    }

    @Test func manualProfileRetryRecoversWithoutLosingLocalData() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let pending = UserDefaults.standard.object(forKey: "profile.pushPending")
        UserDefaults.standard.removeObject(forKey: "profile.pushPending")
        defer { UserDefaults.standard.set(pending, forKey: "profile.pushPending") }
        var offline = true
        let session = SessionStore(modelContext: container.mainContext, loadProfile: {
            if offline { throw URLError(.notConnectedToInternet) }
            return ProfileDTO(userId: UUID(), displayName: "恢复后的称呼", sex: "male", email: nil)
        })
        session.uitestInjectFakeSession(profileResolved: false)
        await session.resolveProfile(retryDelay: .zero)
        #expect(session.profileLoadFailed)

        offline = false
        await session.resolveProfile(retryDelay: .zero)

        #expect(!session.profileLoadFailed)
        #expect(session.needsProfileCompletion == false)
        #expect(session.ensureProfile()?.displayName == "恢复后的称呼")
    }

    @Test func staleProfileResponseDoesNotOverwriteNewSession() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let pending = UserDefaults.standard.object(forKey: "profile.pushPending")
        UserDefaults.standard.removeObject(forKey: "profile.pushPending")
        defer { UserDefaults.standard.set(pending, forKey: "profile.pushPending") }
        var response: CheckedContinuation<ProfileDTO, Error>?
        let session = SessionStore(modelContext: container.mainContext, loadProfile: {
            try await withCheckedThrowingContinuation { response = $0 }
        })
        session.uitestInjectFakeSession(profileResolved: false)
        let oldRequest = Task { await session.resolveProfile(retryDelay: .zero) }
        while response == nil { await Task.yield() }
        session.logout()
        session.uitestInjectFakeSession()
        let newUserId = session.currentUserId
        response?.resume(returning: ProfileDTO(userId: UUID(), displayName: "旧会话称呼", sex: "female", email: nil))
        await oldRequest.value

        #expect(session.currentUserId == newUserId)
        #expect(session.ensureProfile()?.displayName == "测试用户")
        #expect(session.needsProfileCompletion == false)
        #expect(!session.profileLoadFailed)
    }

    @Test func cancelledProfileReadDoesNotRouteOrShowFailure() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let defaults = try #require(UserDefaults(suiteName: "ProfileCancellation.\(UUID())"))
        var response: CheckedContinuation<ProfileDTO, Error>?
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults, loadProfile: {
            try await withCheckedThrowingContinuation { response = $0 }
        })
        session.uitestInjectFakeSession(profileResolved: false)
        let request = Task { await session.resolveProfile(retryDelay: .zero) }
        while response == nil { await Task.yield() }
        request.cancel()
        response?.resume(returning: ProfileDTO(userId: UUID(), displayName: "迟到称呼", sex: nil, email: nil))
        await request.value

        #expect(session.needsProfileCompletion == nil)
        #expect(!session.profileLoadFailed)
        #expect(session.ensureProfile()?.displayName == nil)
    }

    @Test func cachedNameAllowsOfflineRoutingFromUnknownState() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let defaults = try #require(UserDefaults(suiteName: "ProfileOfflineCache.\(UUID())"))
        var attempts = 0
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults, loadProfile: {
            attempts += 1
            throw URLError(.notConnectedToInternet)
        })
        session.uitestInjectFakeSession(profileResolved: false)
        session.ensureProfile()?.displayName = "本地已有称呼"
        try container.mainContext.save()

        await session.resolveProfile(retryDelay: .zero)

        #expect(attempts == 1)
        #expect(session.needsProfileCompletion == false)
        #expect(!session.profileLoadFailed)
    }

    @Test func missingAccountLogsOutWithoutDeletingLocalData() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let workout = Workout(title: "保留本地记录")
        context.insert(workout)
        try context.save()
        let originalToken = Keychain.get("jwt")
        let originalPending = UserDefaults.standard.object(forKey: "profile.pushPending")
        UserDefaults.standard.removeObject(forKey: "profile.pushPending")
        defer {
            if let originalToken { Keychain.set(originalToken, for: "jwt") }
            UserDefaults.standard.set(originalPending, forKey: "profile.pushPending")
        }
        let session = SessionStore(modelContext: context, loadProfile: {
            throw APIError.http(status: 404, body: "用户不存在")
        })
        session.uitestInjectFakeSession()

        await session.refreshProfile()

        #expect(!session.isLoggedIn)
        #expect(session.currentUserId == nil)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 1)
    }

    @Test func temporaryProfileFailureKeepsOfflineSession() async {
        let container = AppModelContainer.make(inMemory: true)
        let originalPending = UserDefaults.standard.object(forKey: "profile.pushPending")
        UserDefaults.standard.removeObject(forKey: "profile.pushPending")
        defer { UserDefaults.standard.set(originalPending, forKey: "profile.pushPending") }
        let session = SessionStore(modelContext: container.mainContext, loadProfile: {
            throw APIError.http(status: 503, body: "暂时不可用")
        })
        session.uitestInjectFakeSession()

        await session.refreshProfile()

        #expect(session.isLoggedIn)
        #expect(session.needsProfileCompletion == false)
    }

    @Test func importedProfileOpensMainAppAndRestoresDisplayName() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let originalPending = UserDefaults.standard.object(forKey: "profile.pushPending")
        UserDefaults.standard.removeObject(forKey: "profile.pushPending")
        defer { UserDefaults.standard.set(originalPending, forKey: "profile.pushPending") }
        let session = SessionStore(modelContext: container.mainContext, loadProfile: {
            ProfileDTO(userId: UUID(), displayName: "佩帕哥哥", sex: "male", email: nil)
        })
        session.uitestInjectFakeSession()

        await session.refreshProfile()

        #expect(session.isLoggedIn)
        #expect(session.needsProfileCompletion == false)
        #expect(session.ensureProfile()?.displayName == "佩帕哥哥")
    }
}

@MainActor
struct UITestExerciseReferenceTests {
    @Test(arguments: [false, true])
    func seededExercisesHaveValidBuiltinReferences(isLong: Bool) {
        let exercises = UITestHooks.liveWorkoutExercises(isLong: isLong)
        #expect(exercises.count == (isLong ? 20 : 3))
        for exercise in exercises {
            #expect(exercise.builtinExerciseCode != nil)
            #expect(exercise.customExerciseId == nil)
        }
    }
}
