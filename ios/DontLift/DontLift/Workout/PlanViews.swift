import SwiftUI
import SwiftData
import OSLog

// MARK: - 计划列表

private struct PlanGroupSection: Identifiable {
    let id: String
    let group: WorkoutPlanGroup?
    let title: String
    let plans: [WorkoutPlan]

    var groupId: UUID? { group?.localId }
}

private enum PlanGroupEditorTarget: Identifiable {
    case create(sortOrder: Int)
    case rename(WorkoutPlanGroup)

    var id: String {
        switch self {
        case .create: "create"
        case .rename(let group): "rename-\(group.localId)"
        }
    }
}

private struct PlanOrderTarget: Identifiable {
    let id: String
    let title: String
    let groupId: UUID?
}

private struct PlanEditorRoute: Identifiable, Hashable {
    let id = UUID()
    let groupId: UUID?
}

private func sortedPlanGroups(_ groups: [WorkoutPlanGroup]) -> [WorkoutPlanGroup] {
    groups.sorted {
        if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
        return $0.updatedAt > $1.updatedAt
    }
}

private func sortedPlans(_ plans: [WorkoutPlan]) -> [WorkoutPlan] {
    plans.sorted {
        if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
        return $0.updatedAt > $1.updatedAt
    }
}

private enum PlanListCardPosition {
    case single
    case first
    case middle
    case last
}

private extension View {
    func planListAttachedCardStyle(
        position: PlanListCardPosition = .single,
        padding: EdgeInsets = EdgeInsets(top: Theme.Spacing.md,
                                         leading: Theme.Spacing.md,
                                         bottom: Theme.Spacing.md,
                                         trailing: Theme.Spacing.md)
    ) -> some View {
        let radius = Theme.Radius.md
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(topLeading: position == .middle || position == .last ? 0 : radius,
                               bottomLeading: position == .first || position == .middle ? 0 : radius,
                               bottomTrailing: position == .first || position == .middle ? 0 : radius,
                               topTrailing: position == .middle || position == .last ? 0 : radius),
            style: .continuous
        )
        return self
            .padding(padding)
            .background(Theme.Color.surface, in: shape)
            .overlay(shape.stroke(Theme.Color.border, lineWidth: 1))
            .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity),
                    radius: Theme.ShadowLevel.sm.radius,
                    x: 0,
                    y: Theme.ShadowLevel.sm.y)
    }
}

/// 计划列表：按分组管理训练模板；所有计划使用同一标准卡片。
struct PlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(GlobalMessageCenter.self) private var globalMessage
    @Query(filter: #Predicate<WorkoutPlanGroup> { $0.deletedAt == nil },
           sort: \WorkoutPlanGroup.sortOrder)
    private var groups: [WorkoutPlanGroup]
    @Query(filter: #Predicate<WorkoutPlan> { $0.deletedAt == nil },
           sort: \WorkoutPlan.sortOrder)
    private var plans: [WorkoutPlan]
    @State private var creatingPlanRoute: PlanEditorRoute?
    @State private var groupEditor: PlanGroupEditorTarget?
    @State private var deletingGroup: WorkoutPlanGroup?
    @State private var showingGroupOrderEditor = false
    @State private var planOrderTarget: PlanOrderTarget?
    @State private var expandedSectionId: String?
    /// 计划详情导航：用绑定式 navigationDestination(item:) 而非 NavigationLink(value:)。
    /// 本工程是「全局唯一 NavigationStack 包 TabView」，类型注册式 navigationDestination(for:)
    /// 从 TabView 子页注册不进外层 stack，value 链接点了不跳；绑定式不依赖类型注册，可靠跳转。
    @State private var selectedPlan: WorkoutPlan?

    /// 「推荐模板」段开关：依赖尚未采集的内置动作库（见 CLAUDE.md 待办「数据工程未完」）。
    /// 数据就绪后置 `true` 即恢复整段（段标题 + `recommendedCard`），无需改动其它代码。
    private static let showRecommendedTemplates = false

    private var orderedGroups: [WorkoutPlanGroup] { sortedPlanGroups(groups) }
    private var validGroupIds: Set<UUID> { Set(groups.map(\.localId)) }
    private var orderedPlans: [WorkoutPlan] { sortedPlans(plans) }
    private var isCompletelyEmpty: Bool { groups.isEmpty && plans.isEmpty }
    private var sectionIds: [String] { sections.map(\.id) }
    private var totalSuggestedSets: Int { orderedPlans.reduce(0) { $0 + $1.totalSuggestedSets } }
    private var planListOverview: String {
        if orderedPlans.isEmpty {
            return orderedGroups.isEmpty ? "还没有分组和计划" : "\(orderedGroups.count) 个分组 · 0 个计划"
        }
        if orderedGroups.isEmpty {
            return "未分组 · \(orderedPlans.count) 个计划 · \(totalSuggestedSets) 组"
        }
        return "\(orderedGroups.count) 个分组 · \(orderedPlans.count) 个计划 · \(totalSuggestedSets) 组"
    }
    private var sectionToggleAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    private var sections: [PlanGroupSection] {
        let grouped = Dictionary(grouping: orderedPlans) { plan in resolvedGroupId(for: plan) }
        var result = orderedGroups.map { group in
            PlanGroupSection(id: group.localId.uuidString,
                             group: group,
                             title: group.name,
                             plans: grouped[group.localId] ?? [])
        }
        if let ungrouped = grouped[nil], !ungrouped.isEmpty {
            result.append(PlanGroupSection(id: "ungrouped", group: nil, title: "未分组", plans: ungrouped))
        }
        return result
    }

    private var groupOrderItems: [ExerciseOrderItem] {
        orderedGroups.map {
            ExerciseOrderItem(id: $0.localId, title: $0.name, subtitle: "\(plans(in: $0.localId).count) 个计划")
        }
    }

    private func usage(for plan: WorkoutPlan) -> PlanUsageSummary {
        historyStore.planUsage[plan.localId] ?? .empty
    }

    private func usageSummary(for plan: WorkoutPlan) -> String {
        let usage = usage(for: plan)
        return "累计训练 \(usage.completedCount) 次"
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if isCompletelyEmpty {
                            emptyMineCard
                        } else {
                            ForEach(sections) { section in
                                sectionView(section)
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
                    .animation(sectionToggleAnimation, value: expandedSectionId)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            WorkoutPerformanceMonitor.event("plan.list.appear")
            pruneExpandedSection()
        }
        .onChange(of: sectionIds) { _, _ in pruneExpandedSection() }
        .navigationDestination(item: $selectedPlan) { PlanDetailView(plan: $0) }
        .navigationDestination(item: $creatingPlanRoute) { route in
            PlanEditorView(plan: nil, initialGroupId: route.groupId)
        }
        .sheet(item: $groupEditor) { target in
            switch target {
            case .create(let sortOrder):
                PlanGroupEditorSheet(title: "新建分组", initialName: "") { name in
                    createGroup(name: name, sortOrder: sortOrder)
                }
            case .rename(let group):
                PlanGroupEditorSheet(title: "重命名分组", initialName: group.name) { name in
                    renameGroup(group, name: name)
                }
            }
        }
        .sheet(isPresented: $showingGroupOrderEditor) {
            ExerciseOrderEditorSheet(title: "调整分组顺序",
                                     items: groupOrderItems,
                                     onCommit: applyGroupOrder)
        }
        .sheet(item: $planOrderTarget) { target in
            ExerciseOrderEditorSheet(title: "调整\(target.title)顺序",
                                     items: planOrderItems(for: target.groupId),
                                     onCommit: { applyPlanOrder($0, groupId: target.groupId) })
        }
        .paperConfirmDialog(
            isPresented: Binding(
                get: { deletingGroup != nil },
                set: { if !$0 { deletingGroup = nil } }
            ),
            title: "删除分组?",
            message: deletingGroup.map { "「\($0.name)」下的计划会保留，并移动到未分组。" } ?? "",
            confirmTitle: "删除",
            onConfirm: {
                if let group = deletingGroup { deleteGroup(group) }
                deletingGroup = nil
            }
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("我的计划")
                    .font(Theme.Font.display(size: 36, weight: .heavy))
                    .foregroundStyle(Theme.Color.fg)
                Text(planListOverview)
                    .font(Theme.Font.mono(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            CircleAddMenu(items: headerMenuItems, accessibilityLabel: "添加计划或分组")
                .padding(.top, 4)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var headerMenuItems: [PaperMenuItem] {
        var items = [
            PaperMenuItem(title: "新建计划", systemImage: "doc.badge.plus") {
                creatingPlanRoute = PlanEditorRoute(groupId: nil)
            },
            PaperMenuItem(title: "新建分组", systemImage: "folder.badge.plus") {
                groupEditor = .create(sortOrder: nextGroupSortOrder())
            }
        ]
        if orderedGroups.count > 1 {
            items.append(PaperMenuItem(title: "调整分组顺序", systemImage: "arrow.up.arrow.down") {
                showingGroupOrderEditor = true
            })
        }
        return items
    }

    @ViewBuilder
    private func sectionView(_ section: PlanGroupSection) -> some View {
        let collapsed = isSectionCollapsed(section)
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(section, collapsed: collapsed)
                .zIndex(1)
            if !collapsed {
                VStack(spacing: 0) {
                    if section.plans.isEmpty {
                        emptyGroupCard()
                    } else {
                        ForEach(Array(section.plans.enumerated()), id: \.element.localId) { index, plan in
                            Button { selectedPlan = plan } label: {
                                planCard(plan, position: planCardPosition(index: index, count: section.plans.count))
                            }
                                .buttonStyle(PressableButtonStyle())
                                .accessibilityLabel("打开计划\(plan.name)")
                                .accessibilityHint("查看计划详情")
                        }
                    }
                }
                .padding(.top, Theme.Spacing.sm)
                .transition(.opacity)
                .zIndex(0)
            }
        }
    }

    private func sectionHeader(_ section: PlanGroupSection, collapsed: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                toggleSection(section)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(collapsed ? Theme.Color.muted : Theme.Color.accent)
                        .rotationEffect(.degrees(collapsed ? -90 : 0))
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(section.title)
                                .font(Theme.Font.body(size: 16, weight: .bold))
                                .foregroundStyle(Theme.Color.fg)
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                                .layoutPriority(1)
                            Text("\(section.plans.count)")
                                .font(Theme.Font.mono(size: 10, weight: .bold))
                                .foregroundStyle(Theme.Color.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.Color.accentSoft, in: Capsule())
                        }
                        Text(sectionSubtitle(section, collapsed: collapsed))
                            .font(Theme.Font.mono(size: 11))
                            .foregroundStyle(Theme.Color.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapsed ? "展开\(section.title)" : "折叠\(section.title)")
            .accessibilityValue("\(section.plans.count) 个计划")
            PaperActionMenuButton(items: sectionMenuItems(for: section),
                                  accessibilityLabel: "\(section.title)更多操作") { isPresented in
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isPresented ? Theme.Color.accent : Theme.Color.fg)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.leading, Theme.Spacing.sm)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background(Theme.Color.surface, in: sectionHeaderShape(collapsed: collapsed))
        .overlay(
            sectionHeaderShape(collapsed: collapsed)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity),
                radius: Theme.ShadowLevel.sm.radius,
                x: 0,
                y: Theme.ShadowLevel.sm.y)
    }

    private func sectionHeaderShape(collapsed: Bool) -> UnevenRoundedRectangle {
        let radius = Theme.Radius.md
        return UnevenRoundedRectangle(
            cornerRadii: .init(topLeading: radius,
                               bottomLeading: radius,
                               bottomTrailing: radius,
                               topTrailing: radius),
            style: .continuous
        )
    }

    private func sectionSubtitle(_ section: PlanGroupSection, collapsed: Bool) -> String {
        guard !section.plans.isEmpty else { return "空分组" }
        if collapsed {
            let names = section.plans.prefix(2).map(\.name).joined(separator: " / ")
            return section.plans.count > 2 ? "\(names) 等 \(section.plans.count) 个计划" : names
        }
        let sets = section.plans.reduce(0) { $0 + $1.totalSuggestedSets }
        return "\(section.plans.count) 个计划 · \(sets) 组"
    }

    private func sectionMenuItems(for section: PlanGroupSection) -> [PaperMenuItem] {
        var items = [
            PaperMenuItem(title: "在此分组新建计划", systemImage: "doc.badge.plus") {
                creatingPlanRoute = PlanEditorRoute(groupId: section.groupId)
            }
        ]
        if section.plans.count > 1 {
            items.append(PaperMenuItem(title: "调整计划顺序", systemImage: "arrow.up.arrow.down") {
                planOrderTarget = PlanOrderTarget(id: section.id, title: section.title, groupId: section.groupId)
            })
        }
        if let group = section.group {
            items.append(PaperMenuItem(title: "重命名分组", systemImage: "pencil") {
                groupEditor = .rename(group)
            })
            items.append(PaperMenuItem(title: "删除分组", systemImage: "trash", role: .destructive) {
                deletingGroup = group
            })
        }
        return items
    }

    private func isSectionCollapsed(_ section: PlanGroupSection) -> Bool {
        expandedSectionId != section.id
    }

    private func pruneExpandedSection() {
        guard let expandedSectionId, !sectionIds.contains(expandedSectionId) else { return }
        self.expandedSectionId = nil
    }

    private func toggleSection(_ section: PlanGroupSection) {
        withAnimation(sectionToggleAnimation) {
            expandedSectionId = expandedSectionId == section.id ? nil : section.id
        }
        Theme.Haptics.selection()
    }

    private func planCardPosition(index: Int, count: Int) -> PlanListCardPosition {
        if count <= 1 { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }

    private func planCard(_ plan: WorkoutPlan, position: PlanListCardPosition = .single) -> some View {
        let usage = usage(for: plan)
        return HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.name)
                    .font(Theme.Font.body(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.86)
                    .layoutPriority(1)
                HStack(spacing: 6) {
                    planMetricPill("\(plan.items.count) 个动作")
                    planMetricPill("\(plan.totalSuggestedSets) 组")
                }

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: usage.completedCount == 0 ? "circle" : "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Color.muted)
                        .frame(width: 14)
                    Text(usageSummary(for: plan))
                        .font(Theme.Font.mono(size: 10.5))
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 28)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .planListAttachedCardStyle(
            position: position,
            padding: EdgeInsets(top: 12,
                                leading: Theme.Spacing.md,
                                bottom: 12,
                                trailing: Theme.Spacing.sm)
        )
        .accessibilityElement(children: .combine)
    }

    private func planMetricPill(_ title: String) -> some View {
        Text(title)
            .font(Theme.Font.mono(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.Color.fg2)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Color.surface2, in: Capsule())
    }

    private func emptyGroupCard() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("这个分组还没有计划")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("可以从分组菜单直接新建计划")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .planListAttachedCardStyle()
    }

    private var emptyMineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有计划")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("点右上 + 新建训练模板或分组")
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

    private func resolvedGroupId(for plan: WorkoutPlan) -> UUID? {
        guard let groupId = plan.groupId, validGroupIds.contains(groupId) else { return nil }
        return groupId
    }

    private func plans(in groupId: UUID?) -> [WorkoutPlan] {
        orderedPlans.filter { resolvedGroupId(for: $0) == groupId }
    }

    private func planOrderItems(for groupId: UUID?) -> [ExerciseOrderItem] {
        plans(in: groupId).map {
            ExerciseOrderItem(id: $0.localId,
                              title: $0.name,
                              subtitle: "\($0.items.count) 动作 · \($0.totalSuggestedSets) 组")
        }
    }

    private func nextGroupSortOrder() -> Int {
        (groups.map(\.sortOrder).max() ?? -1) + 1
    }

    private func createGroup(name: String, sortOrder: Int) {
        let group = WorkoutPlanGroup(name: name, sortOrder: sortOrder)
        modelContext.insert(group)
        try? modelContext.save()
    }

    private func renameGroup(_ group: WorkoutPlanGroup, name: String) {
        group.name = name
        group.markDirty()
        try? modelContext.save()
    }

    private func deleteGroup(_ group: WorkoutPlanGroup) {
        let name = group.name
        for plan in plans where plan.groupId == group.localId {
            plan.groupId = nil
            plan.markDirty()
        }
        group.markDeleted()
        try? modelContext.save()
        Theme.Haptics.notification(.warning)
        globalMessage.show("已删除「\(name)」", style: .success)
    }

    private func applyGroupOrder(_ orderedIds: [UUID]) {
        var byId = Dictionary(uniqueKeysWithValues: groups.map { ($0.localId, $0) })
        let ordered = orderedIds.compactMap { byId.removeValue(forKey: $0) }
        guard ordered.map(\.localId) != orderedGroups.map(\.localId) else { return }
        for (index, group) in ordered.enumerated() {
            group.sortOrder = index
            group.markDirty()
        }
        try? modelContext.save()
        Theme.Haptics.selection()
    }

    private func applyPlanOrder(_ orderedIds: [UUID], groupId: UUID?) {
        var byId = Dictionary(uniqueKeysWithValues: plans(in: groupId).map { ($0.localId, $0) })
        let ordered = orderedIds.compactMap { byId.removeValue(forKey: $0) }
        guard ordered.map(\.localId) != plans(in: groupId).map(\.localId) else { return }
        for (index, plan) in ordered.enumerated() {
            plan.sortOrder = index
            plan.markDirty()
        }
        try? modelContext.save()
        Theme.Haptics.selection()
    }
}

// MARK: - 计划详情（Screen 06，Neon 改版）

struct PlanDetailView: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(TeamService.self) private var teamService
    @Environment(RestTimerController.self) private var restTimer
    @Environment(GlobalMessageCenter.self) private var globalMessage
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(WorkoutPresentationCenter.self) private var workoutPresentation
    @Query(filter: #Predicate<WorkoutPlanGroup> { $0.deletedAt == nil },
           sort: \WorkoutPlanGroup.sortOrder)
    private var planGroups: [WorkoutPlanGroup]

    @State private var pickingExercise = false
    @State private var editingItem: PlanItem?
    @State private var editing = false
    @State private var movingGroup = false
    @State private var sharingToTeam = false
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
    /// 单一活跃会话守卫：冲突态 + 待新建闭包。
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    /// 仅驱动冲突弹窗显隐，与数据分离——避免弹窗淡出关闭时清空 `conflict` 致动作回调读到 nil。
    @State private var showConflict = false
    /// 严格模式缺失必填预设时，阻止开始训练并展示原因。
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
                        // 与首页「本周训练」一致：每行独立卡片（带间距/描边/阴影）+ 统一左滑交互。
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
            CircleIconMenu(systemName: "ellipsis",
                           items: detailMenuItems,
                           accessibilityLabel: "计划更多操作")
        }
        .paperConfirmDialog(
            isPresented: $confirmingDelete,
            title: "删除计划?",
            message: "将删除「\(plan.name)」,此操作不可撤销。",
            confirmTitle: "删除计划",
            onConfirm: { delete() }
        )
        // 删除动作二次确认：复用首页「本周训练」的透明浮层 + 锚定卡片，文案改「删除动作」。
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
                                      exerciseName: pick.name,
                                      primaryMuscle: pick.primaryMuscle,
                                      equipmentType: pick.equipmentType,
                                      orderIndex: items.count,
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
        .sheet(isPresented: $movingGroup) {
            PlanMoveGroupSheet(plan: plan, groups: sortedPlanGroups(planGroups))
        }
        .sheet(isPresented: $sharingToTeam) {
            PlanShareToTeamSheet(plan: plan) { team, result in
                globalMessage.show(result.message(for: team), style: .success)
            }
        }
        .sheet(isPresented: $showingMode) {
            PlanModeSheet(plan: plan)
        }
        .sheet(isPresented: $showingOrderEditor) {
            ExerciseOrderEditorSheet(title: "调整动作顺序",
                                     items: planOrderItems,
                                     onCommit: applyPlanItemOrder)
        }
        // 训练冲突二次确认：统一为纸感弹窗。无独立取消按钮，点蒙层即取消；
        // 「丢弃并开始新训练」为主（红填充）、「继续训练」为次（描边）。
        .paperConfirmDialog(
            isPresented: $showConflict,
            title: "已有进行中的训练",
            message: "同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。",
            confirmTitle: "丢弃并开始新训练",
            secondaryTitle: "继续训练",
            onSecondary: {
                if let existing = conflict { workoutPresentation.present(existing) }
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
        VStack(alignment: .leading, spacing: 0) {
            Text(plan.name)
                .font(Theme.Font.display(size: 30, weight: .heavy))
                .tracking(-0.9)
                .foregroundStyle(Theme.Color.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detailMenuItems: [PaperMenuItem] {
        [
            PaperMenuItem(title: "重命名计划", systemImage: "pencil") { editing = true },
            PaperMenuItem(title: "移动到分组", systemImage: "folder") { movingGroup = true },
            PaperMenuItem(title: "分享到 Team", systemImage: "square.and.arrow.up") { sharingToTeam = true },
            PaperMenuItem(title: "删除计划", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        ]
    }

    // 仅保留动作数与总组数；计划模式在下方规则卡展示，避免重复。
    private var statRow: some View {
        HStack(spacing: 0) {
            statCell(n: "\(plan.items.count)", k: "动作")
            statDivider
            statCell(n: "\(totalSets)", k: "总组数")
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

    // 动作行（独立卡片，与训练首页「本周训练」统一观感与左滑交互）。
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
                Text(item.displayExerciseName)
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
        .accessibilityLabel("编辑\(item.displayExerciseName)")
    }

    private var modeInfoCard: some View {
        Button { showingMode = true } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: plan.mode == .adaptive ? "arrow.triangle.2.circlepath" : "lock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.mode.title)
                        .font(Theme.Font.body(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(plan.mode == .adaptive
                         ? "自适应模式会按下方处方预填；完成后继续跟随实绩更新，跳过动作会保留。"
                         : "严格模式会复制计划预设；完成后不回写，每个动作需有组数与次数。")
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
            Text("计划错误").eyebrowStyle().foregroundStyle(Theme.Color.danger)
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
                                            primaryMuscle: $0.primaryMuscle,
                                            equipmentType: $0.equipmentType,
                                            orderIndex: $0.orderIndex,
                                            suggestedSets: $0.suggestedSets,
                                            suggestedReps: $0.suggestedReps,
                                            suggestedWeightKg: nil)
                               },
                               mode: .adaptive,
                               forkedFrom: plan.localId,
                               groupId: plan.groupId,
                               sortOrder: plan.sortOrder + 1)
        modelContext.insert(copy)
        try? modelContext.save()
    }

    /// 单一活跃会话守卫：存在进行中会话时弹「继续 / 丢弃」，否则新建并进入。
    private func startWorkout() {
        let brokenItems = PlanItem.unstartableItems(in: plan.items)
        guard brokenItems.isEmpty else {
            strictStartError = PlanItem.unstartableMessage(for: brokenItems)
            return
        }
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
                exerciseName: item.displayExerciseName,
                primaryMuscle: item.resolvedPrimaryMuscle,
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
        NotificationCenter.default.post(name: .dontliftActiveWorkoutChanged, object: nil)
        workoutPresentation.present(w)
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

private enum PlanShareToTeamResult {
    case shared
    case updated
    case cancelled

    func message(for team: TeamDTO) -> String {
        switch self {
        case .shared: return "已分享到 \(team.name)"
        case .updated: return "已更新 \(team.name)"
        case .cancelled: return "已取消分享"
        }
    }
}

private enum PlanShareToTeamAction {
    case share(TeamDTO)
    case update(TeamDTO)
    case cancel(TeamDTO, TeamPlanShareCardDTO)

    var team: TeamDTO {
        switch self {
        case .share(let team), .update(let team), .cancel(let team, _):
            return team
        }
    }

    var title: String {
        switch self {
        case .share: return "分享计划?"
        case .update: return "更新分享?"
        case .cancel: return "取消分享?"
        }
    }

    func message(planName: String) -> String {
        switch self {
        case .share(let team):
            return "将「\(planName)」分享给「\(team.name)」。队友可复制或直接开始训练，训练重量不会公开。"
        case .update(let team):
            return "将用当前计划内容更新「\(team.name)」中的分享版本；已复制或已开始的训练不受影响。"
        case .cancel(let team, _):
            return "取消后，「\(team.name)」成员将不再从列表看到「\(planName)」；已复制的计划不受影响。"
        }
    }

    var confirmTitle: String {
        switch self {
        case .share: return "分享"
        case .update: return "更新"
        case .cancel: return "取消分享"
        }
    }

    var isDestructive: Bool {
        if case .cancel = self { return true }
        return false
    }
}

private struct PlanShareToTeamSheet: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let plan: WorkoutPlan
    let onChanged: (TeamDTO, PlanShareToTeamResult) -> Void

    @State private var loading = false
    @State private var workingTeamId: UUID?
    @State private var existingShares: [UUID: TeamPlanShareCardDTO] = [:]
    @State private var pendingAction: PlanShareToTeamAction?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "分享到 Team",
                cancelTitle: "取消",
                showsHandle: true,
                background: Theme.Color.bg,
                onCancel: { dismiss() }
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    summary
                    if loading && teamService.teams.isEmpty {
                        ProgressView()
                            .tint(Theme.Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.lg)
                    } else if teamService.teams.isEmpty {
                        Text("还没有 Team")
                            .font(Theme.Font.body(size: 13))
                            .foregroundStyle(Theme.Color.muted)
                            .padding(.top, Theme.Spacing.lg)
                    } else {
                        ForEach(teamService.teams) { team in
                            teamRow(team)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .background(Theme.Color.bg)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task { await loadTeams() }
        .alert("操作失败", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
        .paperConfirmDialog(
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            title: pendingAction?.title ?? "",
            message: pendingAction?.message(planName: plan.name) ?? "",
            confirmTitle: pendingAction?.confirmTitle ?? "",
            destructive: pendingAction?.isDestructive ?? false,
            onConfirm: {
                if let action = pendingAction {
                    Task { await perform(action) }
                }
                pendingAction = nil
            }
        )
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.name)
                .font(Theme.Font.body(size: 16, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            Text("\(plan.items.count) 个动作 · 不包含重量 · 可更新")
                .font(Theme.Font.mono(size: 11))
                .foregroundStyle(Theme.Color.muted)
            Text("队友可复制或直接开始训练；已分享的 Team 可取消分享。")
                .font(Theme.Font.body(size: 12))
                .foregroundStyle(Theme.Color.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func teamRow(_ team: TeamDTO) -> some View {
        let existing = existingShares[team.id]
        let busy = workingTeamId == team.id
        return HStack(spacing: 12) {
            Text(String(team.name.prefix(1)))
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 36, height: 36)
                .background(Theme.Color.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text(existing == nil ? "未分享 · 邀请码 \(team.inviteCode)" : "已分享 · 可更新")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer(minLength: 8)
            if busy {
                ProgressView().tint(Theme.Color.accent)
            } else if let existing {
                HStack(spacing: 8) {
                    rowActionButton("更新") {
                        pendingAction = .update(team)
                    }
                    rowActionButton("取消", destructive: true) {
                        pendingAction = .cancel(team, existing)
                    }
                }
            } else {
                rowActionButton("分享") {
                    pendingAction = .share(team)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func rowActionButton(_ title: String,
                                 destructive: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(destructive ? Theme.Color.danger : Theme.Color.accent)
                .frame(minWidth: 44)
                .frame(height: 34)
                .padding(.horizontal, 8)
                .background((destructive ? Theme.Color.danger.opacity(0.08) : Theme.Color.accentSoft),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(destructive ? Theme.Color.danger.opacity(0.22) : Theme.Color.accentSofter, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(workingTeamId != nil)
    }

    private func loadTeams() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            try await teamService.loadMyTeams()
            try await reloadExistingShares()
        }
        catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func reloadExistingShares() async throws {
        var result: [UUID: TeamPlanShareCardDTO] = [:]
        for team in teamService.teams {
            let shares = try await teamService.planShares(of: team.id)
            if let share = shares.first(where: isCurrentPlanShare) {
                result[team.id] = share
            }
        }
        existingShares = result
    }

    private func isCurrentPlanShare(_ share: TeamPlanShareCardDTO) -> Bool {
        guard share.sourcePlanId == plan.localId else { return false }
        guard let currentUserId = session.currentUserId else { return true }
        return share.ownerUserId == currentUserId
    }

    private func perform(_ action: PlanShareToTeamAction) async {
        let team = action.team
        workingTeamId = team.id
        defer { workingTeamId = nil }
        do {
            switch action {
            case .share, .update:
                try await share(to: team)
            case .cancel(_, let share):
                try await teamService.deletePlanShare(share.shareId, in: team.id)
                existingShares.removeValue(forKey: team.id)
                onChanged(team, .cancelled)
            }
            Task { await syncEngine.syncAll() }
        } catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func share(to team: TeamDTO) async throws {
        let wasShared = existingShares[team.id] != nil
        do {
            let token = UUID().uuidString
            try await teamService.share(plan: plan, to: team.id, idempotencyToken: token)
            try await reloadExistingShares()
            onChanged(team, wasShared ? .updated : .shared)
        } catch {
            throw error
        }
    }
}

// MARK: - 计划编辑器（仅用于新建空模板入口；详情页内联编辑动作项）

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<WorkoutPlanGroup> { $0.deletedAt == nil },
           sort: \WorkoutPlanGroup.sortOrder)
    private var groups: [WorkoutPlanGroup]

    private let existing: WorkoutPlan?
    @State private var name: String
    @State private var mode: WorkoutPlanMode
    @State private var groupId: UUID?
    @State private var choosingGroup = false

    init(plan: WorkoutPlan?, initialGroupId: UUID? = nil) {
        self.existing = plan
        _name = State(initialValue: plan?.name ?? "")
        _mode = State(initialValue: plan?.mode ?? .adaptive)
        _groupId = State(initialValue: plan?.groupId ?? initialGroupId)
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("新建计划").eyebrowStyle()
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
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("分组").eyebrowStyle()
                    groupPicker
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
        .sheet(isPresented: $choosingGroup) {
            PlanGroupPickerSheet(selectedGroupId: groupId, groups: orderedGroups) { selected in
                groupId = selected
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmed
            existing.mode = mode
            existing.groupId = groupId
            existing.markDirty()
        } else {
            let plan = WorkoutPlan(name: trimmed,
                                   mode: mode,
                                   groupId: groupId,
                                   sortOrder: nextSortOrder(in: groupId))
            modelContext.insert(plan)
        }
        try? modelContext.save()
        dismiss()
    }

    private var orderedGroups: [WorkoutPlanGroup] { sortedPlanGroups(groups) }

    private var selectedGroupName: String {
        guard let groupId, let group = groups.first(where: { $0.localId == groupId }) else { return "未分组" }
        return group.name
    }

    private var groupPicker: some View {
        Button {
            choosingGroup = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "folder")
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 22)
                Text(selectedGroupName)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.muted)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择分组")
    }

    private func nextSortOrder(in groupId: UUID?) -> Int {
        let descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let sameGroup = (try? modelContext.fetch(descriptor))?.filter { $0.groupId == groupId } ?? []
        return (sameGroup.map(\.sortOrder).max() ?? -1) + 1
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
                Text("重命名").eyebrowStyle()
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

/// 新建 / 重命名计划分组。
struct PlanGroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (String) -> Void
    @State private var name: String

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: title,
                cancelTitle: "取消",
                confirmTitle: "完成",
                confirmEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("分组").eyebrowStyle()
                TextField("", text: $name, prompt: Text("分组名称").foregroundColor(Theme.Color.muted))
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
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}

/// 新建计划时选择分组：不用系统 Menu/Picker，保持纸感 sheet 与卡片行规范。
struct PlanGroupPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedGroupId: UUID?
    let groups: [WorkoutPlanGroup]
    let onSelect: (UUID?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "选择分组",
                cancelTitle: "取消",
                background: Theme.Color.bg,
                onCancel: { dismiss() }
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                groupOption(title: "未分组", groupId: nil)
                ForEach(groups) { group in
                    groupOption(title: group.name, groupId: group.localId)
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
    }

    private func groupOption(title: String, groupId: UUID?) -> some View {
        let selected = selectedGroupId == groupId
        return Button {
            onSelect(groupId)
            Theme.Haptics.selection()
            dismiss()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.muted)
                    .frame(width: 24)
                Image(systemName: groupId == nil ? "tray" : "folder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 22)
                Text(title)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

/// 计划移动分组。
struct PlanMoveGroupSheet: View {
    @Bindable var plan: WorkoutPlan
    let groups: [WorkoutPlanGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "移动到分组",
                cancelTitle: "取消",
                background: Theme.Color.bg,
                onCancel: { dismiss() }
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                groupOption(title: "未分组", groupId: nil)
                ForEach(groups) { group in
                    groupOption(title: group.name, groupId: group.localId)
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
    }

    private func groupOption(title: String, groupId: UUID?) -> some View {
        let selected = plan.groupId == groupId
        return Button {
            plan.groupId = groupId
            plan.markDirty()
            try? modelContext.save()
            dismiss()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.muted)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
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
                Text(original.displayExerciseName)
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
        "将「\(plan.name)」从\(plan.mode.title)切换为\(draftMode.title)。切换后开始训练与完成回写规则会按新模式执行。"
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
