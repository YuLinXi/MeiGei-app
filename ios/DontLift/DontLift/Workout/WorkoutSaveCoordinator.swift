import Foundation
import Observation
import SwiftData

/// 合并训练高频输入的保存；失败保留内存中的输入，由页面提供重试。
@MainActor
@Observable
final class WorkoutSaveCoordinator {
    private(set) var hasFailure = false
    @ObservationIgnored private var pendingTask: Task<Void, Never>?

    func schedule(in context: ModelContext,
                  onSaved: @escaping () -> Void,
                  persist: @escaping (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) {
        cancelPending()
        pendingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            pendingTask = nil
            save(in: context, onSaved: onSaved, persist: persist)
        }
    }

    @discardableResult
    func flush(in context: ModelContext,
               onSaved: () -> Void,
               persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) -> Bool {
        cancelPending()
        return save(in: context, onSaved: onSaved, persist: persist)
    }

    func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
    }

    func recordSuccessfulSave() { hasFailure = false }

    @discardableResult
    private func save(in context: ModelContext,
                      onSaved: () -> Void,
                      persist: (ModelContext) throws -> Void) -> Bool {
        do {
            #if DEBUG
            try UITestHooks.failFirstSaveIfNeeded("input")
            #endif
            try persist(context)
            hasFailure = false
            onSaved()
            return true
        } catch {
            hasFailure = true
            return false
        }
    }
}
