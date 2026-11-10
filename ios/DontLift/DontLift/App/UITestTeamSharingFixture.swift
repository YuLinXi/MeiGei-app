#if DEBUG
import SwiftUI
import SwiftData

/// 主动分享使用真实页面和服务调用，仅服务器响应及数据属于隔离测试。
struct UITestTeamSharingFixture: View {
    @Environment(\.modelContext) private var modelContext
    @State private var prepared: TeamShareDraft?
    @State private var presented: TeamShareDraft?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("隔离分享边界测试").font(Theme.Font.l2)
            Text("分享请求审计")
                .font(Theme.Font.l5)
                .accessibilityIdentifier("uitest.team.share.audit")
                .accessibilityValue(UITestTeamSharingAudit.shared.value)
            Button("打开主动分享") { presented = prepared }
                .disabled(prepared == nil)
            if let error { Text(error) }
        }
        .padding()
        .sheet(item: $presented) { TeamShareSheet(draft: $0) }
        .task {
            do {
                let id = UUID(uuidString: "A1000000-0000-0000-0000-000000000006")!
                let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.localId == id })
                let workout: Workout
                if let existing = try modelContext.fetch(descriptor).first {
                    workout = existing
                } else {
                    let set = WorkoutSet(setIndex: 0, weightKg: 60, reps: 8, completed: true)
                    let exercise = WorkoutExercise(builtinExerciseCode: "BB_BENCH_PRESS", exerciseName: "杠铃卧推",
                                                   orderIndex: 0, sets: [set])
                    workout = Workout(localId: id, title: "UI 分享边界训练", endedAt: .now, exercises: [exercise])
                    workout.syncStatusRaw = SyncStatus.synced.rawValue
                    modelContext.insert(workout)
                    try LocalModelSave.save(modelContext)
                }
                prepared = TeamShareDraft(workout: workout)
            } catch { self.error = error.localizedDescription }
        }
    }
}
#endif
