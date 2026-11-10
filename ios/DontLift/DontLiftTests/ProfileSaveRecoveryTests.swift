import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct ProfileSaveRecoveryTests {
    private struct SaveFailure: Error {}

    @Test func failedNameAndSexSavesKeepOriginalProfileAndOtherEdits() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.autosaveEnabled = false
        let suite = "ProfileSaveRecovery.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var patches = 0
        let session = SessionStore(modelContext: context, profileDefaults: defaults, updateProfile: { patch in
            patches += 1
            return ProfileDTO(userId: UUID(), displayName: patch.displayName, sex: patch.sex, email: nil)
        })
        session.uitestInjectFakeSession()
        let profile = try #require(session.ensureProfile())
        let other = WorkoutPlan(name: "其他编辑")
        context.insert(other)
        try context.save()
        other.note = "保留未提交内容"
        #expect(throws: SaveFailure.self) {
            try session.saveDisplayName("新称呼", persist: { _ in throw SaveFailure() })
        }
        #expect(throws: SaveFailure.self) {
            try session.saveSex(.female, persist: { _ in throw SaveFailure() })
        }
        await Task.yield()
        #expect(profile.displayName == "测试用户" && profile.sex == .male)
        #expect(other.note == "保留未提交内容")
        #expect(patches == 0 && !defaults.bool(forKey: "profile.pushPending"))

        try session.saveDisplayName("新称呼")
        try session.saveSex(.female)
        for _ in 0..<1000 where defaults.bool(forKey: "profile.pushPending") { await Task.yield() }
        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<UserProfile>()).first)
        #expect(saved.displayName == "新称呼" && saved.sex == .female)
        #expect(!defaults.bool(forKey: "profile.pushPending"))
        #expect(patches == 1)
    }

    @Test func editsDuringPushAreSerializedAndOldResponseCannotClobberLatestInput() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let suite = "ProfilePushRecovery.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var patches: [ProfilePatchRequest] = []
        var firstResponse: CheckedContinuation<ProfileDTO, any Error>?
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults, updateProfile: { patch in
            patches.append(patch)
            if patches.count == 1 {
                return try await withCheckedThrowingContinuation { firstResponse = $0 }
            }
            return ProfileDTO(userId: UUID(), displayName: patch.displayName, sex: patch.sex, email: nil)
        })
        session.uitestInjectFakeSession()
        try session.saveDisplayName("先改称呼")
        for _ in 0..<1000 where firstResponse == nil { await Task.yield() }
        let response = try #require(firstResponse)
        try session.saveSex(.female)
        await Task.yield()
        #expect(patches.count == 1)
        response.resume(returning: ProfileDTO(userId: UUID(), displayName: "先改称呼", sex: "male", email: nil))
        for _ in 0..<1000 where defaults.bool(forKey: "profile.pushPending") { await Task.yield() }
        #expect(patches.count == 2)
        #expect(patches.last?.displayName == "先改称呼" && patches.last?.sex == "female")
        #expect(session.ensureProfile()?.sex == .female)
        #expect(!defaults.bool(forKey: "profile.pushPending"))
    }

    @Test func profileGetCannotOverwriteAnEditMadeWhileItWasLoading() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let suite = "ProfileGetRecovery.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var continuation: CheckedContinuation<ProfileDTO, any Error>?
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults, loadProfile: {
            try await withCheckedThrowingContinuation { continuation = $0 }
        }, updateProfile: { _ in throw URLError(.notConnectedToInternet) })
        session.uitestInjectFakeSession()
        let refresh = Task { await session.refreshProfile() }
        for _ in 0..<1000 where continuation == nil { await Task.yield() }
        let response = try #require(continuation)
        try session.saveDisplayName("加载期间的新称呼")
        response.resume(returning: ProfileDTO(userId: UUID(), displayName: nil, sex: "male", email: nil))
        await refresh.value
        #expect(session.ensureProfile()?.displayName == "加载期间的新称呼")
        #expect(session.needsProfileCompletion == false)
        #expect(defaults.bool(forKey: "profile.pushPending"))
    }

    @Test func completionLocalSaveFailureDoesNotSendPatchOrReleaseGate() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let suite = "ProfileCompletionSave.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var patches = 0
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults, updateProfile: { patch in
            patches += 1
            return ProfileDTO(userId: UUID(), displayName: patch.displayName, sex: patch.sex, email: nil)
        })
        session.uitestInjectFakeSession(profileResolved: false)
        await #expect(throws: SaveFailure.self) {
            try await session.submitProfileCompletion(displayName: "首次称呼", sex: .female,
                                                      persist: { _ in throw SaveFailure() })
        }
        #expect(patches == 0 && session.needsProfileCompletion == nil)
        #expect(session.ensureProfile()?.displayName == nil)
        try await session.submitProfileCompletion(displayName: "首次称呼", sex: .female)
        #expect(patches == 1 && session.needsProfileCompletion == false)
        #expect(session.ensureProfile()?.displayName == "首次称呼")
    }

    @Test func cancelledCompletionResponseKeepsGateUnresolved() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let suite = "ProfileCompletionCancellation.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var continuation: CheckedContinuation<ProfileDTO, any Error>?
        let session = SessionStore(modelContext: container.mainContext, profileDefaults: defaults, updateProfile: { _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        })
        session.uitestInjectFakeSession(profileResolved: false)
        let submit = Task { try await session.submitProfileCompletion(displayName: "当前输入", sex: .male) }
        for _ in 0..<1000 where continuation == nil { await Task.yield() }
        let response = try #require(continuation)
        submit.cancel()
        response.resume(returning: ProfileDTO(userId: UUID(), displayName: "迟到响应", sex: "female", email: nil))
        await #expect(throws: CancellationError.self) { try await submit.value }
        #expect(session.ensureProfile()?.displayName == "当前输入")
        #expect(session.ensureProfile()?.sex == .male)
        #expect(session.needsProfileCompletion == nil)
    }
}
