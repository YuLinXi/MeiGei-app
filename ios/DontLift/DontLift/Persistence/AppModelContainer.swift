import Foundation
import SwiftData

/// 全 App 的 SwiftData 容器。
///
/// 关键决策（design.md D7）：仅本地存储，**显式关闭 CloudKit 自动同步**
/// （`cloudKitDatabase: .none`）——云同步完全走自建后端 API，避免两套同步平面叠加。
enum AppModelContainer {

    /// 参与同步与本地持久化的全部模型。
    static let schema = Schema([
        UserProfile.self,
        CustomExercise.self,
        WorkoutPlan.self,
        Workout.self,
        WorkoutExercise.self,
        WorkoutSet.self,
    ])

    static func make(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }

    /// 预览 / 测试用的内存容器。
    @MainActor
    static let preview: ModelContainer = make(inMemory: true)
}
