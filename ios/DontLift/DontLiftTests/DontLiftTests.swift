//
//  DontLiftTests.swift
//  DontLiftTests
//
//  Created by Yu on 2026/5/17.
//

import Testing
import Foundation
@testable import DontLift

@MainActor
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
    }

    @Test func dropSetCountsEffectiveSegmentsAndExpandsVolume() {
        let now = Date()
        let w = Workout(startedAt: now, endedAt: now.addingTimeInterval(3600))
        let ex = WorkoutExercise(exerciseName: "测试动作", orderIndex: 0)
        ex.sets = [
            WorkoutSet(
                setIndex: 0,
                completed: true,
                setType: .drop,
                segments: [
                    WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                    WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6),
                    WorkoutSetSegment(segmentIndex: 2)
                ]
            )
        ]
        w.exercises = [ex]

        let s = WorkoutWeeklyStats.compute(workouts: [w], reference: now, calendar: mondayCalendar)

        #expect(s.sessionCount == 1)
        #expect(s.setCount == 2)
        #expect(s.repCount == 14)
        #expect(s.volumeKg == 80 * 8 + 60 * 6)
    }

    @Test func unfinishedWorkoutCountsAsSession() {
        let now = Date()
        let w1 = makeWorkout(startedAt: now, endedAt: now.addingTimeInterval(1800), sets: [(50, 10)])
        let w2 = makeWorkout(startedAt: now, endedAt: now.addingTimeInterval(3600), sets: [(50, 10)])
        // 未结束训练不计入平均时长
        let w3 = makeWorkout(startedAt: now, endedAt: nil, sets: [(50, 10)])
        let s = WorkoutWeeklyStats.compute(workouts: [w1, w2, w3], reference: now, calendar: mondayCalendar)
        #expect(s.sessionCount == 3)
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

    @Test func emptyWeekDayStatusesCoverSevenDays() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 25; comps.hour = 12
        let monday = mondayCalendar.date(from: comps)!

        let days = WorkoutWeeklyStats.dayStatuses(workouts: [], reference: monday, calendar: mondayCalendar)

        #expect(days.count == 7)
        #expect(days.allSatisfy { !$0.isCompleted })
        #expect(days.first?.weekdayIndex == 0)
        #expect(days.first?.isToday == true)
    }

    @Test func sameDayMultipleWorkoutsLightOneDayWithSessionCount() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 27; comps.hour = 9
        let wednesdayMorning = mondayCalendar.date(from: comps)!
        comps.hour = 20
        let wednesdayEvening = mondayCalendar.date(from: comps)!

        let first = makeWorkout(startedAt: wednesdayMorning, endedAt: wednesdayMorning, sets: [(50, 5)])
        let second = makeWorkout(startedAt: wednesdayEvening, endedAt: wednesdayEvening, sets: [(60, 5)])
        let days = WorkoutWeeklyStats.dayStatuses(workouts: [first, second], reference: wednesdayMorning, calendar: mondayCalendar)
        let wednesday = days[2]

        #expect(wednesday.isCompleted)
        #expect(wednesday.sessionCount == 2)
        #expect(days.filter(\.isCompleted).count == 1)
    }

    @Test func dayStatusesUseMondayWeekBoundary() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 1; comps.hour = 12
        let monday = mondayCalendar.date(from: comps)!
        let previousSunday = mondayCalendar.date(byAdding: .day, value: -1, to: monday)!
        let currentSunday = mondayCalendar.date(byAdding: .day, value: 6, to: monday)!
        let old = makeWorkout(startedAt: previousSunday, endedAt: previousSunday, sets: [(50, 5)])
        let current = makeWorkout(startedAt: currentSunday, endedAt: currentSunday, sets: [(60, 5)])

        let days = WorkoutWeeklyStats.dayStatuses(workouts: [old, current], reference: monday, calendar: mondayCalendar)

        #expect(days[6].isCompleted)
        #expect(days[6].sessionCount == 1)
        #expect(days.filter(\.isCompleted).count == 1)
    }
}

struct TeamMemberDTOTests {

    @Test func missingAutoShareWorkoutsDefaultsToFalse() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "teamId": "00000000-0000-0000-0000-000000000002",
          "userId": "00000000-0000-0000-0000-000000000003",
          "role": "member",
          "displayName": "测试用户"
        }
        """.data(using: .utf8)!

        let member = try JSONCoding.decoder.decode(TeamMemberDTO.self, from: json)

        #expect(member.autoShareWorkouts == false)
    }

    @Test func decodesAutoShareWorkouts() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "teamId": "00000000-0000-0000-0000-000000000002",
          "userId": "00000000-0000-0000-0000-000000000003",
          "role": "member",
          "autoShareWorkouts": true
        }
        """.data(using: .utf8)!

        let member = try JSONCoding.decoder.decode(TeamMemberDTO.self, from: json)

        #expect(member.autoShareWorkouts == true)
    }
}

@MainActor
struct DropSetPRStatsTests {
    @Test func dropSetTopSegmentCountsForPR() {
        let workout = Workout(startedAt: Date(timeIntervalSince1970: 1000),
                              endedAt: Date(timeIntervalSince1970: 4600))
        let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH", exerciseName: "卧推", orderIndex: 0)
        exercise.sets = [
            WorkoutSet(
                setIndex: 0,
                completed: true,
                setType: .drop,
                segments: [
                    WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
                    WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
                ]
            )
        ]
        workout.exercises = [exercise]

        let pr = PRStats.latestPR(for: exercise.historyKey, in: [workout])

        #expect(pr?.weightKg == 80)
        #expect(pr?.reps == 8)
    }
}
