import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct SessionProfileTests {
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
