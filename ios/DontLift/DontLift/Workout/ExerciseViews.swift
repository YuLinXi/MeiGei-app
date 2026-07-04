import SwiftUI
import SwiftData

/// 选择动作的结果：内置 code 或自定义 id 二选一。
struct ExercisePick: Identifiable, Hashable {
    var builtinCode: String?
    var customId: UUID?
    var name: String
    var primaryMuscle: String?
    var equipmentType: String?
    var id: String { builtinCode ?? customId?.uuidString ?? name }
}

// MARK: - 3.4 动作库（Screen 04，Neon 改版）

/// 动作库筛选 chip 项（id="all" 或 ExerciseCategory/EquipmentType/子分类的中文值）。
struct LibraryChip: Identifiable, Hashable {
    let id: String
    let title: String
}

struct LibraryQuickIndexHitTesting {
    static func itemIndex(at y: CGFloat, itemCount: Int, itemHeight: CGFloat, spacing: CGFloat) -> Int? {
        guard itemCount > 0, itemHeight > 0, spacing >= 0 else { return nil }
        let totalHeight = CGFloat(itemCount) * itemHeight + CGFloat(max(0, itemCount - 1)) * spacing
        guard totalHeight > 0 else { return nil }
        let clampedY = min(max(y, 0), totalHeight - 0.001)
        let stride = itemHeight + spacing
        return min(itemCount - 1, max(0, Int(clampedY / stride)))
    }
}

/// 动作库左栏选择态（解剖三级树的当前下钻位置）。
private enum LibrarySelection: Hashable {
    case all                                   // 全部
    case mine                                  // 我的（自定义）
    case category(String)                      // L1 部位
    case node(String, String)                  // L1 + L2（解剖肌肉 或 非解剖浏览子类）
    case head(String, String, String)          // L1 + L2 + L3 肌头
}

/// 行卡片切片：复刻纸感分组卡——surface 底 + 左右描边、首行顶边/末行底边、行间分隔线、首末圆角。
/// 每行独立成视图以支持外层 LazyVStack 逐行懒加载。
private struct RowCardSlice: ViewModifier {
    let first: Bool
    let last: Bool
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: first ? Theme.Radius.md : 0,
            bottomLeadingRadius: last ? Theme.Radius.md : 0,
            bottomTrailingRadius: last ? Theme.Radius.md : 0,
            topTrailingRadius: first ? Theme.Radius.md : 0,
            style: .continuous)
    }
    func body(content: Content) -> some View {
        content
            .background(Theme.Color.surface)
            .overlay(alignment: .top)      { if first { hline } }
            .overlay(alignment: .bottom)   { hline }
            .overlay(alignment: .leading)  { vline }
            .overlay(alignment: .trailing) { vline }
            .clipShape(shape)
    }
    private var hline: some View { Rectangle().fill(Theme.Color.border).frame(height: 1) }
    private var vline: some View { Rectangle().fill(Theme.Color.border).frame(width: 1) }
}

/// 动作库内容的使用场景：Tab 浏览打开详情；添加动作抽屉回传选择结果。
private enum ExerciseLibraryContentMode {
    case browse(onBuiltin: (BuiltinExercise) -> Void)
    case pick(onPick: (ExercisePick) -> Void)
}

private struct LibraryQuickIndexItem: Identifiable, Hashable {
    var id: String
    var title: String
    var label: String
    var systemName: String?
    var isSelected: Bool
}

private struct LibraryQuickIndex: View {
    let items: [LibraryQuickIndexItem]
    let onActivate: (LibraryQuickIndexItem) -> Void

    @State private var activeItemId: String?

    private static let itemHeight: CGFloat = 28
    private static let itemSpacing: CGFloat = 6
    private static let hitWidth: CGFloat = 42

    private var contentHeight: CGFloat {
        CGFloat(items.count) * Self.itemHeight + CGFloat(max(0, items.count - 1)) * Self.itemSpacing
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: Self.itemSpacing) {
                ForEach(items) { item in
                    indexItem(item)
                        .frame(width: Self.hitWidth, height: Self.itemHeight)
                }
            }
            .frame(width: Self.hitWidth, height: contentHeight, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard let index = LibraryQuickIndexHitTesting.itemIndex(
                            at: value.location.y,
                            itemCount: items.count,
                            itemHeight: Self.itemHeight,
                            spacing: Self.itemSpacing
                        ) else { return }
                        activate(items[index])
                    }
                    .onEnded { _ in
                        activeItemId = nil
                    }
            )
            .accessibilityElement(children: .contain)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(width: Self.hitWidth, height: contentHeight)
        .padding(.vertical, 6)
    }

    private func activate(_ item: LibraryQuickIndexItem) {
        guard activeItemId != item.id else { return }
        activeItemId = item.id
        Theme.Haptics.selection()
        onActivate(item)
    }

    @ViewBuilder
    private func indexItem(_ item: LibraryQuickIndexItem) -> some View {
        let highlighted = item.isSelected || activeItemId == item.id
        Group {
            if let systemName = item.systemName {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
            } else {
                Text(item.title)
                    .font(Theme.Font.mono(size: 10, weight: .bold))
                    .foregroundStyle(highlighted ? Theme.Color.accent : Theme.Color.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: 28, height: 28)
        .background {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill((highlighted ? Theme.Color.accentSoft : Theme.Color.surface).opacity(highlighted ? 0.72 : 0.42))
                }
        }
        .overlay {
            Circle()
                .stroke((highlighted ? Theme.Color.accentSofter : Theme.Color.border).opacity(highlighted ? 0.9 : 0.52), lineWidth: 0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(item.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            activate(item)
        }
    }
}

private enum MuscleThumbnailAssetKey: String {
    case chest
    case shoulders
    case shouldersFront = "shoulders_front"
    case shouldersRear = "shoulders_rear"
    case back
    case backLats = "back_lats"
    case backTraps = "back_traps"
    case backRhomboids = "back_rhomboids"
    case backLowerBack = "back_lowerBack"
    case arms
    case armsBiceps = "arms_biceps"
    case armsTriceps = "arms_triceps"
    case armsForearms = "arms_forearms"
    case legs
    case legsQuads = "legs_quads"
    case legsHams = "legs_hams"
    case legsAdductors = "legs_adductors"
    case legsCalves = "legs_calves"
    case glutes
    case glutesGlutes = "glutes_glutes"
    case glutesGluteMed = "glutes_gluteMed"
    case core
    case coreAbs = "core_abs"
    case coreObliques = "core_obliques"
    case neck

    var assetName: String {
        "muscleThumb_male_\(rawValue)"
    }
}

/// 动作库 · Tab 根页：不展示顶部标题，仅保留右上自定义动作创建入口。
struct ExerciseLibraryView: View {
    @State private var showingCreate = false
    @State private var selectedExercise: BuiltinExercise?

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ExerciseLibraryContentView(
                    mode: .browse { selectedExercise = $0 },
                    emptyHint: "试试其他关键词，或点右下 + 添加自定义动作。",
                    emptyPlainHint: "切换部位，或点右下 + 添加自定义动作。"
                )
                .padding(.top, Theme.Spacing.md)
            }
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            floatingAddButton
        }
        .rootTabTopScrim()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
        .navigationDestination(item: $selectedExercise) { ExerciseDetailView(exercise: $0) }
    }

    private var floatingAddButton: some View {
        CircleAddButton(action: { showingCreate = true }, accessibilityLabel: "添加自定义动作")
            .frame(width: 48, height: 48)
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
    }
}

/// 可复用动作库主体：不包含顶部标题、右上创建入口或导航外壳，可嵌入 Tab 或底部抽屉。
private struct ExerciseLibraryContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]

    @State private var query = ""
    @State private var selection: LibrarySelection = .all
    /// 手风琴展开态：展开中的 L1、展开中的 L2（单开）。
    @State private var expandedCat: String? = nil
    @State private var expandedNode: String? = nil
    /// 器械轴：「all」或 `EquipmentType.rawValue`。
    @State private var equip: String = "all"
    @State private var pendingDeleteCustom: CustomExercise?
    @State private var visibleLibRowLimit = 60
    let mode: ExerciseLibraryContentMode
    let emptyHint: String
    let emptyPlainHint: String

    private static let quickIndexTopID = "__top"
    private static let initialLibraryRowLimit = 60
    private static let libraryRowPageSize = 50

    /// 器械 chip（全部 + EquipmentType）。
    private let equipChips: [LibraryChip] =
        [LibraryChip(id: "all", title: "全部")]
        + EquipmentType.allCases.map { LibraryChip(id: $0.rawValue, title: $0.rawValue) }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    private var searching: Bool { !trimmedQuery.isEmpty }

    /// 全部内置（已归一到解剖三级树）。
    private var allBuiltin: [BuiltinExercise] { BuiltinExercise.starter }
    private var allCustom: [CustomExercise] { custom.filter { $0.deletedAt == nil } }
    // MARK: 中文模糊多关键词 AND

    private func matchesQuery(_ name: String) -> Bool {
        searching ? ExerciseSearch.matches(name, query: query) : true
    }

    private func matchesQuery(_ exercise: BuiltinExercise) -> Bool {
        searching ? ExerciseSearch.matches(exercise, query: query) : true
    }

    // MARK: 解剖归位辅助

    /// 动作在某 L1 内命中的 L2 肌肉名（按 primaryRegions 经 regionOwner 派生）。空=该 L1 内无 L2（归「全部」段）。
    private func muscleNames(_ ex: BuiltinExercise) -> [String] {
        guard let cat = ExerciseCategory(rawValue: ex.category), cat.isAnatomical else { return [] }
        var names: [String] = []
        for r in ex.primaryRegions {
            if let owner = ExerciseCategory.regionOwner[r], owner.category == cat,
               !names.contains(owner.muscle.name) {
                names.append(owner.muscle.name)
            }
        }
        return names
    }

    // MARK: 过滤（器械 + 搜索恒定叠加；搜索态忽略左栏）

    private func passesEquipAndQuery(_ equipType: String?, _ name: String) -> Bool {
        (equip == "all" || equipType == equip) && matchesQuery(name)
    }

    private var filteredBuiltin: [BuiltinExercise] {
        allBuiltin.filter { ex in
            guard (equip == "all" || ex.equipmentType == equip) && matchesQuery(ex) else { return false }
            if searching { return true }
            switch selection {
            case .all:                 return true
            case .mine:                return false
            case .category(let c):     return ex.category == c
            case .node(let c, let n):
                guard ex.category == c else { return false }
                if let cat = ExerciseCategory(rawValue: c), cat.isAnatomical {
                    return muscleNames(ex).contains(n)
                }
                return ex.subcategory == n
            case .head(let c, let n, let h):
                return ex.category == c && ex.subcategory == h && muscleNames(ex).contains(n)
            }
        }
    }

    private var filteredCustom: [CustomExercise] {
        allCustom.filter { ex in
            guard passesEquipAndQuery(ex.equipmentType, ex.name) else { return false }
            if searching { return true }
            switch selection {
            case .all, .mine:          return true
            case .category(let c):     return ex.primaryMuscle == c
            case .node, .head:         return false   // 自定义无肌肉/肌头粒度
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar.padding(.horizontal, Theme.Spacing.lg).padding(.bottom, 8)
            HStack(spacing: 0) {
                leftRail
                Rectangle().fill(Theme.Color.border).frame(width: 1)
                rightArea
            }
        }
        .paperConfirmDialog(
            isPresented: Binding(
                get: { pendingDeleteCustom != nil },
                set: { if !$0 { pendingDeleteCustom = nil } }
            ),
            title: "删除自定义动作?",
            message: deleteConfirmMessage,
            confirmTitle: "删除动作",
            onConfirm: {
                if let ex = pendingDeleteCustom {
                    deleteCustom(ex)
                }
            }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Color.muted)
            TextField("", text: $query,
                      prompt: Text("搜索动作").foregroundColor(Theme.Color.muted))
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Color.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Color.border2, lineWidth: 1)
        )
    }

    // MARK: 左栏（解剖三级树逐级手风琴）

    private var leftRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                railRow(title: "全部", level: 0,
                        selected: isAll, dimmed: searching) { selectAll() }
                railRow(title: "自定义", level: 0,
                        selected: isMine, dimmed: searching) { selectMine() }
                Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.vertical, 4)
                ForEach(ExerciseCategory.allCases) { cat in
                    railRow(title: cat.rawValue, level: 0,
                            selected: isSelectedCat(cat), dimmed: searching,
                            chevron: hasChildren(cat) ? (expandedCat == cat.rawValue ? .down : .right) : .none) {
                        tapCategory(cat)
                    }
                    if expandedCat == cat.rawValue { childRows(cat) }
                }
                Color.clear.frame(height: 24)
            }
            .padding(.vertical, 8)
            .padding(.leading, 8)
            .padding(.trailing, 4)
        }
        .frame(width: 104)
    }

    /// L2/L3 子行（手风琴展开）。
    @ViewBuilder
    private func childRows(_ cat: ExerciseCategory) -> some View {
        if let collapsed = cat.collapsedBrowseMuscle {
            ForEach(collapsed.heads, id: \.self) { h in
                railRow(title: h, level: 1,
                        selected: isSelectedHead(cat, collapsed.name, h), dimmed: searching) {
                    selectHead(cat, collapsed.name, h)
                }
            }
        } else if cat.isAnatomical {
            ForEach(cat.muscles) { m in
                railRow(title: m.name, level: 1,
                        selected: isSelectedNode(cat, m.name), dimmed: searching,
                        chevron: m.hasHeads ? (expandedNode == m.name ? .down : .right) : .none) {
                    tapNode(cat, m.name, hasHeads: m.hasHeads)
                }
                if m.hasHeads && expandedNode == m.name {
                    ForEach(m.heads, id: \.self) { h in
                        railRow(title: h, level: 2,
                                selected: isSelectedHead(cat, m.name, h), dimmed: searching) {
                            selectHead(cat, m.name, h)
                        }
                    }
                }
            }
        } else {
            ForEach(cat.browseSubcategories, id: \.self) { sub in
                railRow(title: sub, level: 1,
                        selected: isSelectedNode(cat, sub), dimmed: searching) {
                    selectNode(cat, sub)
                }
            }
        }
    }

    private enum Chevron { case none, right, down }

    private func railRow(title: String, level: Int, selected: Bool,
                         dimmed: Bool, chevron: Chevron = .none,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .font(Theme.Font.body(size: level == 0 ? 16 : (level == 1 ? 14 : 13),
                                          weight: selected ? .bold : (level == 0 ? .semibold : .regular)))
                    .foregroundStyle(selected ? Theme.Color.accent
                                     : (dimmed ? Theme.Color.muted : Theme.Color.fg))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                switch chevron {
                case .none:  EmptyView()
                case .right: Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.Color.muted)
                case .down:  Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.Color.accent)
                }
            }
            .padding(.leading, CGFloat(level) * 9)
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.Color.accentSoft : .clear,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .animation(nil, value: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    // MARK: 选中态判定

    private var isAll: Bool { if case .all = selection { return true }; return false }
    private var isMine: Bool { if case .mine = selection { return true }; return false }
    private func isSelectedCat(_ c: ExerciseCategory) -> Bool {
        if case .category(let x) = selection { return x == c.rawValue }; return false
    }
    private func isSelectedNode(_ c: ExerciseCategory, _ n: String) -> Bool {
        if case .node(let x, let y) = selection { return x == c.rawValue && y == n }; return false
    }
    private func isSelectedHead(_ c: ExerciseCategory, _ n: String, _ h: String) -> Bool {
        if case .head(let x, let y, let z) = selection { return x == c.rawValue && y == n && z == h }; return false
    }
    private func hasChildren(_ c: ExerciseCategory) -> Bool {
        c.isAnatomical ? !c.muscles.isEmpty : !c.browseSubcategories.isEmpty
    }

    // MARK: 左栏交互（点哪级过滤到哪级 + 逐级手风琴）

    private func updateRailSelection(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }

    private func selectAll() {
        updateRailSelection {
            selection = .all
            expandedCat = nil
            expandedNode = nil
        }
    }

    private func selectMine() {
        updateRailSelection {
            selection = .mine
            expandedCat = nil
            expandedNode = nil
        }
    }

    private func tapCategory(_ c: ExerciseCategory) {
        updateRailSelection {
            selection = .category(c.rawValue)
            expandedNode = nil
            guard hasChildren(c) else { expandedCat = nil; return }
            // 再次点击已展开的一级 → 收起；否则展开（并收起其他一级）
            expandedCat = (expandedCat == c.rawValue) ? nil : c.rawValue
        }
    }

    private func tapNode(_ c: ExerciseCategory, _ n: String, hasHeads: Bool) {
        updateRailSelection {
            selection = .node(c.rawValue, n)
            guard hasHeads else { expandedNode = nil; return }
            // 再次点击已展开的二级 → 收起；否则展开（并收起其他二级）
            expandedNode = (expandedNode == n) ? nil : n
        }
    }

    private func selectNode(_ c: ExerciseCategory, _ n: String) {
        updateRailSelection {
            selection = .node(c.rawValue, n)
        }
    }

    private func selectHead(_ c: ExerciseCategory, _ n: String, _ h: String) {
        updateRailSelection {
            selection = .head(c.rawValue, n, h)
        }
    }

    // MARK: 右侧动作区（右侧器械快速筛选 + 按树层级分段，逐行懒加载 + 返回顶部）

    private var rightArea: some View {
        let prWeights = historyStore.exercisePRs.mapValues(\.weightKg)
        let rowPage = libraryRowPage
        return ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("LIB_TOP")
                        if rowPage.rows.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(rowPage.rows.enumerated()), id: \.element.id) { idx, row in
                                libRowView(row, prWeights: prWeights, isFirst: idx == 0)
                            }
                            if rowPage.hasMore {
                                loadMoreLibraryRowsTrigger(totalExerciseCount: rowPage.totalExerciseCount)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.leading, Theme.Spacing.md)
                    .padding(.trailing, Theme.Spacing.xl + 20)
                    .padding(.top, 8)
                }

                LibraryQuickIndex(items: quickIndexItems) { item in
                    activateQuickIndexItem(item, proxy: proxy)
                }
                    .padding(.trailing, 4)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .topTrailing)
            }
            // 左栏筛选切换 / 器械筛选切换 → 列表自动回顶
            .onAppear { WorkoutPerformanceMonitor.event("exercise.library.appear") }
            .onChange(of: selection) { _, _ in
                WorkoutPerformanceMonitor.event("exercise.library.filter")
                resetLibraryPaging()
                proxy.scrollTo("LIB_TOP", anchor: .top)
            }
            .onChange(of: equip) { _, _ in
                WorkoutPerformanceMonitor.event("exercise.library.filter")
                resetLibraryPaging()
                proxy.scrollTo("LIB_TOP", anchor: .top)
            }
            .onChange(of: trimmedQuery) { _, _ in
                WorkoutPerformanceMonitor.event("exercise.library.search")
                resetLibraryPaging()
                proxy.scrollTo("LIB_TOP", anchor: .top)
            }
        }
    }

    private var quickIndexItems: [LibraryQuickIndexItem] {
        [LibraryQuickIndexItem(
            id: Self.quickIndexTopID,
            title: "",
            label: "回到顶部",
            systemName: "arrow.up",
            isSelected: false
        )]
        + equipChips.map { chip in
            LibraryQuickIndexItem(
                id: chip.id,
                title: equipmentQuickLabel(for: chip),
                label: "筛选\(chip.title)",
                systemName: nil,
                isSelected: equip == chip.id
            )
        }
    }

    private func activateQuickIndexItem(_ item: LibraryQuickIndexItem, proxy: ScrollViewProxy) {
        if item.id == Self.quickIndexTopID {
            scrollLibToTop(proxy, haptic: false)
        } else if equip == item.id {
            scrollLibToTop(proxy, haptic: false)
        } else {
            equip = item.id
        }
    }

    private func equipmentQuickLabel(for chip: LibraryChip) -> String {
        switch chip.id {
        case "all": return "全"
        case EquipmentType.barbell.rawValue: return "杠"
        case EquipmentType.dumbbell.rawValue: return "哑"
        case EquipmentType.kettlebell.rawValue: return "壶"
        case EquipmentType.machine.rawValue: return "器"
        case EquipmentType.smith.rawValue: return "史"
        case EquipmentType.hammer.rawValue: return "悍"
        case EquipmentType.tbar.rawValue: return "T"
        case EquipmentType.cable.rawValue: return "绳"
        case EquipmentType.band.rawValue: return "弹"
        case EquipmentType.suspension.rawValue: return "悬"
        case EquipmentType.bodyweight.rawValue: return "自"
        case EquipmentType.other.rawValue: return "其"
        default: return String(chip.title.prefix(1))
        }
    }

    /// 平滑回到动作列表顶部（用于重复点击已激活 chip）。
    private func scrollLibToTop(_ proxy: ScrollViewProxy, haptic: Bool = true) {
        if haptic { Theme.Haptics.impact(.light) }
        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("LIB_TOP", anchor: .top) }
    }

    private func resetLibraryPaging() {
        visibleLibRowLimit = Self.initialLibraryRowLimit
    }

    @ViewBuilder
    private func loadMoreLibraryRowsTrigger(totalExerciseCount: Int) -> some View {
        Color.clear
            .frame(height: 1)
            .onAppear {
                loadMoreLibraryRowsIfNeeded(totalExerciseCount: totalExerciseCount)
            }
    }

    private func loadMoreLibraryRowsIfNeeded(totalExerciseCount: Int) {
        guard shouldPageLibraryRows, visibleLibRowLimit < totalExerciseCount else { return }
        visibleLibRowLimit = min(totalExerciseCount, visibleLibRowLimit + Self.libraryRowPageSize)
    }

    /// 扁平行模型：段头 / 内置行 / 自定义行（first/last 控制卡片切片圆角与分隔）。
    private enum LibRow: Identifiable {
        case header(String)
        case builtin(BuiltinExercise, Bool, Bool)
        case custom(CustomExercise, Bool, Bool)
        var id: String {
            switch self {
            case .header(let t):        return "h:" + t
            case .builtin(let e, _, _): return "b:" + e.code
            case .custom(let e, _, _):  return "c:" + e.localId.uuidString
            }
        }
    }

    private struct LibraryRowPage {
        let rows: [LibRow]
        let visibleExerciseCount: Int
        let totalExerciseCount: Int

        var hasMore: Bool { visibleExerciseCount < totalExerciseCount }
    }

    private var shouldPageLibraryRows: Bool {
        isAll && !searching
    }

    private var libraryRowPage: LibraryRowPage {
        makeLibraryRows(limit: shouldPageLibraryRows ? visibleLibRowLimit : nil)
    }

    /// 把分段 + 自定义摊平成逐行，并在「全部」页只构建当前可见批次。
    private func makeLibraryRows(limit: Int?) -> LibraryRowPage {
        var rows: [LibRow] = []
        var visibleExerciseCount = 0
        var totalExerciseCount = 0
        let customs = filteredCustom
        totalExerciseCount += customs.count
        if !customs.isEmpty, let visibleCustoms = visibleItems(customs, limit: limit, currentCount: visibleExerciseCount) {
            rows.append(.header("自定义"))
            for (i, ex) in visibleCustoms.enumerated() {
                rows.append(.custom(ex, i == 0, i == visibleCustoms.count - 1))
            }
            visibleExerciseCount += visibleCustoms.count
        }
        for seg in builtinSegments {
            totalExerciseCount += seg.items.count
            guard let visibleItems = visibleItems(seg.items, limit: limit, currentCount: visibleExerciseCount) else {
                continue
            }
            if !seg.title.isEmpty { rows.append(.header(seg.title)) }
            for (i, ex) in visibleItems.enumerated() {
                rows.append(.builtin(ex, i == 0, i == visibleItems.count - 1))
            }
            visibleExerciseCount += visibleItems.count
        }
        return LibraryRowPage(rows: rows,
                              visibleExerciseCount: visibleExerciseCount,
                              totalExerciseCount: totalExerciseCount)
    }

    private func visibleItems<T>(_ items: [T], limit: Int?, currentCount: Int) -> [T]? {
        guard !items.isEmpty else { return nil }
        guard let limit else { return items }
        let remaining = limit - currentCount
        guard remaining > 0 else { return nil }
        return Array(items.prefix(remaining))
    }

    @ViewBuilder
    private func libRowView(_ row: LibRow, prWeights: [String: Double], isFirst: Bool) -> some View {
        switch row {
        case .header(let title):
            sectionHeader(title, topGap: isFirst ? 2 : 14)
        case .builtin(let ex, let first, let last):
            Button { selectBuiltin(ex) } label: { builtinRow(ex, prWeights: prWeights) }
                .buttonStyle(.plain)
                .modifier(RowCardSlice(first: first, last: last))
        case .custom(let ex, let first, let last):
            if isPicking {
                Button { selectCustom(ex) } label: { customRow(ex, prWeights: prWeights) }
                    .buttonStyle(.plain)
                    .modifier(RowCardSlice(first: first, last: last))
            } else {
                customBrowseRow(ex, first: first, last: last, prWeights: prWeights)
            }
        }
    }

    private var isPicking: Bool {
        if case .pick = mode { return true }
        return false
    }

    private func selectBuiltin(_ ex: BuiltinExercise) {
        switch mode {
        case .browse(let onBuiltin):
            onBuiltin(ex)
        case .pick(let onPick):
            onPick(ExercisePick(builtinCode: ex.code,
                                customId: nil,
                                name: ex.name,
                                primaryMuscle: ex.category,
                                equipmentType: ex.equipmentType))
        }
    }

    private func selectCustom(_ ex: CustomExercise) {
        guard case .pick(let onPick) = mode else { return }
        onPick(ExercisePick(builtinCode: nil,
                            customId: ex.localId,
                            name: ex.name,
                            primaryMuscle: ex.primaryMuscle,
                            equipmentType: ex.equipmentType))
    }

    private var deleteConfirmMessage: String {
        guard let ex = pendingDeleteCustom else { return "" }
        return "将从动作库和后续选择器移除「\(ex.name)」。历史训练和已有计划会保留。"
    }

    private func requestDeleteCustom(_ ex: CustomExercise) {
        Theme.Haptics.selection()
        pendingDeleteCustom = ex
    }

    private func deleteCustom(_ ex: CustomExercise) {
        ex.markDeleted()
        try? modelContext.save()
        Theme.Haptics.notification(.warning)
        syncEngine.scheduleSyncAll()
    }

    private func customBrowseRow(_ ex: CustomExercise, first: Bool, last: Bool, prWeights: [String: Double]) -> some View {
        customRow(ex, prWeights: prWeights)
            .modifier(RowCardSlice(first: first, last: last))
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.5) {
                requestDeleteCustom(ex)
            }
            .accessibilityHint("长按删除自定义动作")
            .accessibilityAction(named: "删除") {
                requestDeleteCustom(ex)
            }
    }

    private struct Segment { let title: String; let items: [BuiltinExercise] }

    /// curated 优先的稳定排序。
    private func curatedFirst(_ items: [BuiltinExercise]) -> [BuiltinExercise] {
        items.enumerated().sorted { a, b in
            let ca = BuiltinExercise.curatedCodes.contains(a.element.code)
            let cb = BuiltinExercise.curatedCodes.contains(b.element.code)
            if ca != cb { return ca }
            return a.offset < b.offset
        }.map(\.element)
    }

    private var builtinSegments: [Segment] {
        let items = filteredBuiltin
        if items.isEmpty { return [] }
        // 搜索态或「全部」→ 按 L1 分段
        if searching || isAll {
            return groupByL1(items)
        }
        switch selection {
        case .category(let c):
            guard let cat = ExerciseCategory(rawValue: c) else { return flat(items) }
            if let collapsed = cat.collapsedBrowseMuscle { return groupByHead(items, muscle: collapsed) }
            if cat.isAnatomical { return groupByMuscle(items, cat: cat) }
            return groupByBrowseSub(items, cat: cat)
        case .node(let c, let n):
            if let cat = ExerciseCategory(rawValue: c), cat.isAnatomical,
               let m = cat.muscles.first(where: { $0.name == n }), m.hasHeads {
                return groupByHead(items, muscle: m)
            }
            return flat(items)
        default:
            return flat(items)
        }
    }

    private func flat(_ items: [BuiltinExercise]) -> [Segment] { [Segment(title: "", items: curatedFirst(items))] }

    private func groupByL1(_ items: [BuiltinExercise]) -> [Segment] {
        ExerciseCategory.allCases.compactMap { cat in
            let sub = items.filter { $0.category == cat.rawValue }
            return sub.isEmpty ? nil : Segment(title: cat.rawValue, items: curatedFirst(sub))
        }
    }

    private func groupByMuscle(_ items: [BuiltinExercise], cat: ExerciseCategory) -> [Segment] {
        var segs: [Segment] = []
        for m in cat.muscles {
            let sub = items.filter { muscleNames($0).first == m.name }
            if !sub.isEmpty { segs.append(Segment(title: m.name, items: curatedFirst(sub))) }
        }
        let rest = items.filter { muscleNames($0).isEmpty }
        if !rest.isEmpty { segs.append(Segment(title: "全部", items: curatedFirst(rest))) }
        return segs
    }

    private func groupByBrowseSub(_ items: [BuiltinExercise], cat: ExerciseCategory) -> [Segment] {
        var segs: [Segment] = []
        for sub in cat.browseSubcategories {
            let g = items.filter { $0.subcategory == sub }
            if !g.isEmpty { segs.append(Segment(title: sub, items: curatedFirst(g))) }
        }
        let rest = items.filter { $0.subcategory == nil || !cat.browseSubcategories.contains($0.subcategory!) }
        if !rest.isEmpty { segs.append(Segment(title: "全部", items: curatedFirst(rest))) }
        return segs
    }

    private func groupByHead(_ items: [BuiltinExercise], muscle: MuscleNode) -> [Segment] {
        var segs: [Segment] = []
        for h in muscle.heads {
            let g = items.filter { $0.subcategory == h }
            if !g.isEmpty { segs.append(Segment(title: h, items: curatedFirst(g))) }
        }
        let rest = items.filter { $0.subcategory == nil || !muscle.heads.contains($0.subcategory!) }
        if !rest.isEmpty { segs.append(Segment(title: "全部", items: curatedFirst(rest))) }
        return segs
    }

    // MARK: 空态

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(searching ? "无匹配" : "动作库").eyebrowStyle()
            Text(searching ? "没有匹配「\(trimmedQuery)」的动作" : "该部位暂无动作")
                .font(Theme.Font.display(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text(searching ? emptyHint : emptyPlainHint)
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: 列表样式件

    private func sectionHeader(_ title: String, topGap: CGFloat = 14) -> some View {
        Text(title)
            .font(Theme.Font.mono(size: 10, weight: .regular))
            .tracking(0.1 * 10)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Color.muted)
            .padding(.top, topGap)
            .padding(.bottom, 6)
            .padding(.leading, 2)
    }

    private func builtinRow(_ ex: BuiltinExercise, prWeights: [String: Double]) -> some View {
        let muscle = displayMuscleName(for: ex)
        let sub = [muscle, ex.subcategory].compactMap { $0 }.joined(separator: " · ")
        let meta = sub.isEmpty ? "\(ex.category) · \(ex.equipmentType)" : "\(ex.category) · \(sub) · \(ex.equipmentType)"
        return HStack(spacing: 12) {
            builtinThumbnail(ex)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                Text(meta)
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let w = prWeights[ex.code] { prPill("PR \(formatKg(w))") }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func builtinThumbnail(_ ex: BuiltinExercise) -> some View {
        if let assetName = thumbnailAssetName(for: ex) {
            MuscleMapThumbnail(assetName: assetName,
                               size: 48)
        } else {
            avatar(String(ex.name.prefix(1)), size: 48)
        }
    }

    private func thumbnailAssetName(for ex: BuiltinExercise) -> String? {
        guard !ex.primaryRegions.isEmpty,
              let category = ExerciseCategory(rawValue: ex.category),
              category.isAnatomical,
              !category.regions.isEmpty else {
            return nil
        }
        let categoryRegions = Set(category.regions)
        let regions = ex.primaryRegions.filter { categoryRegions.contains($0) }
        let key = thumbnailAssetKey(for: ex, category: category, regions: regions)
        return key?.assetName
    }

    private func thumbnailAssetKey(for ex: BuiltinExercise,
                                   category: ExerciseCategory,
                                   regions: [MuscleRegion]) -> MuscleThumbnailAssetKey? {
        guard !regions.isEmpty else { return fallbackThumbnailAssetKey(for: category) }
        if let subcategory = ex.subcategory,
           let region = ExerciseCategory.regionForSubcategory(subcategory),
           regions.contains(region),
           let key = thumbnailAssetKey(for: region, category: category) {
            return key
        }

        for region in regions {
            if let key = thumbnailAssetKey(for: region, category: category) {
                return key
            }
        }
        return fallbackThumbnailAssetKey(for: category)
    }

    private func thumbnailAssetKey(for region: MuscleRegion, category: ExerciseCategory) -> MuscleThumbnailAssetKey? {
        switch category {
        case .chest:
            return .chest
        case .shoulders:
            switch region {
            case .deltFront: return .shouldersFront
            case .deltRear: return .shouldersRear
            default: return .shoulders
            }
        case .back:
            switch region {
            case .lats: return .backLats
            case .traps: return .backTraps
            case .rhomboids: return .backRhomboids
            case .lowerBack: return .backLowerBack
            default: return .back
            }
        case .arms:
            switch region {
            case .biceps: return .armsBiceps
            case .triceps: return .armsTriceps
            case .forearms: return .armsForearms
            default: return .arms
            }
        case .legs:
            switch region {
            case .quads: return .legsQuads
            case .hams: return .legsHams
            case .adductors: return .legsAdductors
            case .calves: return .legsCalves
            default: return .legs
            }
        case .glutes:
            switch region {
            case .glutes: return .glutesGlutes
            case .gluteMed: return .glutesGluteMed
            default: return .glutes
            }
        case .core:
            switch region {
            case .abs: return .coreAbs
            case .obliques: return .coreObliques
            default: return .core
            }
        case .neck:
            return .neck
        default:
            return nil
        }
    }

    private func fallbackThumbnailAssetKey(for category: ExerciseCategory) -> MuscleThumbnailAssetKey? {
        switch category {
        case .chest: return .chest
        case .back: return .back
        case .shoulders: return .shoulders
        case .arms: return .arms
        case .legs: return .legs
        case .glutes: return .glutes
        case .core: return .core
        case .neck: return .neck
        default: return nil
        }
    }

    private func displayMuscleName(for ex: BuiltinExercise) -> String? {
        guard let muscle = muscleNames(ex).first else { return nil }
        guard let cat = ExerciseCategory(rawValue: ex.category),
              cat.collapsedBrowseMuscle?.name == muscle else {
            return muscle
        }
        return nil
    }

    private func customRow(_ ex: CustomExercise, prWeights: [String: Double]) -> some View {
        return HStack(spacing: 12) {
            avatar(String(ex.name.prefix(1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                Text("\(ex.primaryMuscle ?? "—") · \(ex.equipmentType ?? "—")")
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer(minLength: 8)
            if let w = prWeights[ex.localId.uuidString] { selfTag("\(formatKg(w)) kg") }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }

    private func avatar(_ ch: String, size: CGFloat = 40) -> some View {
        let radius: CGFloat = size > 40 ? 12 : 11
        return Text(ch)
            .font(Theme.Font.body(size: size > 40 ? 15 : 14, weight: .bold))
            .foregroundStyle(Theme.Color.fg2)
            .frame(width: size, height: size)
            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
    }

    private func prPill(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.mono(size: 9, weight: .bold))
            .tracking(0.04 * 9)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.Color.accent, in: Capsule())
    }

    private func selfTag(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.mono(size: 9, weight: .bold))
            .foregroundStyle(Theme.Color.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(Theme.Color.accentSofter, lineWidth: 1))
    }
}

// MARK: - 自定义动作创建

/// 新建自定义动作：名称必填，部位与器械使用动作库同源标签。
struct CustomExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedMuscle: String? = nil
    @State private var selectedEquip: String? = nil
    @State private var contentHeight: CGFloat = 520

    private var nameTrimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !nameTrimmed.isEmpty }
    private var sheetHeight: CGFloat { min(max(contentHeight, 360), 640) }

    private let muscleOptions = ExerciseCategory.allCases.map(\.rawValue)
    private let equipmentOptions = EquipmentType.allCases.map(\.rawValue)
    private let tagColumns = [GridItem(.adaptive(minimum: 74), spacing: 8)]

    var body: some View {
        formSheet
            .background(Theme.Color.surface)
            .presentationDetents([.height(sheetHeight)])
            .presentationCornerRadius(26)
            .presentationBackground(Theme.Color.surface)
            .presentationDragIndicator(.hidden)
    }

    // MARK: - 表单 sheet

    private var formSheet: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: "新建动作",
                cancelTitle: nil,
                showsHandle: true,
                topPadding: 0,
                bottomPadding: 10,
                background: Theme.Color.surface
            )

            VStack(alignment: .leading, spacing: 16) {
                field("动作名称", required: true) {
                    TextField("输入名称（必填）", text: $name)
                        .paperField()
                        .submitLabel(.done)
                }

                tagSection(title: "部位", options: muscleOptions, selection: $selectedMuscle)
                tagSection(title: "器械", options: equipmentOptions, selection: $selectedEquip)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 14)

            Button { save() } label: {
                Text("保存")
                    .font(Theme.Font.l1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Color.accent,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.38)
            .shadow(color: Theme.Color.accent.opacity(canSave ? 0.22 : 0), radius: 14, x: 0, y: 4)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 18)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateContentHeight(proxy.size.height) }
                    .onChange(of: proxy.size.height) { _, height in updateContentHeight(height) }
            }
        }
    }

    /// 字段：label（必填红 *）+ 内容。
    private func field<C: View>(_ label: String, required: Bool = false,
                                @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 2) {
                Text(label)
                    .font(Theme.Font.l4)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Color.fg2)
                if required {
                    Text("*").font(Theme.Font.l4).foregroundStyle(Theme.Color.accent)
                }
            }
            content()
        }
    }

    private func tagSection(title: String, options: [String], selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(Theme.Font.l4)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Color.fg2)

            LazyVGrid(columns: tagColumns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    tagButton(option, selected: selection.wrappedValue == option) {
                        Theme.Haptics.selection()
                        selection.wrappedValue = selection.wrappedValue == option ? nil : option
                    }
                }
            }
        }
    }

    private func tagButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.body(size: 13, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.fg2)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(selected ? Theme.Color.accentSoft : Theme.Color.surface2,
                            in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(selected ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    private func updateContentHeight(_ height: CGFloat) {
        let rounded = ceil(height)
        guard abs(contentHeight - rounded) > 1 else { return }
        contentHeight = rounded
    }

    private func save() {
        let ex = CustomExercise(name: nameTrimmed,
                                primaryMuscle: selectedMuscle,
                                equipmentType: selectedEquip)
        modelContext.insert(ex)
        try? modelContext.save()
        Theme.Haptics.notification(.success)
        dismiss()
    }
}

/// 添加动作抽屉：复用动作库主体，不提供标题栏或创建自定义动作入口。
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (ExercisePick) -> Void

    var body: some View {
        ExerciseLibraryContentView(
            mode: .pick { pick in
                onPick(pick)
                dismiss()
            },
            emptyHint: "试试其他关键词，或切换分类。",
            emptyPlainHint: "切换分类查看其它动作。"
        )
        .padding(.top, 14)
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - 动作详情（设计稿 03）

/// 动作详情（设计稿 v2）：纯浏览/查资料页——高亮图 + 标题 + 你的数据 + 要点 + 目标肌群。
/// 不含任何写训练数据入口（旧「加入今日训练」CTA 已移除，加动作走 ExercisePicker / 计划编辑）。
struct ExerciseDetailView: View {
    let exercise: BuiltinExercise
    @Environment(SessionStore.self) private var session
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    /// 用户性别（仅切高亮图底图）。
    private var sex: BodySex {
        profiles.first { $0.serverUserId == session.currentUserId }?.sex ?? .male
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                titleSection
                yourDataSection
                if !exercise.formCues.isEmpty { cuesSection }
                if !exercise.primaryRegions.isEmpty { targetMusclesSection }
                if !exercise.primaryRegions.isEmpty { muscleMapSection }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        // 子页统一导航栏：纸感圆形返回钮（标题留空，动作名在内容区大字呈现）。
        .paperToolbar(onBack: { dismiss() })
        .onAppear { WorkoutPerformanceMonitor.event("exercise.detail.appear") }
    }

    // MARK: 训练部位（正背肌群图）

    private var muscleMapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("训练部位").eyebrowStyle()
            MuscleMapView(primary: exercise.primaryRegions,
                          secondary: exercise.secondaryRegions,
                          sex: sex)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .cardStyle()
        }
    }

    // MARK: 标题 + meta chip（不暴露内部 code）

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(Theme.Font.display(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            HStack(spacing: 7) {
                metaChip(exercise.category)
                if let sub = exercise.subcategory { metaChip(sub) }
                metaChip(exercise.equipmentType)
            }
        }
    }
    private func metaChip(_ s: String) -> some View {
        Text(s)
            .font(Theme.Font.body(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Color.fg2)
            .padding(.horizontal, 11).padding(.vertical, 4)
            .background(Theme.Color.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
    }

    // MARK: 你的数据（读取可重建 projection，不在视图层扫全量训练）

    private var history: ExerciseHistorySnapshot {
        historyStore.exerciseHistory(for: exercise.code)
    }

    private var yourDataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("你的数据").eyebrowStyle()
            if history.isEmpty {
                Text("还没练过 · 去训练里记录这个动作")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                dataCard
            }
        }
    }

    private var dataCard: some View {
        let pr = history.pr
        let last = history.last
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                dataCell("上次", lastAgoText(last))
                dataCell("最近一组", lastSetText(last))
                dataCell("PR", pr.map { "\(formatKg($0.weightKg))kg" } ?? "—", accent: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func dataCell(_ k: String, _ v: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(Theme.Font.mono(size: 9)).foregroundStyle(Theme.Color.muted)
            Text(v).font(Theme.Font.body(size: 16, weight: .bold))
                .foregroundStyle(accent ? Theme.Color.accent : Theme.Color.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lastAgoText(_ point: ExerciseHistoryPoint?) -> String {
        guard let d = point?.date else { return "—" }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: .now)).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "昨天" }
        return "\(days) 天前"
    }
    private func lastSetText(_ point: ExerciseHistoryPoint?) -> String {
        guard let wt = point?.lastSetWeightKg, let r = point?.lastSetReps else { return "—" }
        return "\(formatKg(wt))×\(r)"
    }

    // MARK: 动作要点

    private var cuesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("动作要点").eyebrowStyle()
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(exercise.formCues.enumerated()), id: \.offset) { i, cue in
                    HStack(alignment: .top, spacing: 9) {
                        Text("\(i + 1)").font(Theme.Font.mono(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Color.accent).frame(width: 14)
                        Text(cue).font(Theme.Font.body(size: 13)).foregroundStyle(Theme.Color.fg2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    // MARK: 目标肌群（与高亮图三态色同源）

    private var targetMusclesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("目标肌群").eyebrowStyle()
            VStack(alignment: .leading, spacing: 10) {
                muscleRow(color: Theme.Color.accent, tag: "主动肌", regions: exercise.primaryRegions)
                if !exercise.secondaryRegions.isEmpty {
                    muscleRow(color: Theme.Color.accentSofter, tag: "协同肌", regions: exercise.secondaryRegions)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }
    private func muscleRow(color: Color, tag: String, regions: [MuscleRegion]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
            Text(tag).font(Theme.Font.mono(size: 10)).foregroundStyle(Theme.Color.muted)
                .frame(width: 44, alignment: .leading)
            Text(regions.map(\.displayName).joined(separator: " · "))
                .font(Theme.Font.body(size: 14, weight: .semibold)).foregroundStyle(Theme.Color.fg)
        }
    }
}
