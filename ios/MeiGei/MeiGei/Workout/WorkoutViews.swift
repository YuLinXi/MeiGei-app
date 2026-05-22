import SwiftUI
import SwiftData

// MARK: - 训练记录列表 + 开始训练

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]
    @State private var active: Workout?
    @State private var choosingPlan = false

    var body: some View {
        List {
            ForEach(workouts) { w in
                NavigationLink(value: w) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.title ?? "训练").font(.headline)
                        Text(summary(w)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("训练记录")
        .overlay { if workouts.isEmpty { ContentUnavailableView("还没有训练记录", systemImage: "figure.strengthtraining.traditional", description: Text("点右上角开始一次训练")) } }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink { TrainingHistoryView() } label: {
                    Image(systemName: "calendar")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("空白训练") { startBlank() }
                    if !plans.isEmpty {
                        Divider()
                        ForEach(plans) { p in Button("从「\(p.name)」开始") { start(from: p) } }
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .navigationDestination(for: Workout.self) { WorkoutLoggingView(workout: $0) }
        .navigationDestination(item: $active) { WorkoutLoggingView(workout: $0) }
    }

    private func summary(_ w: Workout) -> String {
        let date = w.startedAt.formatted(date: .abbreviated, time: .shortened)
        let sets = w.exercises.reduce(0) { $0 + $1.sets.count }
        let status = w.endedAt == nil ? "进行中" : "已完成"
        return "\(date) · \(w.exercises.count)动作/\(sets)组 · \(status)"
    }

    private func startBlank() {
        let w = Workout(title: "训练")
        modelContext.insert(w)
        try? modelContext.save()
        active = w
    }

    private func start(from plan: WorkoutPlan) {
        let w = Workout(planId: plan.localId, title: plan.name)
        for item in plan.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let ex = WorkoutExercise(builtinExerciseCode: item.builtinExerciseCode,
                                     customExerciseId: item.customExerciseId,
                                     exerciseName: item.exerciseName,
                                     primaryMuscle: nil, orderIndex: item.orderIndex)
            // 预填建议组数的空组：带建议次数，但**不预填重量**（spec 约束）。
            let count = max(item.suggestedSets ?? 1, 1)
            ex.sets = (0..<count).map { WorkoutSet(setIndex: $0, weightKg: nil, reps: item.suggestedReps) }
            w.exercises.append(ex)
        }
        modelContext.insert(w)
        try? modelContext.save()
        active = w
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { workouts[i].markDeleted() }
        try? modelContext.save()
    }
}

// MARK: - 3.6 训练记录界面

struct WorkoutLoggingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TeamService.self) private var teamService
    @Environment(RestTimerController.self) private var restTimer
    @Environment(HealthKitManager.self) private var healthKit
    @Bindable var workout: Workout
    @State private var pickingExercise = false
    @State private var sharingSummary: CheckinSummary?
    @State private var celebration: [PersonalRecord]?

    var body: some View {
        List {
            ForEach(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                ExerciseSection(exercise: ex, onChange: touch,
                                onCompleteSet: { restTimer.start(label: ex.exerciseName) },
                                onDeleteExercise: { delete(ex) })
            }
            Section {
                Button { pickingExercise = true } label: { Label("添加动作", systemImage: "plus") }
            }
            if workout.endedAt != nil {
                Section {
                    Button { sharingSummary = CheckinSummary(workout: workout) } label: {
                        Label("生成分享海报", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(workout.title ?? "训练")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { RestTimerBar(controller: restTimer) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("休息时长", selection: Binding(
                        get: { restTimer.defaultDuration },
                        set: { restTimer.defaultDuration = $0 })) {
                        ForEach([Double](arrayLiteral: 30, 45, 60, 90, 120, 150, 180), id: \.self) { secs in
                            Text("\(Int(secs)) 秒").tag(secs)
                        }
                    }
                } label: { Label("休息时长", systemImage: "timer") }
            }
            ToolbarItem(placement: .confirmationAction) {
                if workout.endedAt == nil {
                    Button("完成") { finish() }
                } else {
                    Text("已完成").foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in addExercise(pick) }
        }
        .sheet(item: $sharingSummary) { SharePosterSheet(summary: $0) }
        .sheet(isPresented: Binding(get: { celebration != nil }, set: { if !$0 { celebration = nil } })) {
            if let celebration { PRCelebrationSheet(records: celebration) }
        }
    }

    private func addExercise(_ pick: ExercisePick) {
        let ex = WorkoutExercise(builtinExerciseCode: pick.builtinCode, customExerciseId: pick.customId,
                                 exerciseName: pick.name, primaryMuscle: pick.primaryMuscle,
                                 orderIndex: workout.exercises.count)
        ex.sets = [WorkoutSet(setIndex: 0)]
        workout.exercises.append(ex)
        touch()
    }

    private func delete(_ ex: WorkoutExercise) {
        workout.exercises.removeAll { $0.localId == ex.localId }
        modelContext.delete(ex)
        touch()
    }

    private func finish() {
        let endedAt = Date.now
        workout.endedAt = endedAt
        touch()
        // 写入 HealthKit（力量训练 Workout，需授权）；未授权/不可用时静默跳过，不阻断保存。
        let startedAt = workout.startedAt
        Task { await healthKit.saveStrengthWorkout(start: startedAt, end: endedAt) }
        // PR 识别：由原始记录重算，与历史已完成训练比较（排除本次），不持久化（spec/design）。
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.deletedAt == nil && $0.endedAt != nil })
        if let all = try? modelContext.fetch(descriptor) {
            let history = all.filter { $0.localId != workout.localId }
            let prs = detectPersonalRecords(in: workout, history: history)
            if !prs.isEmpty { celebration = prs }
        }
        // 训练即打卡：fan-out 到本人所有 Team（无 Team 时服务端空返回，无副作用）。
        // 失败不阻断 UI——本地训练已落盘，可手动重试。
        let snapshot = workout
        Task { try? await teamService.checkIn(workout: snapshot) }
    }

    /// 任意编辑后：刷新同步信封并落盘（离线优先，下次同步上传）。
    private func touch() {
        workout.markDirty()
        try? modelContext.save()
    }
}

private struct ExerciseSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: WorkoutExercise
    let onChange: () -> Void
    let onCompleteSet: () -> Void
    let onDeleteExercise: () -> Void

    var body: some View {
        Section {
            ForEach(exercise.sets.sorted { $0.setIndex < $1.setIndex }) { set in
                SetRow(set: set, onChange: onChange, onComplete: onCompleteSet)
            }
            .onDelete { offsets in deleteSets(offsets) }
            Button { addSet() } label: { Label("加一组", systemImage: "plus.circle") }.font(.subheadline)
        } header: {
            HStack {
                Text(exercise.exerciseName)
                Spacer()
                Button(role: .destructive) { onDeleteExercise() } label: {
                    Image(systemName: "trash").font(.caption)
                }
            }
        }
    }

    private func addSet() {
        let next = (exercise.sets.map(\.setIndex).max() ?? -1) + 1
        // 复制上一组的重量便于连续记录，但不来自计划预填。
        let lastWeight = exercise.sets.sorted { $0.setIndex < $1.setIndex }.last?.weightKg
        exercise.sets.append(WorkoutSet(setIndex: next, weightKg: lastWeight))
        onChange()
    }

    private func deleteSets(_ offsets: IndexSet) {
        let sorted = exercise.sets.sorted { $0.setIndex < $1.setIndex }
        for i in offsets {
            let s = sorted[i]
            exercise.sets.removeAll { $0.localId == s.localId }
            modelContext.delete(s)
        }
        onChange()
    }
}

private struct SetRow: View {
    @Bindable var set: WorkoutSet
    let onChange: () -> Void
    let onComplete: () -> Void
    @State private var showNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("\(set.setIndex + 1)").font(.caption.bold()).frame(width: 20)
                    .foregroundStyle(set.completed ? .green : .secondary)
                numberField("kg", value: $set.weightKg)
                Text("×").foregroundStyle(.secondary)
                intField("次", value: $set.reps)
                Spacer()
                Button { showNote.toggle() } label: {
                    Image(systemName: hasNote ? "text.bubble.fill" : "text.bubble")
                        .foregroundStyle(hasNote ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }.buttonStyle(.plain)
                Button {
                    set.completed.toggle()
                    onChange()
                    // 标记完成（而非取消）时自动开启组间休息计时。
                    if set.completed { onComplete() }
                } label: {
                    Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(set.completed ? .green : .secondary)
                }.buttonStyle(.plain)
            }
            if showNote || hasNote {
                TextField("单组备注", text: Binding(
                    get: { set.note ?? "" },
                    set: { set.note = $0.nilIfEmpty; onChange() }
                ))
                .font(.caption).textFieldStyle(.roundedBorder)
            }
        }
    }

    private var hasNote: Bool { !(set.note ?? "").isEmpty }

    private func numberField(_ placeholder: String, value: Binding<Double?>) -> some View {
        TextField(placeholder, text: Binding(
            get: { value.wrappedValue.map { formatKg($0) } ?? "" },
            set: { value.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")); onChange() }
        ))
        .keyboardType(.decimalPad).frame(width: 64).multilineTextAlignment(.center)
        .textFieldStyle(.roundedBorder)
    }

    private func intField(_ placeholder: String, value: Binding<Int?>) -> some View {
        TextField(placeholder, text: Binding(
            get: { value.wrappedValue.map(String.init) ?? "" },
            set: { value.wrappedValue = Int($0); onChange() }
        ))
        .keyboardType(.numberPad).frame(width: 50).multilineTextAlignment(.center)
        .textFieldStyle(.roundedBorder)
    }
}
