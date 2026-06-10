//
//  DontLiftTests.swift
//  DontLiftTests
//
//  Created by Yu on 2026/5/17.
//

import Testing
import Foundation
@testable import DontLift

struct WorkoutWeeklyStatsTests {

    /// 构造一个简单训练（在 SwiftData container 外，仅用于纯函数测试）。
    private func makeWorkout(startedAt: Date, endedAt: Date?, sets: [(Double?, Int?)]) -> Workout {
        let w = Workout(startedAt: startedAt, endedAt: endedAt)
        let ex = WorkoutExercise(exerciseName: "测试动作", orderIndex: 0)
        ex.sets = sets.enumerated().map { idx, t in
            WorkoutSet(setIndex: idx, weightKg: t.0, reps: t.1, completed: true)
        }
        w.exercises = [ex]
        return w
    }

    private var mondayCalendar: Calendar { Calendar.currentMondayFirst }

    @Test func emptyInput() {
        let s = WorkoutWeeklyStats.compute(workouts: [], reference: .now, calendar: mondayCalendar)
        #expect(s == .empty)
    }

    @Test func singleWorkoutSums() {
        let now = Date()
        let w = makeWorkout(startedAt: now, endedAt: now.addingTimeInterval(3600),
                            sets: [(100, 5), (100, 5), (90, 8)])
        let s = WorkoutWeeklyStats.compute(workouts: [w], reference: now, calendar: mondayCalendar)
        #expect(s.sessionCount == 1)
        #expect(s.setCount == 3)
        #expect(s.repCount == 18)
        let expectedVolume: Double = 100 * 5 + 100 * 5 + 90 * 8
        #expect(s.volumeKg == expectedVolume)
        #expect(s.avgDurationSec == 3600)
    }

    @Test func weightedAverageDuration() {
        let now = Date()
        let w1 = makeWorkout(startedAt: now, endedAt: now.addingTimeInterval(1800), sets: [(50, 10)])
        let w2 = makeWorkout(startedAt: now, endedAt: now.addingTimeInterval(3600), sets: [(50, 10)])
        // 未结束训练不计入平均时长
        let w3 = makeWorkout(startedAt: now, endedAt: nil, sets: [(50, 10)])
        let s = WorkoutWeeklyStats.compute(workouts: [w1, w2, w3], reference: now, calendar: mondayCalendar)
        #expect(s.sessionCount == 3)
        #expect(s.avgDurationSec == (1800 + 3600) / 2)
    }

    @Test func crossWeekBoundary() {
        // 选 2026-05-25（周一）作为参考日；本周窗口 [05-25 00:00, 06-01 00:00)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 25; comps.hour = 12
        let monday = mondayCalendar.date(from: comps)!
        // 上周日（05-24）：不应计入
        let prevSunday = mondayCalendar.date(byAdding: .day, value: -1, to: monday)!
        // 本周三（05-27）：应计入
        let wed = mondayCalendar.date(byAdding: .day, value: 2, to: monday)!
        let wOut = makeWorkout(startedAt: prevSunday, endedAt: prevSunday, sets: [(100, 1)])
        let wIn = makeWorkout(startedAt: wed, endedAt: wed, sets: [(50, 4)])
        let s = WorkoutWeeklyStats.compute(workouts: [wOut, wIn], reference: monday, calendar: mondayCalendar)
        #expect(s.sessionCount == 1)
        #expect(s.volumeKg == 50 * 4)
    }
}
