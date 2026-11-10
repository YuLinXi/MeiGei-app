import Foundation
import SwiftData

/// 已有模型的短同步提交只撤销本次变更；新对象隔离保存，避免失败候选残留在共享 context。
@MainActor
enum LocalModelCommit {
    @discardableResult
    static func insert<Model: PersistentModel>(_ candidate: Model,
                                               in context: ModelContext,
                                               persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) }) throws -> Model {
        let creationContext = ModelContext(context.container)
        creationContext.autosaveEnabled = false
        creationContext.insert(candidate)
        #if DEBUG
        try UITestHooks.failFirstSaveIfNeeded("commit")
        #endif
        try persist(creationContext)
        return context.model(for: candidate.persistentModelID) as! Model
    }

    static func perform(in context: ModelContext,
                        persist: (ModelContext) throws -> Void = { try LocalModelSave.save($0) },
                        mutation: () throws -> Void) throws {
        context.processPendingChanges()
        let previous = context.undoManager
        let undo = UndoManager()
        undo.groupsByEvent = false
        context.undoManager = undo
        defer { context.undoManager = previous }
        undo.beginUndoGrouping()
        do {
            try mutation()
            context.processPendingChanges()
            // SwiftData 可能已经闭合本组，不能再次无条件 end。
            if undo.groupingLevel > 0 { undo.endUndoGrouping() }
            #if DEBUG
            try UITestHooks.failFirstSaveIfNeeded("commit")
            #endif
            try persist(context)
        } catch {
            if undo.groupingLevel > 0 {
                context.processPendingChanges()
                if undo.groupingLevel > 0 { undo.endUndoGrouping() }
            }
            undo.undo()
            context.processPendingChanges()
            throw error
        }
    }
}
