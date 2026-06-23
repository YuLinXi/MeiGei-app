import SwiftUI
import SwiftData
import OSLog

// MARK: - 计划列表（Screen 05，Neon 改版）

/// 计划列表：单一「我的计划」列表——最近在用的计划置顶为富信息卡，其余普通行；
/// 「推荐模板」段在内置动作库数据采集完成前不渲染（开关 `showRecommendedTemplates`）。
struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]
    @State private var creatingNew = false
    /// 计划详情导航：用绑定式 navigationDestination(item:) 而非 NavigationLink(value:)。
    /// 本工程是「全局唯一 NavigationStack 包 TabView」，类型注册式 navigationDestination(for:)
    /// 从 TabView 子页注册不进外层 stack，value 链接点了不跳；绑定式不依赖类型注册，可靠跳转。
    @State private var selectedPlan: WorkoutPlan?

    /// 「推荐模板」段开关：依赖尚未采集的内置动作库（见 CLAUDE.md 待办「数据工程未完」）。
    /// 数据就绪后置 `true` 即恢复整段（段标题 + `recommendedCard`），无需改动其它代码。
    private static let showRecommendedTemplates = false

    /// 最近在用的计划（列表置顶富卡）= 近 14 天内有 workout 关联 planId 的计划；
    /// 否则取最近更新的一个；若无任何计划则为 nil。判定逻辑复用 `WorkoutPlan.active`，与首页一致。
    private var activePlan: WorkoutPlan? {
        if let id = historyStore.home.activePlanId,
           let plan = plans.first(where: { $0.localId == id }) {
            return plan
        }
        if let recent = plans.first(where: { historyStore.home.recentPlanIds.contains($0.localId) }) {
            return recent
        }
        return plans.first
    }

    private var otherPlans: [WorkoutPlan] {
        guard let active = activePlan else { return plans }
        return plans.filter { $0.localId != active.localId }
    }

    private func usage(for plan: WorkoutPlan) -> PlanUsageSummary {
        historyStore.planUsage[plan.localId] ?? .empty
    }

    private func behaviorSummary(for plan: WorkoutPlan, usage: PlanUsageSummary) -> String {
        switch plan.mode {
        case .strict:
            "严格执行 · 不回写"
        case .adaptive:
            usage.completedCount == 0 ? "默认 4×10 起步 · 完成后自动更新" : "下次依据：上次完成实绩"
        }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // 单一「我的计划」列表：最近在用的计划置顶为富信息卡（featuredCard），
                        // 其余按更新时间普通行展示。计划数为 1 时也只此一张富卡，不再出现
                        // 「进行中」与「还没有计划」并存的矛盾。空态仅当确实没有任何计划。
                        Text("我的计划").eyebrowStyle()
                        if plans.isEmpty {
                            emptyMineCard
                        } else {
                            VStack(spacing: Theme.Spacing.md) {
                                if let active = activePlan {
                                    featuredCard(active)
                                }
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
        .onAppear { WorkoutPerformanceMonitor.event("plan.list.appear") }
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
        let usage = usage(for: plan)
        let lastTrained = usage.lastTrainedAt
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
                    Text(behaviorSummary(for: plan, usage: usage))
                        .font(Theme.Font.mono(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.muted)
                    HStack(spacing: Theme.Spacing.xl) {
                        metaCol(title: "累计", value: "\(usage.completedCount) 次")
                        metaCol(title: "总组数", value: "\(plan.totalSuggestedSets)")
                        metaCol(title: "模式", value: plan.mode.displayName)
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
        let usage = usage(for: plan)
        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(plan.name)
                        .font(Theme.Font.body(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                    modePill(plan.mode)
                }
                Text("\(plan.items.count) 个动作 · \(plan.totalSuggestedSets) 组")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
                Text(behaviorSummary(for: plan, usage: usage))
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func modePill(_ mode: WorkoutPlanMode) -> some View {
        Text(mode.displayName)
            .font(Theme.Font.mono(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.Color.surface2, in: Capsule())
            .foregroundStyle(mode == .adaptive ? Theme.Color.accent : Theme.Color.muted)
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
    @Environment(RestTimerController.self) private var restTimer
    @Environment(WorkoutHistoryStore.self) private var historyStore

    @State private var pickingExercise = false
    @State private var editingItem: PlanItem?
    @State private var editing = false
    @State private var showingMode = false
    @State private var confirmingDelete = false
    @State private var decodeError: String?
    /// 待删除动作行（左滑删除二次确认）+ 该行全局坐标，供确认卡定位于其正下方。
    @State private var pendingDeleteItem: PlanItem?
    @State private var deleteRect: CGRect = .zero
    /// 左滑删除协调器：同一时刻仅一张展开，点击别处自动收回（详见 SwipeDeleteList）。
    @State private var swipe = SwipeRowCoordinator()
    /// 显式动作排序面板。
    @State private var showingOrderEditor = false
    /// 单一活跃会话守卫：冲突态 + 待新建闭包 + 导航打开的会话。
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    /// 仅驱动冲突弹窗显隐，与数据分离——避免弹窗淡出关闭时清空 `conflict` 致动作回调读到 nil。
    @State private var showConflict = false
    @State private var startedSession: Workout?
    /// 严格计划缺失必填预设时，阻止开始训练并展示原因。
    @State private var strictStartError: String?

    private static let log = Logger(subsystem: "com.yulinxi.app.DontLift", category: "PlanDetail")

    private var orderedItems: [PlanItem] {
        plan.items.sorted { $0.orderIndex < $1.orderIndex }
    }

    // 总组数下沉为 `WorkoutPlan` 扩展，与计划列表 featured 卡共用同一算法。
    private var totalSets: Int { plan.totalSuggestedSets }

    private var planOrderItems: [ExerciseOrderItem] {
        orderedItems.map {
            ExerciseOrderItem(id: $0.itemId, title: $0.exerciseName, subtitle: subtitle($0))
        }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                // 对齐原型 .scroll：children gap 11、横向 17、顶部 4。
                VStack(alignment: .leading, spacing: 11) {
                    header
                    statRow
                    modeInfoCard
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
                        ) { item in
                            planItemRow(item)
                        }
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
        .onAppear { WorkoutPerformanceMonitor.event("plan.detail.appear") }
        // 子页统一导航栏：圆形返回 + ⋯ 菜单（标题留空，计划名在内容区大字呈现）。
        .paperToolbar(onBack: { dismiss() }) {
            CircleIconMenu(systemName: "ellipsis") {
                Button { editing = true } label: { Label("重命名计划", systemImage: "pencil") }
                Button(role: .destructive) { confirmingDelete = true } label: { Label("删除计划", systemImage: "trash") }
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
                                      exerciseName: pick.name, orderIndex: items.count,
                                      suggestedSets: PlanDefaults.suggestedSets,
                                      suggestedReps: PlanDefaults.suggestedReps))
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
        .sheet(isPresented: $showingMode) {
            PlanModeSheet(plan: plan)
        }
        .sheet(isPresented: $showingOrderEditor) {
            ExerciseOrderEditorSheet(title: "调整动作顺序",
                                     items: planOrderItems,
                                     onCommit: applyPlanItemOrder)
        }
        .navigationDestination(item: $startedSession) { WorkoutLoggingView(workout: $0) }
        // 训练冲突二次确认：统一为纸感弹窗。无独立取消按钮，点蒙层即取消；
        // 「丢弃并开始新训练」为主（红填充）、「继续训练」为次（描边）。
        .paperConfirmDialog(
            isPresented: $showConflict,
            title: "已有进行中的训练",
            message: "同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。",
            confirmTitle: "丢弃并开始新训练",
            secondaryTitle: "继续训练",
            onSecondary: {
                if let existing = conflict { startedSession = existing }
                clearConflict()
            },
            showCancel: false,
            onConfirm: {
                if let existing = conflict {
                    WorkoutSession.discard(existing, in: modelContext)
                    restTimer.stop()   // 丢弃旧会话即停止其可能进行中的休息计时全套。
                    if let build = pendingBuild { commit(build) }
                }
                clearConflict()
            }
        )
        .paperConfirmDialog(
            isPresented: Binding(
                get: { strictStartError != nil },
                set: { if !$0 { strictStartError = nil } }
            ),
            title: "计划还不能开始",
            message: strictStartError ?? "",
            confirmTitle: "知道了",
            destructive: false,
            showCancel: false,
            onConfirm: { strictStartError = nil }
        )
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
            statCell(n: plan.mode.displayName, k: "模式")
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
        HStack {
            Text("训练动作")
                .font(Theme.Font.mono(size: 10))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Color.muted)
            Spacer(minLength: 8)
            if orderedItems.count > 1 {
                Button {
                    swipe.collapseAll()
                    showingOrderEditor = true
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                        .font(Theme.Font.body(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("调整动作顺序")
            }
        }
        .padding(.horizontal, 2)
    }

    // 动作行（独立卡片，与训练首页「最近训练」统一观感与左滑交互）。
    // 行外层卡片与左滑交互由 `SwipeDeleteList` 统一装配，此处只产出卡片内容。点击行或编辑图标进入建议参数编辑。
    private func planItemRow(_ item: PlanItem) -> some View {
        // 序号按当前顺序推出（动作数极少，firstIndex 开销可忽略）。
        let index = (orderedItems.firstIndex { $0.itemId == item.itemId } ?? 0) + 1
        let preview = PlanPrescriptionPreview.make(for: item, mode: plan.mode,
                                                   lookup: historyStore.planLookup, planId: plan.localId)
        let showsSource = plan.mode != .strict
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
                Text(preview.summaryText)
                    .font(Theme.Font.mono(size: 12))
                    .foregroundStyle(Theme.Color.muted)
                if showsSource {
                    Text(preview.detailText)
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                }
            }
            Spacer(minLength: 0)
            if showsSource {
                sourceBadge(preview.badgeText)
            }
            editItemButton(item)
        }
        .cardStyle()
    }

    private func editItemButton(_ item: PlanItem) -> some View {
        Button {
            swipe.collapseAll()
            editingItem = item
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑\(item.exerciseName)")
    }

    private var modeInfoCard: some View {
        Button { showingMode = true } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: plan.mode == .adaptive ? "arrow.triangle.2.circlepath" : "lock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.mode == .adaptive ? "自适应计划" : "严格计划")
                        .font(Theme.Font.body(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(plan.mode == .adaptive
                         ? "开始训练会按下方处方预填；完成后继续跟随实绩更新，跳过动作会保留。"
                         : "开始训练会复制计划预设；完成后不回写，每个动作需有组数与次数。")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("规则")
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func sourceBadge(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.mono(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Theme.Color.accentSoft, in: Capsule())
            .foregroundStyle(Theme.Color.accent)
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
        // Fork 规则（design.md D8）：复制 动作 + 组数 + 次数，清空重量（重量最私人）；副本默认自适应。
        let copy = WorkoutPlan(name: plan.name + " · 副本",
                               items: plan.items.map {
                                   PlanItem(itemId: UUID(),
                                            builtinExerciseCode: $0.builtinExerciseCode,
                                            customExerciseId: $0.customExerciseId,
                                            exerciseName: $0.exerciseName,
                                            orderIndex: $0.orderIndex,
                                            suggestedSets: $0.suggestedSets,
                                            suggestedReps: $0.suggestedReps,
                                            suggestedWeightKg: nil)
                               },
                               mode: .adaptive,
                               forkedFrom: plan.localId)
        modelContext.insert(copy)
        try? modelContext.save()
    }

    /// 单一活跃会话守卫：存在进行中会话时弹「继续 / 丢弃」，否则新建并进入。
    private func startWorkout() {
        if plan.mode == .strict {
            let missing = PlanPrefill.missingStrictRequiredItems(in: plan.items)
            guard missing.isEmpty else {
                strictStartError = PlanPrefill.strictRequirementMessage(for: missing)
                return
            }
        }
        if let existing = WorkoutSession.activeSession(in: modelContext) {
            pendingBuild = buildFromPlan
            conflict = existing
            showConflict = true
        } else {
            commit(buildFromPlan)
        }
    }

    /// 关闭冲突弹窗并清理冲突态（动作执行完或取消后调用）。
    private func clearConflict() {
        conflict = nil
        pendingBuild = nil
    }

    private func buildFromPlan() -> Workout {
        let w = Workout(planId: plan.localId, title: plan.name)
        let mode = plan.mode
        for (i, item) in orderedItems.enumerated() {
            let ex = WorkoutExercise(
                builtinExerciseCode: item.builtinExerciseCode,
                customExerciseId: item.customExerciseId,
                exerciseName: item.exerciseName,
                orderIndex: i,
                planItemId: item.itemId   // 自适应回写合并主键（design.md D3）
            )
            // 按模式落值（design.md D1/D4）：严格整组复制预设；自适应历史优先→回退预设。
            ex.sets = PlanPrefill.sets(for: item, mode: mode, lookup: historyStore.planLookup)
            w.exercises.append(ex)
        }
        return w
    }

    private func commit(_ build: () -> Workout) {
        let w = build()
        modelContext.insert(w)
        try? modelContext.save()
        historyStore.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)
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

    private func applyPlanItemOrder(_ orderedIds: [UUID]) {
        var byId = Dictionary(uniqueKeysWithValues: plan.items.map { ($0.itemId, $0) })
        var items = orderedIds.compactMap { byId.removeValue(forKey: $0) }
        items.append(contentsOf: byId.values.sorted { $0.orderIndex < $1.orderIndex })
        guard items.map(\.itemId) != orderedItems.map(\.itemId) else { return }
        for i in items.indices { items[i].orderIndex = i }
        plan.items = items
        plan.markDirty()
        try? modelContext.save()
        Theme.Haptics.selection()
    }
}

// MARK: - 计划编辑器（仅用于新建空模板入口；详情页内联编辑动作项）

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existing: WorkoutPlan?
    @State private var name: String
    @State private var mode: WorkoutPlanMode

    init(plan: WorkoutPlan?) {
        self.existing = plan
        _name = State(initialValue: plan?.name ?? "")
        _mode = State(initialValue: plan?.mode ?? .adaptive)
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
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("计划模式").eyebrowStyle()
                    modeOption(.adaptive)
                    modeOption(.strict)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        // 子页统一导航栏：圆形返回 + 右侧保存键（双环处理收口在 paperToolbar）。
        .paperToolbar(title: existing == nil ? "新建计划" : "编辑计划", onBack: { dismiss() }) {
            Button("保存") { save() }
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .tint(Theme.Color.accent)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmed
            existing.mode = mode
            existing.markDirty()
        } else {
            let plan = WorkoutPlan(name: trimmed, mode: mode)
            modelContext.insert(plan)
        }
        try? modelContext.save()
        dismiss()
    }

    @ViewBuilder private func modeOption(_ candidate: WorkoutPlanMode) -> some View {
        let selected = mode == candidate
        Button { mode = candidate } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.muted)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.title).font(Theme.Font.l2).foregroundStyle(Theme.Color.fg)
                    Text(candidate.detailText).font(Theme.Font.body(size: 12)).foregroundStyle(Theme.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "重命名",
                cancelTitle: "取消",
                confirmTitle: "完成",
                confirmEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Color.bg)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        plan.name = trimmed
        plan.markDirty()
        dismiss()
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
        _sets = State(initialValue: item.suggestedSets ?? PlanDefaults.suggestedSets)
        _reps = State(initialValue: item.suggestedReps ?? PlanDefaults.suggestedReps)
        _weight = State(initialValue: item.suggestedWeightKg.map { formatKg($0) } ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "编辑动作",
                cancelTitle: "取消",
                confirmTitle: "完成",
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Color.bg)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.medium])
    }

    private func save() {
        var updated = original
        updated.suggestedSets = sets
        updated.suggestedReps = reps
        updated.suggestedWeightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
        onSave(updated)
        dismiss()
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

// MARK: - 计划模式选择 sheet（task 6.2/6.3）

/// 计划模式标识 + 规则说明 + 切换（切到严格模式校验必填）。
struct PlanModeSheet: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draftMode: WorkoutPlanMode
    @State private var error: String?
    @State private var confirmingChange = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _draftMode = State(initialValue: plan.mode)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "计划模式",
                cancelTitle: "取消",
                confirmTitle: "确定",
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: requestConfirm
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                option(.adaptive)
                option(.strict)
                if let error {
                    Text(error).font(Theme.Font.body(size: 12)).foregroundStyle(Theme.Color.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Color.bg)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.medium, .large])
        .paperConfirmDialog(
            isPresented: $confirmingChange,
            title: "确认切换计划模式？",
            message: confirmMessage,
            confirmTitle: "确认切换",
            destructive: false,
            onConfirm: { applyDraftMode() }
        )
    }

    @ViewBuilder private func option(_ m: WorkoutPlanMode) -> some View {
        let selected = draftMode == m
        Button { selectDraft(m) } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.muted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.title).font(Theme.Font.l2).foregroundStyle(Theme.Color.fg)
                    Text(m.detailText).font(Theme.Font.body(size: 12)).foregroundStyle(Theme.Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var confirmMessage: String {
        "将「\(plan.name)」从\(plan.mode.displayName)模式切换为\(draftMode.displayName)模式。切换后开始训练与完成回写规则会按新模式执行。"
    }

    /// 点选只改 sheet 内草稿，不写计划实体。
    private func selectDraft(_ m: WorkoutPlanMode) {
        draftMode = m
        error = nil
    }

    /// 点击「确定」后才校验与二次确认；确认前不写入 `WorkoutPlan.mode`。
    private func requestConfirm() {
        guard draftMode != plan.mode else {
            dismiss()
            return
        }
        if draftMode == .strict {
            let missing = PlanPrefill.missingStrictRequiredItems(in: plan.items)
            if !missing.isEmpty {
                error = "切换严格模式前，请先补齐这些动作的组数与次数：" + missing.map(\.exerciseName).joined(separator: "、")
                return
            }
        }
        error = nil
        confirmingChange = true
    }

    private func applyDraftMode() {
        plan.mode = draftMode
        plan.markDirty()
        try? modelContext.save()
        dismiss()
    }
}

/// 去掉多余小数（80.0 → "80"，72.5 → "72.5"）。
func formatKg(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}
