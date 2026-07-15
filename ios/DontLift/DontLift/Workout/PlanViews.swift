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

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        planOverview

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
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            floatingAddMenu
        }
        .rootTabTopScrim()
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

    private var floatingAddMenu: some View {
        CircleAddMenu(items: headerMenuItems, accessibilityLabel: "添加计划或分组")
            .frame(width: 48, height: 48)
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
    }

    private var planOverview: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("总览")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .tracking(0.08 * 12)
                .foregroundStyle(Theme.Color.muted)
            Text(planListOverview)
                .font(Theme.Font.mono(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("计划总览，\(planListOverview)")
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
                    if !section.plans.isEmpty {
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
                        if let subtitle = sectionSubtitle(section, collapsed: collapsed) {
                            Text(subtitle)
                                .font(Theme.Font.mono(size: 11))
                                .foregroundStyle(Theme.Color.muted)
                                .lineLimit(1)
                        }
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

    private func sectionSubtitle(_ section: PlanGroupSection, collapsed: Bool) -> String? {
        guard !section.plans.isEmpty else { return nil }
        if collapsed {
            let names = section.plans.prefix(2).map(\.name).joined(separator: " / ")
            return section.plans.count > 2 ? "\(names) 等 \(section.plans.count) 个计划" : names
        }
        return "\(section.plans.count) 个计划"
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
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(plan.name)
                        .font(Theme.Font.body(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.86)

                    Spacer(minLength: Theme.Spacing.xs)

                    planUsageInlineLabel(usage)
                }
                HStack(spacing: 6) {
                    planMetricPill("\(plan.totalExerciseCount) 个动作")
                    planMetricPill("\(plan.totalSuggestedSets) 组")
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
            padding: EdgeInsets(top: 10,
                                leading: Theme.Spacing.md,
                                bottom: 10,
                                trailing: Theme.Spacing.sm)
        )
        .accessibilityElement(children: .combine)
    }

    private func planUsageInlineLabel(_ usage: PlanUsageSummary) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: usage.completedCount == 0 ? "circle" : "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 14)
            Text("累计训练 \(usage.completedCount) 次")
                .font(Theme.Font.mono(size: 10.5))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.Color.muted)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
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

    private var emptyMineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有计划")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("点右下 + 新建训练模板或分组")
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
    @State private var creatingSuperset = false
    @State private var pendingPlanUnitKind: PlanUnitKind = .singleExercise
    @State private var editingItem: PlanItem?
    @State private var editingSupersetItem: PlanItem?
    @State private var editing = false
    @State private var movingGroup = false
    @State private var sharingToTeam = false
    @State private var showingMode = false
    @State private var confirmingDelete = false
    @State private var decodeError: String?
    @State private var pendingEditAfterPick: PlanItem?
    /// 待删除动作行；由原生 swipe action 触发，再走统一纸感二次确认。
    @State private var pendingDeleteItem: PlanItem?
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
            ExerciseOrderItem(id: $0.itemId,
                              title: planItemTitle($0),
                              subtitle: subtitle($0),
                              structureKind: structureKind(for: $0))
        }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            List {
                // 标题区作为单个原生 List 行，内部继续沿用原有 11pt 纸感版式。
                VStack(alignment: .leading, spacing: 11) {
                    header
                    statRow
                    modeInfoCard
                    sectionLabel

                    if let err = decodeError {
                        decodeErrorCard(err)
                    } else if orderedItems.isEmpty {
                        emptyExercisesCard
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 17, bottom: 5.5, trailing: 17))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if decodeError == nil, !orderedItems.isEmpty {
                    ForEach(orderedItems, id: \.itemId) { item in
                        planItemRow(item)
                            .contentShape(Rectangle())
                            .onTapGesture { editPlanItem(item) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteItem = item
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                .tint(Theme.Color.danger)
                            }
                            .accessibilityAction(named: "删除") {
                                pendingDeleteItem = item
                            }
                            .listRowInsets(EdgeInsets(top: 5.5, leading: 17, bottom: 5.5, trailing: 17))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                addExerciseCTA
                    .listRowInsets(EdgeInsets(top: 5.5, leading: 17, bottom: 12, trailing: 17))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 1)
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
        .paperConfirmDialog(
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            title: "删除动作?",
            message: pendingDeleteItem.map {
                "将从计划中删除「\(planItemTitle($0))」，此操作不可撤销。"
            } ?? "",
            confirmTitle: "删除动作",
            onConfirm: {
                guard let item = pendingDeleteItem else { return }
                Theme.Haptics.notification(.warning)
                deleteItem(item)
            }
        )
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerView { pick in
                var items = plan.items
                let newItem = planItem(from: pick, kind: pendingPlanUnitKind, orderIndex: items.count)
                items.append(newItem)
                plan.items = items
                plan.markDirty()
                try? modelContext.save()
                pendingEditAfterPick = newItem
            }
        }
        .onChange(of: pickingExercise) { _, isPresented in
            guard !isPresented, let item = pendingEditAfterPick else { return }
            pendingEditAfterPick = nil
            pendingPlanUnitKind = .singleExercise
            editingItem = item
        }
        .sheet(isPresented: $creatingSuperset) {
            SupersetCreationSheet { result in
                addPlanSuperset(result)
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
        .sheet(item: $editingSupersetItem) { item in
            SupersetCreationSheet(title: "编辑超级组",
                                  initial: supersetInitialResult(from: item)) { result in
                updatePlanSuperset(itemId: item.itemId, result: result)
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
            statCell(n: "\(plan.totalExerciseCount)", k: "动作")
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

    // 动作行保持独立纸感卡片；外层原生 List 统一处理滚动与左滑删除。
    private func planItemRow(_ item: PlanItem) -> some View {
        // 序号按当前顺序推出（动作数极少，firstIndex 开销可忽略）。
        let index = (orderedItems.firstIndex { $0.itemId == item.itemId } ?? 0) + 1
        let summary = planItemSummary(item)
        return HStack(spacing: 11) {
            Text(String(format: "%02d", index))
                .font(Theme.Font.mono(size: 12, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 18)
            planItemKindIcon(item)
            VStack(alignment: .leading, spacing: 3) {
                Text(planItemTitle(item))
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(summary.main)
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let warmup = summary.warmup {
                    Text(warmup)
                        .font(Theme.Font.body(size: 11.5))
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if !item.usableAlternatives.isEmpty {
                    Text("备选：\(item.usableAlternatives.map(\.displayExerciseName).joined(separator: "、"))")
                        .font(Theme.Font.body(size: 11.5))
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            editItemButton(item)
        }
        .cardStyle(padding: 12)
    }

    private func planItemTitle(_ item: PlanItem) -> String {
        if item.isSuperset { return item.supersetTitle }
        return item.displayExerciseName
    }

    private func structureKind(for item: PlanItem) -> WorkoutStructureIconKind? {
        if item.isDropSet { return .dropSet }
        if item.isSuperset { return .superset }
        return nil
    }

    @ViewBuilder
    private func planItemKindIcon(_ item: PlanItem) -> some View {
        if let kind = structureKind(for: item) {
            WorkoutStructureIcon(kind: kind)
        }
    }

    private func supersetPrescriptionSummary(_ item: PlanItem) -> String {
        let memberText = item.orderedSupersetMembers.map { member in
            switch (member.suggestedWeightKg, member.suggestedReps) {
            case let (.some(weight), .some(reps)):
                return "\(formatKg(weight)) kg × \(reps)"
            case let (.some(weight), .none):
                return "\(formatKg(weight)) kg"
            case let (.none, .some(reps)):
                return "\(reps) 次"
            case (.none, .none):
                return "未设"
            }
        }.joined(separator: " / ")
        return "\(memberText) × \(item.supersetRounds)组"
    }

    private func planItemSummary(_ item: PlanItem) -> (main: String, warmup: String?) {
        if item.isSuperset {
            return (supersetPrescriptionSummary(item), nil)
        }
        let preview = PlanPrescriptionPreview.make(for: item,
                                                   mode: plan.mode,
                                                   lookup: historyStore.planLookup,
                                                   planId: plan.localId)
        return (preview.summaryText, preview.warmupSummaryText)
    }

    private func editPlanItem(_ item: PlanItem) {
        if item.isSuperset {
            editingSupersetItem = item
        } else {
            editingItem = item
        }
    }

    private func editItemButton(_ item: PlanItem) -> some View {
        Button {
            editPlanItem(item)
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑\(item.unitDisplayName)")
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
                         : "严格模式会复制当前处方；完成后不回写，每个动作需有组数与次数。")
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

    private var addExerciseCTA: some View {
        HStack(spacing: 10) {
            structureMenuButton
            addPlanUnitButton(title: "添加动作", systemImage: "plus", compact: false) {
                pendingPlanUnitKind = .singleExercise
                pickingExercise = true
            }
        }
    }

    private var structureMenuButton: some View {
        WorkoutStructureMenuButton(
            onAddDropSet: {
                pendingPlanUnitKind = .dropSet
                pickingExercise = true
            },
            onAddSuperset: {
                creatingSuperset = true
            }
        )
    }

    private func addPlanUnitButton(title: String,
                                   systemImage: String,
                                   compact: Bool,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(Theme.Font.body(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(compact ? Theme.Color.muted : Theme.Color.accent)
            .padding(.horizontal, compact ? 12 : 22)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(height: compact ? 36 : 40)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(compact ? Theme.Color.border : Theme.Color.accentSofter,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
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
        if item.isSuperset { return supersetPrescriptionSummary(item) }
        // 对齐原型 .pm：「3 组 × 10 · 60 kg」/「3 组 × 12」；重量可空时仅显示组×次。
        var parts: [String] = []
        if let r = item.suggestedReps { parts.append("\(item.formalSetCount) 组 × \(r)") }
        else if item.formalSetCount > 0 { parts.append("\(item.formalSetCount) 组") }
        if let w = item.suggestedWeightKg { parts.append("\(formatKg(w)) kg") }
        if let warmup = item.warmupSummaryText { parts.append(warmup) }
        return parts.isEmpty ? "未设建议" : parts.joined(separator: " · ")
    }

    private func planItem(from pick: ExercisePick, kind: PlanUnitKind, orderIndex: Int) -> PlanItem {
        switch kind {
        case .dropSet:
            return PlanItem.dropSet(orderIndex: orderIndex,
                                    builtinExerciseCode: pick.builtinCode,
                                    customExerciseId: pick.customId,
                                    exerciseName: pick.name,
                                    primaryMuscle: pick.primaryMuscle,
                                    equipmentType: pick.equipmentType,
                                    segments: [
                                        WorkoutSetSegment(segmentIndex: 0, reps: PlanDefaults.suggestedReps),
                                        WorkoutSetSegment(segmentIndex: 1)
                                    ])
        case .singleExercise, .superset:
            return PlanItem(builtinExerciseCode: pick.builtinCode,
                            customExerciseId: pick.customId,
                            exerciseName: pick.name,
                            primaryMuscle: pick.primaryMuscle,
                            equipmentType: pick.equipmentType,
                            orderIndex: orderIndex,
                            suggestedSets: PlanDefaults.suggestedSets,
                            suggestedReps: PlanDefaults.suggestedReps)
        }
    }

    private func duplicate() {
        // Fork 规则（design.md D8）：复制 动作 + 组数 + 次数，清空重量（重量最私人）；副本默认自适应。
        let copy = WorkoutPlan(name: plan.name + " · 副本",
                               items: plan.items.map(weightlessCopyForDuplicate(_:)),
                               mode: .adaptive,
                               forkedFrom: plan.localId,
                               groupId: nil,
                               sortOrder: nextSortOrder(in: nil))
        modelContext.insert(copy)
        try? modelContext.save()
    }

    private func nextSortOrder(in groupId: UUID?) -> Int {
        let descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let sameGroup = (try? modelContext.fetch(descriptor))?.filter { $0.groupId == groupId } ?? []
        return (sameGroup.map(\.sortOrder).max() ?? -1) + 1
    }

    private func weightlessCopyForDuplicate(_ item: PlanItem) -> PlanItem {
        if item.isSuperset {
            return PlanItem.superset(
                itemId: UUID(),
                orderIndex: item.orderIndex,
                roundCount: item.supersetRounds,
                restAfterRoundSeconds: item.supersetRestAfterRoundSeconds,
                members: item.orderedSupersetMembers.map {
                    PlanSupersetMember(memberId: UUID(),
                                       builtinExerciseCode: $0.builtinExerciseCode,
                                       customExerciseId: $0.customExerciseId,
                                       exerciseName: $0.exerciseName,
                                       primaryMuscle: $0.primaryMuscle,
                                       equipmentType: $0.equipmentType,
                                       orderIndex: $0.orderIndex,
                                       suggestedWeightKg: nil,
                                       suggestedReps: $0.suggestedReps)
                }
            )
        }
        if item.isDropSet {
            let prescriptions = item.dropSetPrescriptions.enumerated().map { idx, prescription in
                PlanSetPrescription(setType: .drop,
                                    orderIndex: idx,
                                    weightKg: nil,
                                    reps: prescription.reps,
                                    isWarmup: false,
                                    segments: prescription.segments
                                        .sorted { $0.segmentIndex < $1.segmentIndex }
                                        .enumerated()
                                        .map { segmentIndex, segment in
                                            WorkoutSetSegment(segmentIndex: segmentIndex,
                                                              weightKg: nil,
                                                              reps: segment.reps)
                                        })
            }
            return PlanItem(itemId: UUID(),
                            unitKind: .dropSet,
                            builtinExerciseCode: item.builtinExerciseCode,
                            customExerciseId: item.customExerciseId,
                            exerciseName: item.displayExerciseName,
                            primaryMuscle: item.primaryMuscle,
                            equipmentType: item.equipmentType,
                            orderIndex: item.orderIndex,
                            suggestedSets: max(1, item.suggestedSets ?? prescriptions.count),
                            suggestedReps: item.suggestedReps,
                            suggestedWeightKg: nil,
                            setPrescriptions: prescriptions.isEmpty ? nil : prescriptions)
        }
        return PlanItem(itemId: UUID(),
                        builtinExerciseCode: item.builtinExerciseCode,
                        customExerciseId: item.customExerciseId,
                        exerciseName: item.exerciseName,
                        primaryMuscle: item.primaryMuscle,
                        equipmentType: item.equipmentType,
                        orderIndex: item.orderIndex,
                        suggestedSets: item.suggestedSets,
                        suggestedReps: item.suggestedReps,
                        suggestedWeightKg: nil,
                        setPrescriptions: PlanItem.reindexRegularPrescriptions(item.regularSetPrescriptions).map {
                            PlanSetPrescription(prescriptionId: UUID(),
                                                setType: $0.setType,
                                                orderIndex: $0.orderIndex,
                                                weightKg: nil,
                                                reps: $0.reps,
                                                isWarmup: $0.isWarmup,
                                                segments: $0.segments.map {
                                                    WorkoutSetSegment(segmentId: UUID(),
                                                                      segmentIndex: $0.segmentIndex,
                                                                      weightKg: nil,
                                                                      reps: $0.reps)
                                                })
                        },
                        alternatives: item.alternatives)
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
        PlanWorkoutBuilder.workout(from: plan, lookup: historyStore.planLookup)
    }

    private func commit(_ build: () -> Workout) {
        let w = build()
        modelContext.insert(w)
        try? modelContext.save()
        historyStore.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)
        NotificationCenter.default.post(name: .dontliftActiveWorkoutChanged, object: nil)
        workoutPresentation.present(w)
    }

    private func addPlanSuperset(_ result: SupersetCreationResult) {
        var items = plan.items
        items.append(planSupersetItem(from: result, itemId: UUID(), orderIndex: items.count, existing: nil))
        plan.items = items
        plan.markDirty()
        try? modelContext.save()
    }

    private func updatePlanSuperset(itemId: UUID, result: SupersetCreationResult) {
        var items = plan.items
        guard let idx = items.firstIndex(where: { $0.itemId == itemId }) else { return }
        items[idx] = planSupersetItem(from: result,
                                      itemId: itemId,
                                      orderIndex: items[idx].orderIndex,
                                      existing: items[idx])
        plan.items = items
        plan.markDirty()
        try? modelContext.save()
    }

    private func planSupersetItem(from result: SupersetCreationResult,
                                  itemId: UUID,
                                  orderIndex: Int,
                                  existing: PlanItem?) -> PlanItem {
        PlanItem.superset(
            itemId: itemId,
            orderIndex: orderIndex,
            roundCount: result.roundCount,
            restAfterRoundSeconds: existing?.supersetRestAfterRoundSeconds,
            members: [
                planSupersetMember(from: result.first, orderIndex: 0),
                planSupersetMember(from: result.second, orderIndex: 1)
            ]
        )
    }

    private func planSupersetMember(from member: SupersetCreationResult.Member, orderIndex: Int) -> PlanSupersetMember {
        PlanSupersetMember(memberId: member.memberId ?? UUID(),
                           builtinExerciseCode: member.pick.builtinCode,
                           customExerciseId: member.pick.customId,
                           exerciseName: member.pick.name,
                           primaryMuscle: member.pick.primaryMuscle,
                           equipmentType: member.pick.equipmentType,
                           orderIndex: orderIndex,
                           suggestedWeightKg: member.weightKg,
                           suggestedReps: member.reps)
    }

    private func supersetInitialResult(from item: PlanItem) -> SupersetCreationResult? {
        let members = item.orderedSupersetMembers
        guard members.count == 2 else { return nil }
        return SupersetCreationResult(
            roundCount: item.supersetRounds,
            first: supersetResultMember(from: members[0]),
            second: supersetResultMember(from: members[1])
        )
    }

    private func supersetResultMember(from member: PlanSupersetMember) -> SupersetCreationResult.Member {
        .init(memberId: member.memberId,
              pick: ExercisePick(builtinCode: member.builtinExerciseCode,
                                 customId: member.customExerciseId,
                                 name: member.displayExerciseName,
                                 primaryMuscle: member.resolvedPrimaryMuscle,
                                 equipmentType: member.resolvedEquipmentType),
              weightKg: member.suggestedWeightKg,
              reps: member.suggestedReps)
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
            Text("\(plan.totalExerciseCount) 个动作 · 不包含重量 · 可更新")
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
        .presentationDetents([.large])
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

private enum PlanItemEditorField: Hashable {
    case workingGroupCount
    case workingReps
    case workingWeight
    case warmupWeight(UUID)
    case warmupReps(UUID)
    case dropOuterGroupCount
    case dropChildGroupCount
    case dropSegmentWeight(UUID)
    case dropSegmentReps(UUID)

    var allowsDecimal: Bool {
        switch self {
        case .workingWeight, .warmupWeight, .dropSegmentWeight:
            return true
        case .workingGroupCount, .workingReps, .warmupReps, .dropOuterGroupCount, .dropChildGroupCount, .dropSegmentReps:
            return false
        }
    }
}

struct PlanItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prescriptions: [EditablePlanPrescription]
    @State private var warmupPrescriptions: [EditablePlanPrescription]
    @State private var isWarmupExpanded = false
    @State private var focusedField: PlanItemEditorField?
    @State private var replaceOnInput = false
    @State private var dropOuterGroupCountText: String
    @State private var alternatives: [PlanExerciseOption]
    @State private var pickingAlternative = false
    @State private var alternativeError: String?
    private let original: PlanItem
    let onSave: (PlanItem) -> Void

    @MainActor
    init(item: PlanItem, onSave: @escaping (PlanItem) -> Void) {
        self.original = item
        self.onSave = onSave
        let editable = item.manualSetPrescriptionsForEditing().map(EditablePlanPrescription.init)
        let formal = editable.filter { !$0.isWarmup }
        let warmups = editable.filter(\.isWarmup)
        _prescriptions = State(initialValue: item.isDropSet || !formal.isEmpty ? (item.isDropSet ? editable : formal) : [
            .working(weight: item.suggestedWeightKg.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? "",
                     reps: item.suggestedReps.map(String.init) ?? "\(PlanDefaults.suggestedReps)")
        ])
        _warmupPrescriptions = State(initialValue: item.isDropSet ? [] : warmups)
        _dropOuterGroupCountText = State(initialValue: "\(max(1, item.suggestedSets ?? 1))")
        _alternatives = State(initialValue: item.usableAlternatives)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: original.isDropSet ? "编辑递减组" : "编辑动作",
                cancelTitle: "取消",
                confirmTitle: "完成",
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        editorTitle
                        prescriptionEditor
                        if !original.isDropSet {
                            alternativeEditor
                        }
                        Color.clear.frame(height: focusedField == nil ? 18 : 250)
                    }
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Theme.Color.bg)
                .onChange(of: focusedField) { _, field in
                    scrollFocusedField(field, with: proxy)
                }
                .onChange(of: isWarmupExpanded) { _, _ in
                    scrollFocusedField(focusedField, with: proxy)
                }
            }
            if focusedField != nil {
                NumericFormKeypad(decimalEnabled: focusedField?.allowsDecimal == true,
                                  onDigit: keypadDigit,
                                  onDot: keypadDot,
                                  onBackspace: keypadBackspace,
                                  onPrev: focusPreviousField,
                                  onNext: focusNextField,
                                  onDone: { focusedField = nil })
            }
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.large])
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: focusedField)
        .sheet(isPresented: $pickingAlternative) {
            ExercisePickerView(onPick: addAlternative)
        }
        .alert("无法添加备选动作", isPresented: Binding(
            get: { alternativeError != nil },
            set: { if !$0 { alternativeError = nil } }
        )) {
            Button("知道了", role: .cancel) { alternativeError = nil }
        } message: {
            Text(alternativeError ?? "")
        }
    }

    private var editorTitle: some View {
        VStack(alignment: .leading, spacing: original.isDropSet ? 8 : 0) {
            Text(original.displayExerciseName)
                .font(Theme.Font.l1)
                .foregroundStyle(Theme.Color.fg)
            if original.isDropSet {
                HStack(spacing: 6) {
                    WorkoutStructureIcon(kind: .dropSet)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func save() {
        var updated = original
        if original.isDropSet {
            updated.suggestedSets = dropOuterGroupCount
            updated.applyManualSetPrescriptions(dropSetModels)
        } else {
            updated.applyManualSetPrescriptions(warmupModels + workingModels)
            updated.alternatives = alternatives.isEmpty ? nil : alternatives
        }
        onSave(updated)
        dismiss()
    }

    private var prescriptionEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if original.isDropSet {
                dropSetPrescriptionCard
            } else {
                workingPrescriptionCard
                warmupPrescriptionSection
            }
        }
    }

    private var alternativeEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("备选动作")
                    .font(Theme.Font.l2)
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text("每次只练其中一个")
                    .font(Theme.Font.l4)
                    .foregroundStyle(Theme.Color.muted)
            }

            if !alternatives.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(alternatives.enumerated()), id: \.element.id) { index, option in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.displayExerciseName)
                                    .font(Theme.Font.body(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Color.fg)
                                if let equipment = option.resolvedEquipmentType {
                                    Text(equipment)
                                        .font(Theme.Font.l4)
                                        .foregroundStyle(Theme.Color.muted)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                alternatives.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Color.danger)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("移除备选动作\(option.displayExerciseName)")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        if index < alternatives.count - 1 {
                            Rectangle().fill(Theme.Color.border).frame(height: 1)
                        }
                    }
                }
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.Color.border, lineWidth: 1)
                )
            }

            Button {
                focusedField = nil
                pickingAlternative = true
            } label: {
                Label("添加备选动作", systemImage: "arrow.triangle.branch")
                    .font(Theme.Font.body(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .stroke(Theme.Color.accentSofter, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func addAlternative(_ pick: ExercisePick) {
        let option = PlanExerciseOption(builtinExerciseCode: pick.builtinCode,
                                        customExerciseId: pick.customId,
                                        exerciseName: pick.name,
                                        primaryMuscle: pick.primaryMuscle,
                                        equipmentType: pick.equipmentType)
        let usedKeys = Set([original.historyKey] + alternatives.map(\.historyKey))
        guard !usedKeys.contains(option.historyKey) else {
            alternativeError = "该动作已经是默认动作或备选动作。"
            return
        }
        alternatives.append(option)
    }

    private var workingGroupCount: Int {
        max(1, prescriptions.count)
    }

    private var dropOuterGroupCount: Int {
        max(1, Int(dropOuterGroupCountText) ?? 1)
    }

    private var dropChildGroupCount: Int {
        max(1, prescriptions.first?.segments.count ?? 1)
    }

    private var workingModels: [PlanSetPrescription] {
        let source = prescriptions.first ?? .working(weight: "", reps: "\(PlanDefaults.suggestedReps)")
        return (0..<workingGroupCount).map { index in
            let prescription = prescriptions.indices.contains(index) ? prescriptions[index] : source
            return EditablePlanPrescription.working(id: prescriptions.indices.contains(index) ? prescriptions[index].id : UUID(),
                                             weight: prescription.weight,
                                             reps: prescription.reps,
                                             isWarmup: false)
                .model(orderIndex: index)
        }
    }

    private var warmupModels: [PlanSetPrescription] {
        warmupPrescriptions.enumerated().map { idx, prescription in
            EditablePlanPrescription.working(id: prescription.id,
                                             weight: prescription.weight,
                                             reps: prescription.reps,
                                             isWarmup: true)
                .model(orderIndex: idx)
        }
    }

    private var dropSetModels: [PlanSetPrescription] {
        var draft = prescriptions.first ?? .drop(firstWeight: "", firstReps: "\(PlanDefaults.suggestedReps)")
        draft.isWarmup = false
        return [draft.model(orderIndex: 0)]
    }

    private var workingWeightBinding: Binding<String> {
        Binding(
            get: { prescriptions.first?.weight ?? "" },
            set: { setWorkingWeight($0) }
        )
    }

    private var workingRepsBinding: Binding<String> {
        Binding(
            get: { prescriptions.first?.reps ?? "\(PlanDefaults.suggestedReps)" },
            set: { setWorkingReps($0) }
        )
    }

    private var workingPrescriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            workingGroupCountRow
            Rectangle().fill(Theme.Color.border).frame(height: 1)
            HStack(spacing: 8) {
                valueField(title: "重量（可选）", placeholder: "kg", text: workingWeightBinding.wrappedValue, focused: focusedField == .workingWeight) {
                    focus(.workingWeight)
                }
                .id(PlanItemEditorField.workingWeight)
                valueField(title: "次数", placeholder: "次", text: workingRepsBinding.wrappedValue, focused: focusedField == .workingReps) {
                    focus(.workingReps)
                }
                .id(PlanItemEditorField.workingReps)
            }
        }
        .cardStyle(padding: 12, cornerRadius: Theme.Radius.md)
    }

    private var warmupPrescriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    isWarmupExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isWarmupExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 16)
                        Text("热身组")
                            .font(Theme.Font.body(size: 13, weight: .bold))
                        Text("\(warmupPrescriptions.count) 组")
                            .font(Theme.Font.mono(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Color.muted)
                    }
                    .foregroundStyle(Theme.Color.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    addWarmupPrescription()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                        .frame(width: 30, height: 30)
                        .background(Theme.Color.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加热身组")
            }

            if isWarmupExpanded {
                if warmupPrescriptions.isEmpty {
                    Text("未添加热身组")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                } else {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                    ForEach(Array(warmupPrescriptions.enumerated()), id: \.element.id) { index, prescription in
                        warmupPrescriptionRow(prescription, index: index)
                    }
                }
            }
        }
        .cardStyle(padding: 12, cornerRadius: Theme.Radius.md)
    }

    private var workingGroupCountRow: some View {
        HStack(spacing: 12) {
            Text("组数")
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .frame(width: 44, alignment: .leading)
            valuePill(text: "\(workingGroupCount)",
                      placeholder: "组",
                      focused: focusedField == .workingGroupCount,
                      width: nil) {
                focus(.workingGroupCount)
            }
            .id(PlanItemEditorField.workingGroupCount)
        }
    }

    private func warmupPrescriptionRow(_ prescription: EditablePlanPrescription, index: Int) -> some View {
        let controlTopOffset: CGFloat = 16
        return HStack(spacing: 8) {
            Text("热\(index + 1)")
                .font(Theme.Font.mono(size: 11, weight: .bold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 28, height: 30, alignment: .leading)
                .padding(.top, controlTopOffset)
            valueField(title: "重量（可选）",
                       placeholder: "kg",
                       text: prescription.weight,
                       focused: focusedField == .warmupWeight(prescription.id)) {
                focus(.warmupWeight(prescription.id))
            }
            .id(PlanItemEditorField.warmupWeight(prescription.id))
            Text("×")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .padding(.top, controlTopOffset)
            valueField(title: "次数",
                       placeholder: "次",
                       text: prescription.reps,
                       focused: focusedField == .warmupReps(prescription.id)) {
                focus(.warmupReps(prescription.id))
            }
            .id(PlanItemEditorField.warmupReps(prescription.id))
            Button {
                removeWarmupPrescription(prescription.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.danger)
                    .frame(width: 28, height: 30)
            }
            .padding(.top, controlTopOffset)
            .buttonStyle(.plain)
            .accessibilityLabel("删除热身组")
        }
    }

    private var dropSetPrescriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            dropOuterGroupCountRow
            Rectangle().fill(Theme.Color.border).frame(height: 1)
            ForEach(Array(dropSegments.enumerated()), id: \.element.id) { index, segment in
                dropSegmentRow(segment, index: index)
            }
            addDropSegmentButton
        }
        .cardStyle(padding: 12, cornerRadius: Theme.Radius.md)
    }

    private var dropOuterGroupCountRow: some View {
        HStack(spacing: 12) {
            Text("组数")
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .frame(width: 44, alignment: .leading)
            valuePill(text: dropOuterGroupCountText,
                      placeholder: "组",
                      focused: focusedField == .dropOuterGroupCount,
                      width: nil) {
                focus(.dropOuterGroupCount)
            }
            .id(PlanItemEditorField.dropOuterGroupCount)
        }
    }

    private var dropSegments: [EditablePlanSegment] {
        prescriptions.first?.segments ?? []
    }

    private func countField(title: String, text: String, focused: Bool, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Font.mono(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
            valuePill(text: text, placeholder: "组", focused: focused, width: nil, onTap: onTap)
        }
    }

    private var addDropSegmentButton: some View {
        Button {
            setDropChildGroupCount(dropChildGroupCount + 1)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("添加子组")
                    .font(Theme.Font.body(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(Theme.Color.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(Theme.Color.accentSofter, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加递减组内子组")
    }

    private func dropSegmentRow(_ segment: EditablePlanSegment, index: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(Theme.Font.mono(size: 11, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 18, alignment: .leading)
            valueField(title: "重量", placeholder: "kg",
                       text: segment.weight,
                       focused: focusedField == .dropSegmentWeight(segment.id)) {
                focus(.dropSegmentWeight(segment.id))
            }
            .id(PlanItemEditorField.dropSegmentWeight(segment.id))
            Text("×")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
                .padding(.top, 16)
            valueField(title: "次数", placeholder: "次",
                       text: segment.reps,
                       focused: focusedField == .dropSegmentReps(segment.id)) {
                focus(.dropSegmentReps(segment.id))
            }
            .id(PlanItemEditorField.dropSegmentReps(segment.id))
        }
    }

    private func valueField(title: String, placeholder: String, text: String, focused: Bool, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Font.mono(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
            valuePill(text: text, placeholder: placeholder, focused: focused, width: nil, onTap: onTap)
        }
    }

    private func valuePill(text: String, placeholder: String, focused: Bool, width: CGFloat?, onTap: @escaping () -> Void) -> some View {
        let display = text.isEmpty ? placeholder : text
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        return Button(action: onTap) {
            Text(display)
                .font(Theme.Font.number(size: 14, weight: .bold))
                .foregroundStyle(text.isEmpty ? Theme.Color.muted.opacity(0.45) : Theme.Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .padding(.horizontal, 7)
                .background(Theme.Color.surface, in: shape)
                .overlay(
                    shape.stroke(focused ? Theme.Color.accent : Theme.Color.border,
                                 lineWidth: focused ? 1.7 : 1)
                )
                .frame(width: width)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(display)
    }

    private func addWarmupPrescription() {
        let source = warmupPrescriptions.last?.representativeText ?? (weight: "", reps: "")
        warmupPrescriptions.append(.working(weight: source.weight, reps: source.reps, isWarmup: true))
        isWarmupExpanded = true
    }

    private func removeWarmupPrescription(_ id: UUID) {
        warmupPrescriptions.removeAll { $0.id == id }
        if case .warmupWeight(let focusedId) = focusedField, focusedId == id {
            focusedField = nil
        }
        if case .warmupReps(let focusedId) = focusedField, focusedId == id {
            focusedField = nil
        }
    }

    private func setWarmupWeight(_ value: String, id: UUID) {
        guard let index = warmupPrescriptions.firstIndex(where: { $0.id == id }) else { return }
        warmupPrescriptions[index].weight = value
    }

    private func setWarmupReps(_ value: String, id: UUID) {
        guard let index = warmupPrescriptions.firstIndex(where: { $0.id == id }) else { return }
        warmupPrescriptions[index].reps = value
    }

    private func ensureWorkingPrescription() {
        if prescriptions.isEmpty {
            prescriptions.append(.working(weight: "", reps: "\(PlanDefaults.suggestedReps)"))
        }
        for index in prescriptions.indices {
            prescriptions[index].setType = .working
            prescriptions[index].segments = []
        }
    }

    private func setWorkingWeight(_ value: String) {
        ensureWorkingPrescription()
        for index in prescriptions.indices {
            prescriptions[index].weight = value
        }
    }

    private func setWorkingReps(_ value: String) {
        ensureWorkingPrescription()
        for index in prescriptions.indices {
            prescriptions[index].reps = value
        }
    }

    private func setWorkingGroupCount(_ count: Int) {
        ensureWorkingPrescription()
        let target = max(1, count)
        let source = prescriptions.first?.representativeText ?? (weight: "", reps: "\(PlanDefaults.suggestedReps)")
        if prescriptions.count < target {
            while prescriptions.count < target {
                prescriptions.append(.working(weight: source.weight, reps: source.reps, isWarmup: false))
            }
        } else if prescriptions.count > target {
            prescriptions.removeLast(prescriptions.count - target)
        }
    }

    private func ensureDropPrescription() {
        if prescriptions.isEmpty {
            prescriptions.append(.drop(firstWeight: "", firstReps: "\(PlanDefaults.suggestedReps)"))
        }
        prescriptions[0].setType = .drop
        if prescriptions[0].segments.isEmpty {
            prescriptions[0].segments = [
                EditablePlanSegment(weight: "", reps: "\(PlanDefaults.suggestedReps)"),
                EditablePlanSegment(weight: "", reps: "")
            ]
        }
        if prescriptions.count > 1 {
            prescriptions.removeLast(prescriptions.count - 1)
        }
    }

    private func setDropChildGroupCount(_ count: Int) {
        ensureDropPrescription()
        let target = max(1, count)
        if prescriptions[0].segments.count < target {
            while prescriptions[0].segments.count < target {
                prescriptions[0].segments.append(EditablePlanSegment(weight: "", reps: ""))
            }
        } else if prescriptions[0].segments.count > target {
            prescriptions[0].segments.removeLast(prescriptions[0].segments.count - target)
        }
    }

    private func setDropOuterGroupCount(_ count: Int) {
        let target = max(1, count)
        dropOuterGroupCountText = "\(target)"
    }

    private func setDropSegmentWeight(_ value: String, segmentId: UUID) {
        ensureDropPrescription()
        guard let index = prescriptions[0].segments.firstIndex(where: { $0.id == segmentId }) else { return }
        prescriptions[0].segments[index].weight = value
    }

    private func setDropSegmentReps(_ value: String, segmentId: UUID) {
        ensureDropPrescription()
        guard let index = prescriptions[0].segments.firstIndex(where: { $0.id == segmentId }) else { return }
        prescriptions[0].segments[index].reps = value
    }

    private func focus(_ field: PlanItemEditorField) {
        switch field {
        case .warmupWeight, .warmupReps:
            isWarmupExpanded = true
        default:
            break
        }
        focusedField = field
        replaceOnInput = true
    }

    private func scrollFocusedField(_ field: PlanItemEditorField?, with proxy: ScrollViewProxy) {
        guard let field else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            proxy.scrollTo(field, anchor: .center)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard focusedField == field else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
    }

    private var focusSequence: [PlanItemEditorField] {
        if original.isDropSet {
            return [.dropOuterGroupCount] + dropSegments.flatMap {
                [PlanItemEditorField.dropSegmentWeight($0.id), .dropSegmentReps($0.id)]
            }
        }
        return [.workingGroupCount, .workingWeight, .workingReps] + warmupPrescriptions.flatMap {
            [PlanItemEditorField.warmupWeight($0.id), .warmupReps($0.id)]
        }
    }

    private func focusPreviousField() {
        guard !focusSequence.isEmpty else { return }
        guard let focusedField, let index = focusSequence.firstIndex(of: focusedField) else {
            focus(focusSequence[0])
            return
        }
        focus(focusSequence[(index - 1 + focusSequence.count) % focusSequence.count])
    }

    private func focusNextField() {
        guard !focusSequence.isEmpty else { return }
        guard let focusedField, let index = focusSequence.firstIndex(of: focusedField) else {
            focus(focusSequence[0])
            return
        }
        focus(focusSequence[(index + 1) % focusSequence.count])
    }

    private func keypadDigit(_ digit: Int) {
        guard let field = focusedField else { return }
        let prefix = replaceOnInput ? "" : text(for: field)
        setText(prefix + "\(digit)", for: field)
        replaceOnInput = false
    }

    private func keypadDot() {
        guard let field = focusedField, field.allowsDecimal else { return }
        let current = replaceOnInput ? "" : text(for: field)
        guard !current.contains(".") else { return }
        setText(current.isEmpty ? "0." : current + ".", for: field)
        replaceOnInput = false
    }

    private func keypadBackspace() {
        guard let field = focusedField else { return }
        var current = text(for: field)
        if replaceOnInput {
            current = ""
        } else if !current.isEmpty {
            current.removeLast()
        }
        setText(current, for: field)
        replaceOnInput = false
    }

    private func text(for field: PlanItemEditorField) -> String {
        switch field {
        case .workingGroupCount:
            return "\(workingGroupCount)"
        case .workingReps:
            return workingRepsBinding.wrappedValue
        case .workingWeight:
            return workingWeightBinding.wrappedValue
        case .warmupWeight(let id):
            return warmupPrescriptions.first(where: { $0.id == id })?.weight ?? ""
        case .warmupReps(let id):
            return warmupPrescriptions.first(where: { $0.id == id })?.reps ?? ""
        case .dropOuterGroupCount:
            return dropOuterGroupCountText
        case .dropChildGroupCount:
            return "\(dropChildGroupCount)"
        case .dropSegmentWeight(let id):
            return dropSegments.first(where: { $0.id == id })?.weight ?? ""
        case .dropSegmentReps(let id):
            return dropSegments.first(where: { $0.id == id })?.reps ?? ""
        }
    }

    private func setText(_ value: String, for field: PlanItemEditorField) {
        switch field {
        case .workingGroupCount:
            setWorkingGroupCount(intValue(value) ?? 1)
        case .workingReps:
            setWorkingReps(value)
        case .workingWeight:
            setWorkingWeight(value)
        case .warmupWeight(let id):
            setWarmupWeight(value, id: id)
        case .warmupReps(let id):
            setWarmupReps(value, id: id)
        case .dropOuterGroupCount:
            setDropOuterGroupCount(intValue(value) ?? 1)
        case .dropChildGroupCount:
            setDropChildGroupCount(intValue(value) ?? 1)
        case .dropSegmentWeight(let id):
            setDropSegmentWeight(value, segmentId: id)
        case .dropSegmentReps(let id):
            setDropSegmentReps(value, segmentId: id)
        }
    }
}

private struct EditablePlanPrescription: Identifiable, Hashable {
    let id: UUID
    var setType: WorkoutSetType
    var weight: String
    var reps: String
    var isWarmup: Bool
    var segments: [EditablePlanSegment]

    init(_ prescription: PlanSetPrescription) {
        id = prescription.prescriptionId
        setType = prescription.setType == .drop ? .drop : .working
        weight = prescription.weightKg.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
        reps = prescription.reps.map(String.init) ?? ""
        isWarmup = prescription.isWarmupEffective
        segments = prescription.segments
            .sorted { $0.segmentIndex < $1.segmentIndex }
            .map { segment in
                EditablePlanSegment(id: segment.segmentId,
                                    weight: segment.weightKg.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? "",
                                    reps: segment.reps.map(String.init) ?? "")
            }
        if setType == .drop && segments.isEmpty {
            segments = [EditablePlanSegment(weight: weight, reps: reps), EditablePlanSegment(weight: "", reps: "")]
        }
    }

    static func working(id: UUID = UUID(), weight: String, reps: String, isWarmup: Bool = false) -> EditablePlanPrescription {
        EditablePlanPrescription(id: id, setType: .working, weight: weight, reps: reps, isWarmup: isWarmup, segments: [])
    }

    static func drop(id: UUID = UUID(), firstWeight: String, firstReps: String) -> EditablePlanPrescription {
        EditablePlanPrescription(id: id,
                                 setType: .drop,
                                 weight: "",
                                 reps: "",
                                 isWarmup: false,
                                 segments: [EditablePlanSegment(weight: firstWeight, reps: firstReps),
                                            EditablePlanSegment(weight: "", reps: "")])
    }

    private init(id: UUID, setType: WorkoutSetType, weight: String, reps: String, isWarmup: Bool, segments: [EditablePlanSegment]) {
        self.id = id
        self.setType = setType
        self.weight = weight
        self.reps = reps
        self.isWarmup = isWarmup
        self.segments = segments
    }

    var representativeText: (weight: String, reps: String) {
        if setType == .drop {
            let segment = segments.first { !$0.weight.isEmpty || !$0.reps.isEmpty } ?? segments.first
            return (segment?.weight ?? "", segment?.reps ?? "")
        }
        return (weight, reps)
    }

    func model(orderIndex: Int) -> PlanSetPrescription {
        if setType == .drop {
            let modelSegments = segments.enumerated().map { idx, segment in
                WorkoutSetSegment(segmentId: segment.id,
                                  segmentIndex: idx,
                                  weightKg: decimalValue(segment.weight),
                                  reps: intValue(segment.reps))
            }
            return PlanSetPrescription(prescriptionId: id,
                                       setType: .drop,
                                       orderIndex: orderIndex,
                                       isWarmup: isWarmup,
                                       segments: modelSegments)
        }
        return PlanSetPrescription(prescriptionId: id,
                                   setType: .working,
                                   orderIndex: orderIndex,
                                   weightKg: decimalValue(weight),
                                   reps: intValue(reps),
                                   isWarmup: isWarmup)
    }
}

private struct EditablePlanSegment: Identifiable, Hashable {
    let id: UUID
    var weight: String
    var reps: String

    init(_ segment: WorkoutSetSegment) {
        id = segment.segmentId
        weight = segment.weightKg.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
        reps = segment.reps.map(String.init) ?? ""
    }

    init(id: UUID = UUID(), weight: String, reps: String) {
        self.id = id
        self.weight = weight
        self.reps = reps
    }
}

private func decimalValue(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: ".")
    return trimmed.isEmpty ? nil : Double(trimmed)
}

private func intValue(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : Int(trimmed)
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
