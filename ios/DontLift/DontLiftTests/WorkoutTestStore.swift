import SwiftData
@testable import DontLift

/// 让业务计算使用受管理的训练图；容器随测试保留，保存错误直接使测试失败。
@MainActor
final class WorkoutTestStore {
    let container: ModelContainer
    let context: ModelContext

    init() {
        let container = AppModelContainer.make(inMemory: true)
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func insert<Model: PersistentModel>(_ model: Model) throws -> Model {
        context.insert(model)
        try context.save()
        return model
    }
}
