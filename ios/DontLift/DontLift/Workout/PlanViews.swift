import SwiftUI
import SwiftData
import OSLog

// MARK: - 计划列表（Screen 05，Neon 改版）

/// 计划列表：「进行中」featured 卡 + 「我的计划」两段；「推荐模板」段在内置动作库
/// 数据采集完成前不渲染（开关 `showRecommendedTemplates`）。
struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var creatingNew = false
    /// 计划详情导航：用绑定式 navigationDestination(item:) 而非 NavigationLink(value:)。
    /// 本工程是「全局唯一 NavigationStack 包 TabView」，类型注册式 navigationDestination(for:)
    /// 从 TabView 子页注册不进外层 stack，value 链接点了不跳；绑定式不依赖类型注册，可靠跳转。
    @State private var selectedPlan: WorkoutPlan?

    /// 「推荐模板」段开关：依赖尚未采集的内置动作库（见 CLAUDE.md 待办「数据工程未完」）。
    /// 数据就绪后置 `true` 即恢复整段（段标题 + `recommendedCard`），无需改动其它代码。
    private static let showRecommendedTemplates = false

    /// 「进行中」= 最近 14 天内有 workout 关联 planId 的计划；
    /// 否则取最近更新的一个；若无任何计划则为 nil。判定逻辑复用 `WorkoutPlan.active`，与首页一致。
    private var activePlan: WorkoutPlan? {
        WorkoutPlan.active(in: plans, workouts: workouts)
    }

    private var otherPlans: [WorkoutPlan] {
        guard let active = activePlan else { return plans }
        return plans.filter { $0.localId != active.localId }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if let active = activePlan {
                            Text("进行中").eyebrowStyle()
                            featuredCard(active)
                        }

                        Text("我的计划").eyebrowStyle()
                        if otherPlans.isEmpty {
                            emptyMineCard
                        } else {
                            VStack(spacing: Theme.Spacing.md) {
                                ForEach(otherPlans) { plan in
                                    Button { selectedPlan = plan } label: { planCard(plan) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }

                        // 内置动作库数据采集完成前不渲染「推荐模板」段（开关见 showRecommendedTemplates）。
                        if Self.showRecommendedTemplates {
                            Text("推荐模板").eyebrowStyle()
                            recommendedCard
                        }

                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
        // 自绘大标题头（与训练/动作 Tab 一致），隐藏系统导航栏。
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedPlan) { PlanDetailView(plan: $0) }
        .navigationDestination(isPresented: $creatingNew) {
            PlanEditorView(plan: nil)
        }
    }

    // MARK: Header（大标题「计划」+ 右侧圆形朱砂红加号，与动作 Tab 一致）

    private var header: some View {
        HStack {
            Text("计划")
                .font(Theme.Font.display(size: 36, weight: .heavy))
                .tracking(-1.08)
                .foregroundStyle(Theme.Color.fg)
            Spacer(minLength: 0)
            CircleAddButton(action: { creatingNew = true }, accessibilityLabel: "新建计划")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func featuredCard(_ plan: WorkoutPlan) -> some View {
        // 关联此计划的已完成训练（用于「累计次数」与 eyebrow 的「上次训练」）。
        // 全部可由本地记录重算，不展示 MVP 不支持的周计划/周期化语义。
        let done = workouts.filter { $0.planId == plan.localId && $0.endedAt != nil }
        let lastTrained = done.map(\.startedAt).max()
        Button { selectedPlan = plan } label: {
            HStack(spacing: 0) {
                // 左侧朱砂红竖条
                Rectangle().fill(Theme.Color.accent).frame(width: 4)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Text(lastTrained.map { "上次训练 · \($0.formatted(.relative(presentation: .named)))" } ?? "未开始")
                            .font(Theme.Font.mono(size: 11, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.Color.accentSoft, in: Capsule())
                            .foregroundStyle(Theme.Color.accent)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.Color.muted)
                    }
                    Text(plan.name)
                        .font(Theme.Font.l1)
                        .foregroundStyle(Theme.Color.fg)
                    Text("\(plan.items.count) 个动作")
                        .font(Theme.Font.l4)
                        .foregroundStyle(Theme.Color.fg2)
                    HStack(spacing: Theme.Spacing.xl) {
                        metaCol(title: "累计", value: "\(done.count) 次")
                        metaCol(title: "总组数", value: "\(plan.totalSuggestedSets)")
                        metaCol(title: "预计", value: "≈\(plan.estimatedMinutes) 分")
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Color.border, lineWidth: 1)
            )
            .paperShadow(.sm, cornerRadius: Theme.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    private func metaCol(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).eyebrowStyle()
            Text(value).numStyle(size: 18).foregroundStyle(Theme.Color.fg)
        }
    }

    private func planCard(_ plan: WorkoutPlan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text("\(plan.items.count) 个动作 · \(plan.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var emptyMineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有计划")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("点右上 + 新建一个训练模板")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var recommendedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PPL · 推/拉/腿 6 周").font(Theme.Font.body(size: 15, weight: .semibold)).foregroundStyle(Theme.Color.fg)
            Text("即将上线 · 数据采集中").font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .opacity(0.6)
    }
}

// MARK: - 计划详情（Screen 06，Neon 改版）

struct PlanDetailView: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pickingExercise = false
    @State private var editingItem: PlanItem?
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var decodeError: String?
    /// 待删除动作行（左滑删除二次确认）+ 该行全局坐标，供确认卡定位于其正下方。
    @State private var pendingDeleteItem: PlanItem?
    @State private var deleteRect: CGRect = .zero
    /// 左滑删除协调器：同一时刻仅一张展开，点击别处自动收回（详见 SwipeDeleteList）。
    @State private var swipe = SwipeRowCoordinator()
    /// 单一活跃会话守卫：冲突态 + 待新建闭包 + 导航打开的会话。
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    @State private var startedSession: Workout?

    private static let log = Logger(subsystem: "com.yulinxi.app.DontLift", category: "PlanDetail")

    private var orderedItems: [PlanItem] {
        plan.items.sorted { $0.orderIndex < $1.orderIndex }
    }

    // 总组数 / 预计时长下沉为 `WorkoutPlan` 扩展，与计划列表 featured 卡共用同一算法。
    private var totalSets: Int { plan.totalSuggestedSets }
    private var estimatedMinutes: Int { plan.estimatedMinutes }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                // 对齐原型 .scroll：children gap 11、横向 17、顶部 4。
                VStack(alignment: .leading, spacing: 11) {
                    header
                    statRow
                    sectionLabel

                    if let err = decodeError {
                        decodeErrorCard(err)
                    } else if orderedItems.isEmpty {
                        emptyExercisesCard
                    } else {
                        // 与首页「最近训练」一致：每行独立卡片（带间距/描边/阴影）+ 统一左滑交互。
                        SwipeDeleteList(
                            data: orderedItems,
                            id: \.itemId,
                            coordinator: swipe,
                            onTap: { editingItem = $0 },
                            onDelete: { item, rect in
                                deleteRect = rect
                                pendingDeleteItem = item
                            }
                        ) { item in planItemRow(item) }
                    }

                    addExerciseCTA
                }
                .padding(.horizontal, 17)
                .padding(.top, 4)
                .padding(.bottom, 12)
                // 点击列表任意其它区域（含列表下方空白）：收回当前展开的左滑动作行。
                .collapseSwipeOnTap(swipe)
            }
        }
        // 对齐原型 .footer：scroll 与 footer 为兄弟（内容不穿底栏），底栏实底 + 顶部分隔线。
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // 圆形返回 / ⋯ 菜单（沿用 WorkoutViews 既定约定；iOS 26 关掉系统 Liquid Glass 圆背景避免双环）。
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(systemName: "chevron.left", action: { dismiss() }, size: 32)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { menuButton }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(systemName: "chevron.left", action: { dismiss() }, size: 32)
                }
                ToolbarItem(placement: .topBarTrailing) { menuButton }
            }
        }
        .paperConfirmDialog(
            isPresented: $confirmingDelete,
            title: "删除计划?",
            message: "将删除「\(plan.name)」,此操作不可撤销。",
            confirmTitle: "删除计划",
            onConfirm: { delete() }
        )
        // 删除动作二次确认：复用首页「最近训练」的透明浮层 + 锚定卡片，文案改「删除动作」。
        .fullScreenCover(isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { if !$0 { pendingDeleteItem = nil } })) {
            if let item = pendingDeleteItem {
                DeleteConfirmCover(
                    anchorRect: deleteRect,
                    confirmTitle: "删除动作",
                    onConfirm: {
                        Theme.Haptics.notification(.warning)
                        deleteItem(item)
                    },
                    onClose: { pendingDeleteItem = nil }
                )
                .presentationBackground(.clear)
            }
        }
        .transaction(value: pendingDeleteItem != nil) { $0.disablesAnimations = true }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in
                var items = plan.items
                items.append(PlanItem(builtinExerciseCode: pick.builtinCode, customExerciseId: pick.customId,
                                      exerciseName: pick.name, orderIndex: items.count))
                plan.items = items
                plan.markDirty()
                try? modelContext.save()
            }
        }
        .sheet(item: $editingItem) { item in
            PlanItemEditorView(item: item) { updated in
                var items = plan.items
                if let idx = items.firstIndex(where: { $0.itemId == updated.itemId }) {
                    items[idx] = updated
                    plan.items = items
                    plan.markDirty()
                    try? modelContext.save()
                }
            }
        }
        .sheet(isPresented: $editing) {
            PlanRenameSheet(plan: plan)
        }
        .navigationDestination(item: $startedSession) { WorkoutLoggingView(workout: $0) }
        .confirmationDialog("已有进行中的训练", isPresented: Binding(
            get: { conflict != nil },
            set: { if !$0 { conflict = nil; pendingBuild = nil } }), presenting: conflict) { existing in
            Button("继续训练") { startedSession = existing; pendingBuild = nil }
            Button("丢弃并开始新训练", role: .destructive) {
                WorkoutSession.discard(existing, in: modelContext)
                if let build = pendingBuild { commit(build) }
                pendingBuild = nil
            }
            Button("取消", role: .cancel) { pendingBuild = nil }
        } message: { _ in Text("同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。") }
    }

    // 对齐原型 .navbar ⋯：圆形钮 + Menu（重命名 / 删除走二次确认）。点 dots 用 fg2。
    private var menuButton: some View {
        Menu {
            Button { editing = true } label: { Label("重命名计划", systemImage: "pencil") }
            Button(role: .destructive) { confirmingDelete = true } label: { Label("删除计划", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 32, height: 32)
                .background(Theme.Color.surface, in: Circle())
                .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
        }
    }

    private var header: some View {
        // 对齐原型：eyebrow mono 10/.16em/muted；ptitle 30 weight 800/-.03em；间距 3。
        VStack(alignment: .leading, spacing: 3) {
            Text("PLAN · 训练模板")
                .font(Theme.Font.mono(size: 10))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Color.muted)
            Text(plan.name)
                .font(Theme.Font.display(size: 30, weight: .heavy))
                .tracking(-0.9)
                .foregroundStyle(Theme.Color.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // 对齐原型 .stat3：3 列居中 + 中缝 1px 分隔线；n=sans 22/800/-.025em，k=mono 9/.06em/muted。
    private var statRow: some View {
        HStack(spacing: 0) {
            statCell(n: "\(plan.items.count)", k: "动作")
            statDivider
            statCell(n: "\(totalSets)", k: "总组数")
            statDivider
            statCell(n: "≈\(estimatedMinutes)", k: "分钟")
        }
        .cardStyle(padding: 0)
    }

    private var statDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(width: 1, height: 40)
    }

    private func statCell(n: String, k: String) -> some View {
        VStack(spacing: 7) {
            Text(n)
                .font(Theme.Font.display(size: 22, weight: .heavy))
                .tracking(-0.55)
                .foregroundStyle(Theme.Color.fg)
            Text(k)
                .font(Theme.Font.mono(size: 9))
                .tracking(0.54)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 4)
    }

    // 对齐原型 .seclbl：mono 10/.1em/uppercase/muted。
    private var sectionLabel: some View {
        Text("动作")
            .font(Theme.Font.mono(size: 10))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Color.muted)
            .padding(.horizontal, 2)
    }

    // 动作行（独立卡片，与训练首页「最近训练」统一观感与左滑交互）：
    // 序号 mono 12/700/muted/宽 18 居中；名称 sans 15/600；参数 mono 12/muted；⋯ muted 17。
    // 行外层卡片与左滑交互由 `SwipeDeleteList` 统一装配，此处只产出卡片内容。点击行进建议参数编辑。
    private func planItemRow(_ item: PlanItem) -> some View {
        // 序号按当前顺序推出（动作数极少，firstIndex 开销可忽略）。
        let index = (orderedItems.firstIndex { $0.itemId == item.itemId } ?? 0) + 1
        return HStack(spacing: 11) {
            Text(String(format: "%02d", index))
                .font(Theme.Font.mono(size: 12, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.exerciseName)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle(item))
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "ellipsis")
                .font(.system(size: 17))
                .foregroundStyle(Theme.Color.muted)
        }
        .cardStyle()
    }

    private var emptyExercisesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有动作")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("点下方「+ 添加动作」开始编排")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // 对齐原型 .add-row：虚线 border2 1.5px、muted、12/600、padding 12、加号 15。
    private var addExerciseCTA: some View {
        Button { pickingExercise = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("添加动作")
                    .font(Theme.Font.body(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.Color.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.Color.border2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    /// jsonb 解码错误兜底卡（design.md D3）：当 SwiftData 反序列化 items 异常时显示。
    /// 实际 SwiftData 走 Codable，解码失败会在底层抛错；这里保留 UI 钩子方便未来 catch。
    private func decodeErrorCard(_ err: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("PLAN · ERROR").eyebrowStyle().foregroundStyle(Theme.Color.danger)
            Text("计划数据损坏，请重建")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.danger)
            Text(err)
                .font(Theme.Font.mono(size: 11))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Color.danger.opacity(0.55), lineWidth: 1)
        )
    }

    // 对齐原型 .footer：复制=ghost 次级键(自适应宽 + border2 + sh-sm)，开始=主键(flex1 + accent)；
    // 容器实底 bg + 顶部 1px 分隔线。主次对比靠填充 vs 描边，不靠尺寸。
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { duplicate() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                    Text("复制")
                        .font(Theme.Font.body(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.Color.fg)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.Color.border2, lineWidth: 1)
                )
                .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity),
                        radius: Theme.ShadowLevel.sm.radius, x: 0, y: Theme.ShadowLevel.sm.y)
            }
            .buttonStyle(PressableButtonStyle())

            Button { startWorkout() } label: {
                HStack(spacing: 6) {
                    Text("开始这次训练")
                        .font(Theme.Font.body(size: 15, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .shadow(color: Theme.Color.accent.opacity(0.24), radius: 7, x: 0, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Color.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
    }

    private func subtitle(_ item: PlanItem) -> String {
        // 对齐原型 .pm：「3 组 × 10 · 60 kg」/「3 组 × 12」；重量可空时仅显示组×次。
        var parts: [String] = []
        if let s = item.suggestedSets, let r = item.suggestedReps { parts.append("\(s) 组 × \(r)") }
        else if let s = item.suggestedSets { parts.append("\(s) 组") }
        if let w = item.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
        return parts.isEmpty ? "未设建议" : parts.joined(separator: " · ")
    }

    private func duplicate() {
        let copy = WorkoutPlan(name: plan.name + " · 副本",
                               items: plan.items.map {
                                   PlanItem(itemId: UUID(),
                                            builtinExerciseCode: $0.builtinExerciseCode,
                                            customExerciseId: $0.customExerciseId,
                                            exerciseName: $0.exerciseName,
                                            orderIndex: $0.orderIndex,
                                            suggestedSets: $0.suggestedSets,
                                            suggestedReps: $0.suggestedReps,
                                            suggestedWeightKg: $0.suggestedWeightKg)
                               },
                               forkedFrom: plan.localId)
        modelContext.insert(copy)
        try? modelContext.save()
    }

    /// 单一活跃会话守卫：存在进行中会话时弹「继续 / 丢弃」，否则新建并进入。
    private func startWorkout() {
        if let existing = WorkoutSession.activeSession(in: modelContext) {
            pendingBuild = buildFromPlan
            conflict = existing
        } else {
            commit(buildFromPlan)
        }
    }

    private func buildFromPlan() -> Workout {
        let w = Workout(planId: plan.localId, title: plan.name)
        for (i, item) in orderedItems.enumerated() {
            let ex = WorkoutExercise(
                builtinExerciseCode: item.builtinExerciseCode,
                customExerciseId: item.customExerciseId,
                exerciseName: item.exerciseName,
                orderIndex: i
            )
            let count = max(1, item.suggestedSets ?? 3)
            ex.sets = (0..<count).map { idx in WorkoutSet(setIndex: idx) }
            w.exercises.append(ex)
        }
        return w
    }

    private func commit(_ build: () -> Workout) {
        let w = build()
        modelContext.insert(w)
        try? modelContext.save()
        startedSession = w
    }

    private func delete() {
        plan.markDeleted()
        try? modelContext.save()
        dismiss()
    }

    /// 删除单个动作项：从 items 移除后按顺序重排 orderIndex，markDirty 并落盘。
    private func deleteItem(_ item: PlanItem) {
        var items = plan.items.sorted { $0.orderIndex < $1.orderIndex }
        items.removeAll { $0.itemId == item.itemId }
        for i in items.indices { items[i].orderIndex = i }
        plan.items = items
        plan.markDirty()
        try? modelContext.save()
    }
}

// MARK: - 计划编辑器（仅用于新建空模板入口；详情页内联编辑动作项）

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existing: WorkoutPlan?
    @State private var name: String

    init(plan: WorkoutPlan?) {
        self.existing = plan
        _name = State(initialValue: plan?.name ?? "")
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("CREATE · 新建计划").eyebrowStyle()
                TextField("", text: $name, prompt: Text("计划名称").foregroundColor(Theme.Color.muted))
                    .font(Theme.Font.display(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        .navigationTitle(existing == nil ? "新建计划" : "编辑计划")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // 圆形返回按钮（沿用 WorkoutDetailView/PlanDetailView 既定约定；
        // iOS 26 关掉系统 Liquid Glass 圆背景避免与自绘圆叠成双环）。
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(systemName: "chevron.left", action: { dismiss() }, size: 32)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(Theme.Font.body(size: 15, weight: .semibold))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .tint(Theme.Color.accent)
                }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    CircleIconButton(systemName: "chevron.left", action: { dismiss() }, size: 32)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(Theme.Font.body(size: 15, weight: .semibold))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .tint(Theme.Color.accent)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmed
            existing.markDirty()
        } else {
            let plan = WorkoutPlan(name: trimmed)
            modelContext.insert(plan)
        }
        try? modelContext.save()
        dismiss()
    }
}

/// 重命名 sheet（PlanDetailView 三点菜单触发）。
struct PlanRenameSheet: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(plan: WorkoutPlan) {
        self.plan = plan
        _name = State(initialValue: plan.name)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("RENAME").eyebrowStyle()
                    TextField("", text: $name)
                        .font(Theme.Font.display(size: 22, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
                    Spacer()
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        plan.name = name.trimmingCharacters(in: .whitespaces)
                        plan.markDirty()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(Theme.Color.accent)
                }
            }
        }
    }
}

// MARK: - 单个动作项的建议参数编辑（保留原 Form，sheet 内）

struct PlanItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sets: Int
    @State private var reps: Int
    @State private var weight: String
    private let original: PlanItem
    let onSave: (PlanItem) -> Void

    init(item: PlanItem, onSave: @escaping (PlanItem) -> Void) {
        self.original = item
        self.onSave = onSave
        _sets = State(initialValue: item.suggestedSets ?? 3)
        _reps = State(initialValue: item.suggestedReps ?? 10)
        _weight = State(initialValue: item.suggestedWeightKg.map { formatKg($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(original.exerciseName)
                        .font(Theme.Font.l1)
                        .foregroundStyle(Theme.Color.fg)
                    // 建议组数
                    stepperRow(title: "建议组数") {
                        PaperStepper(value: sets, range: 1...20) { sets = $0 }
                    }
                    // 建议次数
                    stepperRow(title: "建议次数") {
                        PaperStepper(value: reps, range: 1...100) { reps = $0 }
                    }
                    // 建议重量（可空）
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("建议重量 (kg)").eyebrowStyle()
                        TextField("可空", text: $weight)
                            .keyboardType(.decimalPad)
                            .paperField()
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        var updated = original
                        updated.suggestedSets = sets
                        updated.suggestedReps = reps
                        updated.suggestedWeightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
                        onSave(updated)
                        dismiss()
                    }
                    .tint(Theme.Color.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// 标签 + 右侧控件一行（卡片容器）。
    private func stepperRow<Control: View>(title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title).font(Theme.Font.l2).foregroundStyle(Theme.Color.fg)
            Spacer()
            control()
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

/// 去掉多余小数（80.0 → "80"，72.5 → "72.5"）。
func formatKg(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}
