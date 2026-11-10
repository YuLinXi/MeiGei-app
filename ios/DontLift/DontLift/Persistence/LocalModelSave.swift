import Foundation
import SwiftData

/// 明确保存成功后发布项目事件，不依赖各系统版本的 SwiftData 通知行为。
nonisolated enum LocalModelSave {
    static let didSave = Notification.Name("dontlift.modelContextDidSave")

    static func save(_ context: ModelContext) throws {
        let inserted = context.insertedModelsArray
        let changed = context.changedModelsArray
        let deleted = context.deletedModelsArray.map(\.persistentModelID)
        try context.save()
        NotificationCenter.default.post(name: didSave, object: context, userInfo: [
            ModelContext.NotificationKey.insertedIdentifiers.rawValue: inserted.map(\.persistentModelID),
            ModelContext.NotificationKey.updatedIdentifiers.rawValue: changed.map(\.persistentModelID),
            ModelContext.NotificationKey.deletedIdentifiers.rawValue: deleted
        ])
    }
}
