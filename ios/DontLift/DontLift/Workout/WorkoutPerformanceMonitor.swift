import Foundation
import OSLog

/// 训练历史性能诊断工具。Release 下 signpost 仍可由 Instruments 采集，
/// DEBUG 下额外输出数据规模日志，便于对比导入历史前后表现。
nonisolated enum WorkoutPerformanceMonitor {
    private static let signposter = OSSignposter(
        subsystem: "com.yulinxi.app.DontLift",
        category: "WorkoutPerformance"
    )

    static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        #if DEBUG
        let start = ContinuousClock.now
        #endif
        defer {
            signposter.endInterval(name, state)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-profile-workout") {
                print("PROFILE \(name) main=\(Thread.isMainThread) duration=\(start.duration(to: .now))")
            }
            #endif
        }
        return try body()
    }

    static func record(_ name: StaticString, since start: ContinuousClock.Instant) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-profile-workout") {
            print("PROFILE \(name) main=\(Thread.isMainThread) duration=\(start.duration(to: .now))")
        }
        #endif
    }

    static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }
}
