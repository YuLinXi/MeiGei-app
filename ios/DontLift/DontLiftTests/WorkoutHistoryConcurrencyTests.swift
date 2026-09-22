import Foundation
import SwiftData
import Testing
@testable import DontLift

@MainActor
struct WorkoutHistoryConcurrencyTests {
    actor Reader {
        var calls = 0
        var fail = false
        private var continuation: CheckedContinuation<Void, Never>?
        func read() async throws -> [HistoryWorkout] {
            calls += 1
            await withCheckedContinuation { continuation = $0 }
            if fail { throw CocoaError(.fileReadUnknown) }
            return []
        }
        func release(fail: Bool = false) {
            self.fail = fail
            continuation?.resume()
            continuation = nil
        }
    }

    private func waitForCall(_ count: Int, reader: Reader) async throws {
        for _ in 0..<200 {
            if await reader.calls == count { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("历史读取未按期开始")
    }

    @Test func coalescesWaitersAndDiscardsInvalidatedResult() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let reader = Reader()
        let store = WorkoutHistoryStore(modelContext: container.mainContext, readHistory: { _ in try await reader.read() })
        store.ensureLoaded(reason: .manual)
        try await waitForCall(1, reader: reader)
        #expect(store.loadState == .refreshing)
        #expect(!store.hasSnapshot)
        let first = Task { await store.waitUntilLoaded() }
        let second = Task { await store.waitUntilLoaded() }
        store.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)
        await reader.release()
        try await waitForCall(2, reader: reader)
        #expect(!store.hasSnapshot)
        await reader.release()
        #expect(await first.value)
        #expect(await second.value)
        #expect(await reader.calls == 2)
        #expect(store.loadState == .available)
    }

    @Test func failureRetainsSnapshotAndRetries() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let reader = Reader()
        let store = WorkoutHistoryStore(modelContext: container.mainContext, readHistory: { _ in try await reader.read() })
        store.ensureLoaded(reason: .manual)
        try await waitForCall(1, reader: reader)
        await reader.release()
        #expect(await store.waitUntilLoaded())
        let timestamp = store.lastRefreshFinishedAt
        store.scheduleRefresh(reason: .manual, delayNanoseconds: 0)
        try await waitForCall(2, reader: reader)
        let waiter = Task { await store.waitUntilLoaded() }
        await Task.yield()
        await reader.release(fail: true)
        #expect(await waiter.value == false)
        #expect(store.loadState == .failed)
        #expect(store.hasSnapshot)
        #expect(store.lastRefreshFinishedAt == timestamp)
        store.ensureLoaded(reason: .manual)
        try await waitForCall(3, reader: reader)
        await reader.release()
        #expect(await store.waitUntilLoaded())
    }

    @Test func resetDiscardsOldSessionAndWaiters() async throws {
        let container = AppModelContainer.make(inMemory: true)
        let reader = Reader()
        let store = WorkoutHistoryStore(modelContext: container.mainContext, readHistory: { _ in try await reader.read() })
        store.ensureLoaded(reason: .manual)
        try await waitForCall(1, reader: reader)
        let waiter = Task { await store.waitUntilLoaded() }
        await Task.yield()
        store.reset()
        await reader.release()
        #expect(await waiter.value == false)
        #expect(!store.hasSnapshot)
        #expect(store.loadState == .notReady)
    }
}
