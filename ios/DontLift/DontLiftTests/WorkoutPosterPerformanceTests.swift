import Foundation
import SwiftData
import Testing
import UIKit
@testable import DontLift

/// 真实导出路径的长训练基线；仅测数据整理与渲染，不代表触摸到显示或系统分享耗时。
@Suite(.serialized)
@MainActor
struct WorkoutPosterPerformanceTests {
    @Test(arguments: ["celebration", "energyTrail", "miniGym", "highFive", "equipmentWreath"])
    func longWorkoutRendersAtExportResolution(backgroundRaw: String) async throws {
        try #require(UITestHooks.isFinishFlowUITest, "需使用隔离内存宿主参数运行海报性能采样")
        let background = WorkoutPosterBackground.resolve(rawValue: backgroundRaw)
        let container = AppModelContainer.make(inMemory: true)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = Workout(title: "长训练海报性能样本", startedAt: start, timerStartedAt: start,
                              endedAt: start.addingTimeInterval(3600), exercises: (0..<20).map { index in
            WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "动作 \(index + 1)", orderIndex: index,
                            sets: (0..<5).map { WorkoutSet(setIndex: $0, weightKg: 60, reps: 10, completed: true) })
        })
        container.mainContext.insert(workout)
        try container.mainContext.save()

        for index in 0...30 {
            try autoreleasepool {
                let projectionStart = ContinuousClock.now
                let data = WorkoutPosterData(workout: workout,
                                             caloriePreferences: WorkoutCaloriePreferences(showsEstimates: false))
                let projectionSeconds = seconds(projectionStart.duration(to: .now))
                #expect(data.context.exerciseCount == 20 && data.context.setCount == 100)
                #expect(data.exerciseLines.count == 20)
                let renderStart = ContinuousClock.now
                let image = try #require(WorkoutPosterImageRenderer.render(data: data, background: background))
                let renderSeconds = seconds(renderStart.duration(to: .now))
                #expect(image.cgImage?.width == 1080 && image.cgImage?.height == 1920)
                print("[S4-poster] background=\(background.rawValue) index=\(index) projection_s=\(projectionSeconds) render_s=\(renderSeconds)")
            }
            await Task.yield()
        }
    }

    private func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
