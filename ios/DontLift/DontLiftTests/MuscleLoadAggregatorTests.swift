import Foundation
import Testing
@testable import DontLift

@MainActor
struct MuscleLoadAggregatorTests {

    // MARK: - 构造辅助

    private func makeWorkout(at startedAt: Date, exercises: [WorkoutExercise]) -> Workout {
        let workout = Workout(title: "训练", startedAt: startedAt)
        workout.exercises = exercises
        workout.endedAt = startedAt.addingTimeInterval(3600)
        return workout
    }

    private func makeExercise(name: String,
                              muscle: String?,
                              sets: [WorkoutSet]) -> WorkoutExercise {
        let exercise = WorkoutExercise(exerciseName: name, primaryMuscle: muscle, orderIndex: 0)
        exercise.sets = sets
        return exercise
    }

    private func workingSet(_ index: Int, weightKg: Double? = 60, reps: Int? = 8) -> WorkoutSet {
        WorkoutSet(setIndex: index, weightKg: weightKg, reps: reps, completed: true, setType: .working)
    }

    /// 固定的「本周三 12:00」，保证周中同期对比测试稳定。
    private let reference = Calendar.currentMondayFirst.date(
        bySettingHour: 12, minute: 0, second: 0,
        of: Date()
    ) ?? Date()

    // MARK: - 口径

    @Test func countsOnlyCompletedFormalSets() throws {
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let exercise = makeExercise(name: "卧推", muscle: "胸", sets: [
            workingSet(0),
            workingSet(1),
            workingSet(2, weightKg: nil, reps: nil),
            WorkoutSet(setIndex: 3, weightKg: 20, reps: 12, completed: true, setType: .warmup),
            WorkoutSet(setIndex: 4, weightKg: 80, reps: 8, completed: false, setType: .working)
        ])
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [exercise])]

        let entries = MuscleLoadAggregator.load(workouts: workouts, in: week)

        let chest = entries.first { $0.category == .chest }
        #expect(chest?.workingSets == 3)                    // 热身组与未打勾组不计入
        let volume = try #require(chest?.volumeKg)
        #expect(volume == 960)                              // 60×8 + 60×8 + 缺值按 0
        #expect(MuscleLoadAggregator.totalWorkingSets(entries) == 3)
    }

    @Test func dropSetCountsAsOneSetButExpandsVolume() throws {
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let drop = WorkoutSet(setIndex: 0, completed: true, setType: .drop, segments: [
            WorkoutSetSegment(segmentIndex: 0, weightKg: 80, reps: 8),
            WorkoutSetSegment(segmentIndex: 1, weightKg: 60, reps: 6)
        ])
        let exercise = makeExercise(name: "飞鸟", muscle: "胸", sets: [drop])
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [exercise])]

        let chest = MuscleLoadAggregator.load(workouts: workouts, in: week).first { $0.category == .chest }

        #expect(chest?.workingSets == 1)                        // 父组计 1
        let volume = try #require(chest?.volumeKg)
        #expect(volume == 1000)                                 // 训练量按 segments 展开：80×8 + 60×6
    }

    @Test func excludesSoftDeletedWorkoutsAndOutOfRangeDays() {
        let week = MuscleLoadAggregator.weekRange(for: reference)
        // 每个训练独立的动作实例：@Model 关系逆回写会让共享实例从先前数组中移除。
        let inWeek = makeWorkout(at: week.lowerBound.addingTimeInterval(3600),
                                 exercises: [makeExercise(name: "卧推", muscle: "胸", sets: [workingSet(0)])])
        let deleted = makeWorkout(at: week.lowerBound.addingTimeInterval(7200),
                                  exercises: [makeExercise(name: "卧推", muscle: "胸", sets: [workingSet(0)])])
        deleted.deletedAt = Date()
        let lastWeek = makeWorkout(at: week.lowerBound.addingTimeInterval(-3600),
                                   exercises: [makeExercise(name: "卧推", muscle: "胸", sets: [workingSet(0)])])

        let entries = MuscleLoadAggregator.load(workouts: [inWeek, deleted, lastWeek], in: week)

        #expect(entries.first { $0.category == .chest }?.workingSets == 1)
    }

    // MARK: - 归组

    @Test func snapshotTakesPriorityOverLibrary() {
        // 快照为「肩」，即便动作库能把该名字解析到其它部位，也以快照为准。
        let exercise = makeExercise(name: "卧推", muscle: "肩", sets: [workingSet(0)])
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [exercise])]

        let entries = MuscleLoadAggregator.load(workouts: workouts, in: week)

        #expect(entries.first { $0.category == .shoulders }?.workingSets == 1)
        #expect(entries.first { $0.category == .chest }?.workingSets == 0)
    }

    @Test func missingSnapshotFallsBackToLibrary() {
        // 快照 nil，但动作库可解析「杠铃卧推」→ 胸
        let exercise = makeExercise(name: "杠铃卧推", muscle: nil, sets: [workingSet(0)])
        exercise.builtinExerciseCode = "BB_BENCH_PRESS"
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [exercise])]

        let entries = MuscleLoadAggregator.load(workouts: workouts, in: week)

        #expect(entries.first { $0.category == .chest }?.workingSets == 1)
    }

    @Test func unresolvableExerciseGoesToOtherBucket() {
        let exercise = makeExercise(name: "不存在的动作", muscle: nil, sets: [workingSet(0)])
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [exercise])]

        let entries = MuscleLoadAggregator.load(workouts: workouts, in: week)

        #expect(entries.last?.category == nil)
        #expect(entries.last?.workingSets == 1)
    }

    @Test func nonAnatomicalExercisesAreExcludedEntirely() {
        let cardio = makeExercise(name: "慢跑", muscle: "有氧", sets: [workingSet(0)])
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [cardio])]

        let entries = MuscleLoadAggregator.load(workouts: workouts, in: week)

        #expect(MuscleLoadAggregator.totalWorkingSets(entries) == 0)
        #expect(entries.allSatisfy { $0.category != nil })      // 不进「其他」桶
    }

    @Test func collapsedLegacyCategoriesMapToParentL1() {
        // 旧细分类收缩：二头→手臂、斜方肌→背、小腿→腿（快照与动作库两条路径都走 collapseL1）。
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let curl = makeExercise(name: "哑铃弯举", muscle: "二头", sets: [workingSet(0)])
        let shrug = makeExercise(name: "杠铃耸肩", muscle: "斜方肌", sets: [workingSet(0)])
        let raise = makeExercise(name: "提踵", muscle: "小腿", sets: [workingSet(0)])
        let workouts = [makeWorkout(at: week.lowerBound.addingTimeInterval(3600),
                                    exercises: [curl, shrug, raise])]

        let entries = MuscleLoadAggregator.load(workouts: workouts, in: week)

        #expect(entries.first { $0.category == .arms }?.workingSets == 1)
        #expect(entries.first { $0.category == .back }?.workingSets == 1)
        #expect(entries.first { $0.category == .legs }?.workingSets == 1)
        #expect(entries.allSatisfy { $0.category != nil })      // 不产生「其他」
    }

    // MARK: - 排序与同期对比

    @Test func boardSortsBySetsDescendingWithOtherLast() {
        let entries = [
            MuscleLoadEntry(category: .legs, workingSets: 6, volumeKg: 0),
            MuscleLoadEntry(category: .chest, workingSets: 12, volumeKg: 0),
            MuscleLoadEntry(category: nil, workingSets: 9, volumeKg: 0),
            MuscleLoadEntry(category: .back, workingSets: 12, volumeKg: 0)
        ]

        let board = MuscleLoadAggregator.sortedBoard(entries)

        #expect(board.map(\.category) == [.back, .chest, .legs, nil])   // 同组数按中文名次序（背 U+80CC < 胸 U+80F8），其他沉底
    }

    @Test func sameOffsetPreviousWeekTruncatesToElapsedTime() {
        let calendar = Calendar.currentMondayFirst
        let week = MuscleLoadAggregator.weekRange(for: reference, calendar: calendar)
        // 把 reference 对齐到本周三中午，构造确定的 elapsed
        let wednesdayNoon = calendar.date(byAdding: .day, value: 2, to: week.lowerBound)!
            .addingTimeInterval(12 * 3600)

        let baseline = MuscleLoadAggregator.sameOffsetPreviousWeekRange(
            for: week, reference: wednesdayNoon, calendar: calendar)

        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: week.lowerBound)!
        #expect(baseline.lowerBound == previousWeekStart)
        #expect(baseline.upperBound == previousWeekStart
            .addingTimeInterval(2 * 24 * 3600 + 12 * 3600))               // 上周三中午截断
    }

    @Test func completedWeekComparesAgainstFullPreviousWeek() {
        let calendar = Calendar.currentMondayFirst
        let previous = MuscleLoadAggregator.previousWeekRange(for: reference, calendar: calendar)

        // reference 落在本周，但查看的是上一完整周时，对比基准为上上周整周
        let baseline = MuscleLoadAggregator.sameOffsetPreviousWeekRange(
            for: previous, reference: reference, calendar: calendar)

        let expectedStart = calendar.date(byAdding: .weekOfYear, value: -1, to: previous.lowerBound)!
        #expect(baseline == expectedStart..<previous.lowerBound)
    }

    // MARK: - 趋势

    @Test func weeklySeriesBuildsFourWeekRisingSequence() {
        let calendar = Calendar.currentMondayFirst
        let thisWeek = MuscleLoadAggregator.weekRange(for: reference, calendar: calendar)
        var workouts: [Workout] = []
        // 近 4 周胸依次为 6、8、10、12 组（本周做 12 组）
        for (offset, count) in [(-3, 6), (-2, 8), (-1, 10), (0, 12)] {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeek.lowerBound)!
            let sets = (0..<count).map { workingSet($0) }
            let exercise = makeExercise(name: "卧推", muscle: "胸", sets: sets)
            workouts.append(makeWorkout(at: weekStart.addingTimeInterval(3600), exercises: [exercise]))
        }

        let series = MuscleLoadAggregator.weeklySeries(workouts: workouts, weeks: 4, reference: reference)

        #expect(series[.chest] == [6, 8, 10, 12])
        #expect(series[.back] == [0, 0, 0, 0])                  // 无数据周补 0
        #expect(series[nil] == [0, 0, 0, 0])
    }

    // MARK: - 快照构建

    @Test func snapshotBuildsBoardBaselineSeriesAndContributions() {
        let calendar = Calendar.currentMondayFirst
        let thisWeek = MuscleLoadAggregator.weekRange(for: reference, calendar: calendar)
        let thisWeekDay = thisWeek.lowerBound.addingTimeInterval(3600)
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.lowerBound)!
        var workouts: [Workout] = []
        workouts.append(makeWorkout(at: thisWeekDay, exercises: [
            makeExercise(name: "卧推", muscle: "胸", sets: [workingSet(0), workingSet(1), workingSet(2)])
        ]))
        // 上周一、周二（同期内）各 2 组
        for day in [0, 1] {
            workouts.append(makeWorkout(at: lastWeekStart.addingTimeInterval(TimeInterval(day) * 86400 + 3600),
                                        exercises: [makeExercise(name: "卧推", muscle: "胸",
                                                                 sets: [workingSet(0), workingSet(1)])]))
        }
        // 上周三（同期外）1 组
        workouts.append(makeWorkout(at: lastWeekStart.addingTimeInterval(2 * 86400 + 3600),
                                    exercises: [makeExercise(name: "卧推", muscle: "胸", sets: [workingSet(0)])]))

        let referenceAt = thisWeek.lowerBound.addingTimeInterval(86400)   // 本周二 00:00 视角
        let snapshot = MuscleLoadAggregator.snapshot(workouts: workouts, reference: referenceAt, calendar: calendar)

        #expect(snapshot.weekStart == thisWeek.lowerBound)
        #expect(MuscleLoadAggregator.sets(of: .chest, in: snapshot.board) == 3)
        // 同期基准：上周一 00:00 → 上周二 00:00 截断，只含周一的 2 组
        #expect(MuscleLoadAggregator.sets(of: .chest, in: snapshot.baseline) == 2)
        // 上一完整周看板含全周 5 组
        #expect(MuscleLoadAggregator.sets(of: .chest, in: snapshot.previousBoard) == 5)
        #expect(snapshot.series[.chest] == [0, 0, 5, 3])
        #expect(snapshot.contributions[.chest]?.first?.exerciseName == "卧推")
        #expect(snapshot.contributions[.chest]?.first?.workingSets == 3)
        #expect(snapshot.previousContributions[.chest]?.first?.workingSets == 5)
    }

    // MARK: - 贡献明细

    @Test func contributionsGroupByHistoryKeyDescending() {
        let week = MuscleLoadAggregator.weekRange(for: reference)
        let benchDay1 = makeExercise(name: "杠铃卧推", muscle: "胸", sets: [workingSet(0), workingSet(1)])
        benchDay1.builtinExerciseCode = "BB_BENCH_PRESS"
        let benchDay2 = makeExercise(name: "杠铃卧推", muscle: "胸", sets: [workingSet(0)])
        benchDay2.builtinExerciseCode = "BB_BENCH_PRESS"
        let fly = makeExercise(name: "不存在的飞鸟", muscle: "胸", sets: [workingSet(0)])
        let squat = makeExercise(name: "深蹲", muscle: "腿", sets: [workingSet(0)])
        let day1 = makeWorkout(at: week.lowerBound.addingTimeInterval(3600), exercises: [benchDay1, squat])
        let day2 = makeWorkout(at: week.lowerBound.addingTimeInterval(7200), exercises: [benchDay2, fly])

        let contributions = MuscleLoadAggregator.contributions(
            workouts: [day1, day2], in: week, category: .chest)

        #expect(contributions.count == 2)                       // 深蹲（腿）不出现
        #expect(contributions[0].exerciseName == "杠铃卧推")
        #expect(contributions[0].workingSets == 3)              // 同 historyKey 跨训练合并
        #expect(contributions[1].workingSets == 1)
    }
}
