import SwiftUI
import SwiftData
import Charts

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

/// 动作库 · Tab 根页：保留顶部标题与右上自定义动作创建入口。
struct ExerciseLibraryView: View {
    @State private var showingCreate = false
    @State private var selectedExercise: BuiltinExercise?

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ExerciseLibraryContentView(
                    mode: .browse { selectedExercise = $0 },
                    emptyHint: "试试其他关键词，或点右上 + 添加自定义动作。",
                    emptyPlainHint: "切换部位，或点右上 + 添加自定义动作。"
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
        .navigationDestination(item: $selectedExercise) { ExerciseDetailView(exercise: $0) }
    }

    private var header: some View {
        HStack {
            Text("动作")
                .font(Theme.Font.display(size: 36, weight: .heavy))
                .tracking(-1.08)
                .foregroundStyle(Theme.Color.fg)
            Spacer(minLength: 0)
            CircleAddButton(action: { showingCreate = true }, accessibilityLabel: "添加自定义动作")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

/// 可复用动作库主体：不包含顶部标题、右上创建入口或导航外壳，可嵌入 Tab 或底部抽屉。
private struct ExerciseLibraryContentView: View {
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]

    @State private var query = ""
    @State private var selection: LibrarySelection = .all
    /// 手风琴展开态：展开中的 L1、展开中的 L2（单开）。
    @State private var expandedCat: String? = nil
    @State private var expandedNode: String? = nil
    /// 器械轴：「all」或 `EquipmentType.rawValue`。
    @State private var equip: String = "all"
    let mode: ExerciseLibraryContentMode
    let emptyHint: String
    let emptyPlainHint: String

    /// 器械 chip（全部 + EquipmentType）。
    private let equipChips: [LibraryChip] =
        [LibraryChip(id: "all", title: "全部")]
        + EquipmentType.allCases.map { LibraryChip(id: $0.rawValue, title: $0.rawValue) }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    private var searching: Bool { !trimmedQuery.isEmpty }

    /// 全部内置（已归一到解剖三级树）。
    private var allBuiltin: [BuiltinExercise] { BuiltinExercise.starter }
    private var allCustom: [CustomExercise] { custom.filter { $0.deletedAt == nil } }
    private var totalCount: Int { allBuiltin.count + allCustom.count }

    // MARK: 中文模糊多关键词 AND

    private func matchesQuery(_ name: String) -> Bool {
        searching ? ExerciseSearch.matches(name, query: query) : true
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
            guard passesEquipAndQuery(ex.equipmentType, ex.name) else { return false }
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

    // MARK: 左栏数量角标（仅按部位归属计，不随器械/搜索变化）

    private func builtinCount(_ c: ExerciseCategory) -> Int {
        allBuiltin.filter { $0.category == c.rawValue }.count
            + allCustom.filter { $0.primaryMuscle == c.rawValue }.count
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
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Color.muted)
            TextField("", text: $query,
                      prompt: Text("搜索 \(totalCount) 个动作").foregroundColor(Theme.Color.muted))
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
                railRow(title: "全部", level: 0, count: totalCount,
                        selected: isAll, dimmed: searching) { selectAll() }
                railRow(title: "自定义", level: 0, count: allCustom.count,
                        selected: isMine, dimmed: searching) { selectMine() }
                Rectangle().fill(Theme.Color.border).frame(height: 1).padding(.vertical, 4)
                ForEach(ExerciseCategory.allCases) { cat in
                    railRow(title: cat.rawValue, level: 0, count: builtinCount(cat),
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
                railRow(title: h, level: 1, count: nil,
                        selected: isSelectedHead(cat, collapsed.name, h), dimmed: searching) {
                    selectHead(cat, collapsed.name, h)
                }
            }
        } else if cat.isAnatomical {
            ForEach(cat.muscles) { m in
                railRow(title: m.name, level: 1, count: nil,
                        selected: isSelectedNode(cat, m.name), dimmed: searching,
                        chevron: m.hasHeads ? (expandedNode == m.name ? .down : .right) : .none) {
                    tapNode(cat, m.name, hasHeads: m.hasHeads)
                }
                if m.hasHeads && expandedNode == m.name {
                    ForEach(m.heads, id: \.self) { h in
                        railRow(title: h, level: 2, count: nil,
                                selected: isSelectedHead(cat, m.name, h), dimmed: searching) {
                            selectHead(cat, m.name, h)
                        }
                    }
                }
            }
        } else {
            ForEach(cat.browseSubcategories, id: \.self) { sub in
                railRow(title: sub, level: 1, count: nil,
                        selected: isSelectedNode(cat, sub), dimmed: searching) {
                    selectNode(cat, sub)
                }
            }
        }
    }

    private enum Chevron { case none, right, down }

    private func railRow(title: String, level: Int, count: Int?, selected: Bool,
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
                if let count { Text("\(count)").font(Theme.Font.mono(size: 10)).foregroundStyle(Theme.Color.muted) }
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func selectAll() { selection = .all; expandedCat = nil; expandedNode = nil }
    private func selectMine() { selection = .mine; expandedCat = nil; expandedNode = nil }
    private func tapCategory(_ c: ExerciseCategory) {
        selection = .category(c.rawValue)
        expandedNode = nil
        guard hasChildren(c) else { expandedCat = nil; return }
        // 再次点击已展开的一级 → 收起；否则展开（并收起其他一级）
        expandedCat = (expandedCat == c.rawValue) ? nil : c.rawValue
    }
    private func tapNode(_ c: ExerciseCategory, _ n: String, hasHeads: Bool) {
        selection = .node(c.rawValue, n)
        guard hasHeads else { expandedNode = nil; return }
        // 再次点击已展开的二级 → 收起；否则展开（并收起其他二级）
        expandedNode = (expandedNode == n) ? nil : n
    }
    private func selectNode(_ c: ExerciseCategory, _ n: String) {
        selection = .node(c.rawValue, n)
    }
    private func selectHead(_ c: ExerciseCategory, _ n: String, _ h: String) {
        selection = .head(c.rawValue, n, h)
    }

    // MARK: 右侧动作区（器械 chip + 按树层级分段，逐行懒加载 + 返回顶部）

    private var rightArea: some View {
        let prWeights = historyStore.exercisePRs.mapValues(\.weightKg)
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // 置顶器械轴：固定在右侧顶部，不随动作列表滚动；重复点已激活 chip 也回顶
                HorizontalChipPicker(items: equipChips, selection: $equip,
                                     onReselect: { _ in scrollLibToTop(proxy) }) { $0.title }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                Rectangle().fill(Theme.Color.border).frame(height: 1)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("LIB_TOP")
                        if filteredBuiltin.isEmpty && filteredCustom.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(libRows.enumerated()), id: \.element.id) { idx, row in
                                libRowView(row, prWeights: prWeights, isFirst: idx == 0)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, 8)
                }
            }
            // 左栏筛选切换 / 器械筛选切换 → 列表自动回顶
            .onAppear { WorkoutPerformanceMonitor.event("exercise.library.appear") }
            .onChange(of: selection) { _, _ in
                WorkoutPerformanceMonitor.event("exercise.library.filter")
                proxy.scrollTo("LIB_TOP", anchor: .top)
            }
            .onChange(of: equip) { _, _ in
                WorkoutPerformanceMonitor.event("exercise.library.filter")
                proxy.scrollTo("LIB_TOP", anchor: .top)
            }
            .onChange(of: trimmedQuery) { _, _ in
                WorkoutPerformanceMonitor.event("exercise.library.search")
            }
        }
    }

    /// 平滑回到动作列表顶部（用于重复点击已激活 chip）。
    private func scrollLibToTop(_ proxy: ScrollViewProxy) {
        Theme.Haptics.impact(.light)
        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("LIB_TOP", anchor: .top) }
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

    /// 把分段 + 自定义摊平成逐行（作为外层 LazyVStack 直接子视图 → 真·懒加载）。
    private var libRows: [LibRow] {
        var rows: [LibRow] = []
        let customs = filteredCustom
        if !customs.isEmpty {
            rows.append(.header("自定义"))
            for (i, ex) in customs.enumerated() {
                rows.append(.custom(ex, i == 0, i == customs.count - 1))
            }
        }
        for seg in builtinSegments {
            if !seg.title.isEmpty { rows.append(.header(seg.title)) }
            for (i, ex) in seg.items.enumerated() {
                rows.append(.builtin(ex, i == 0, i == seg.items.count - 1))
            }
        }
        return rows
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
                customRow(ex, prWeights: prWeights)
                    .modifier(RowCardSlice(first: first, last: last))
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
            avatar(String(ex.name.prefix(1)))
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

    private func avatar(_ ch: String) -> some View {
        Text(ch)
            .font(Theme.Font.body(size: 14, weight: .bold))
            .foregroundStyle(Theme.Color.fg2)
            .frame(width: 40, height: 40)
            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
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

/// C 设计稿 Screen 12 · 方案 C「底部滚轮 Picker」。
/// 表单极简两字段（主要肌群 + 器械），选择交由从底部升起的自绘滚轮承载：
/// 点字段 → 滚轮升起 + scrim 压暗表单 → 滚动居中高亮（朱砂红选中带）→「完成」回填。
struct CustomExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedMuscle: String? = nil
    @State private var selectedEquip: String? = nil

    /// 当前升起的滚轮（nil = 收起，仅表单态）。
    @State private var activeWheel: WheelKind? = nil
    /// 滚轮当前居中项（滚动停止后回填的候选值）。
    @State private var centeredValue: String? = nil

    private var nameTrimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !nameTrimmed.isEmpty }

    /// 滚轮升起/收起的统一动效曲线（设计稿规格）。
    private var wheelAnimation: Animation { .timingCurve(0.32, 1, 0.36, 1, duration: 0.32) }

    var body: some View {
        // scrim 与滚轮用 overlay 承载（不参与表单 sheet 的基础布局，避免底对齐基准变化导致抖动）。
        formSheet
            .overlay {
                if activeWheel != nil {
                    Theme.Color.fg.opacity(0.28)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { closeWheel(commit: false) }
                }
            }
            .overlay(alignment: .bottom) {
                if let kind = activeWheel {
                    wheelSheet(kind)
                        .transition(.move(edge: .bottom))
                }
            }
            .background(Theme.Color.surface)
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.hidden)
            // 二级滚轮打开时禁止下拉关闭表单 sheet。
            .interactiveDismissDisabled(activeWheel != nil)
    }

    // MARK: - 表单 sheet（grab + 头部 + 三字段 + 底部保存）

    private var formSheet: some View {
        VStack(spacing: 0) {
            // grab handle
            Capsule()
                .fill(Theme.Color.border2)
                .frame(width: 34, height: 4)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xs)

            PaperSheetHeader(
                title: "新建动作",
                cancelTitle: "取消",
                topPadding: Theme.Spacing.lg,
                bottomPadding: Theme.Spacing.md,
                background: Theme.Color.surface,
                onCancel: { dismiss() }
            )

            // 字段区
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                field("动作名称", required: true) {
                    TextField("输入名称（必填）", text: $name).paperField()
                }
                field("主要肌群") { pickerField(.muscle) }
                field("器械") { pickerField(.equipment) }
            }
            .padding(Theme.Spacing.md)

            Spacer(minLength: 0)

            // 底部保存
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
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.lg)
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

    /// 收起态 Picker 行：空=placeholder 灰；编辑中=朱砂红边+浅红底；已选=墨黑值。
    private func pickerField(_ kind: WheelKind) -> some View {
        let value = kind == .muscle ? selectedMuscle : selectedEquip
        let active = activeWheel == kind
        return HStack {
            Text(value ?? kind.placeholder)
                .font(Theme.Font.l2)
                .fontWeight(value == nil ? .regular : .semibold)
                .foregroundStyle(value == nil ? Theme.Color.muted : Theme.Color.fg)
            Spacer()
            Image(systemName: "chevron.down")
                .font(Theme.Font.l4)
                .foregroundStyle(active ? Theme.Color.accent : Theme.Color.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(active ? Theme.Color.accentSoft : Theme.Color.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(active ? Theme.Color.accent : Theme.Color.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { openWheel(kind) }
    }

    // MARK: - 滚轮弹层

    private func wheelSheet(_ kind: WheelKind) -> some View {
        VStack(spacing: 0) {
            // 顶栏：标题 | 完成（取消路径 = 点 scrim）
            PaperSheetHeader(
                title: kind.title,
                cancelTitle: nil,
                confirmTitle: "完成",
                topPadding: 14,
                bottomPadding: 14,
                background: Theme.Color.surface,
                onConfirm: { closeWheel(commit: true) }
            )

            // 滚轮：选中带 + 自绘滚动列表
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.Color.accentSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .stroke(Theme.Color.accentSofter, lineWidth: 1)
                    )
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)
                WheelPicker(options: kind.options, centered: $centeredValue)
            }
            .frame(height: 220)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .background(Theme.Color.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.lg,
                                          topTrailingRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: Theme.Color.fg.opacity(0.18), radius: 20, x: 0, y: -10)
    }

    // MARK: - 滚轮开关

    private func openWheel(_ kind: WheelKind) {
        let current = kind == .muscle ? selectedMuscle : selectedEquip
        centeredValue = current ?? kind.options.first   // 非动画：避免初始定位被动画化
        Theme.Haptics.impact(.light)
        withAnimation(wheelAnimation) { activeWheel = kind }
    }

    /// 关闭滚轮。commit=true 时把居中项回填到对应字段。
    private func closeWheel(commit: Bool) {
        if commit, let kind = activeWheel {
            switch kind {
            case .muscle:    selectedMuscle = centeredValue
            case .equipment: selectedEquip = centeredValue
            }
            Theme.Haptics.selection()
        }
        withAnimation(wheelAnimation) { activeWheel = nil }
    }

    private func save() {
        // 设计稿：肌群/器械可空 → 落库补「未分类」。
        let ex = CustomExercise(name: nameTrimmed,
                                primaryMuscle: selectedMuscle ?? "未分类",
                                equipmentType: selectedEquip ?? "未分类")
        modelContext.insert(ex)
        try? modelContext.save()
        Theme.Haptics.notification(.success)
        dismiss()
    }
}

/// 滚轮字段种类（肌群 / 器械），与动作库筛选同一套枚举。
private enum WheelKind: Equatable {
    case muscle, equipment

    var title: String { self == .muscle ? "主要肌群" : "器械" }
    var placeholder: String { self == .muscle ? "选择肌群" : "选择器械" }
    var options: [String] {
        switch self {
        case .muscle:    return ExerciseCategory.allCases.map(\.rawValue)
        case .equipment: return EquipmentType.allCases.map(\.rawValue)
        }
    }
}

/// 自绘 iOS 风格滚轮（对齐 C 设计稿动效规格）：
/// 行高 38 / 可视 5 行 / scroll-snap 吸附 / 居中行朱砂红加粗放大 1.06、相邻行渐隐。
private struct WheelPicker: View {
    let options: [String]
    @Binding var centered: String?

    private let itemH: CGFloat = 44
    private let visibleH: CGFloat = 220   // 5 行

    var body: some View {
        let centerIdx = centered.flatMap { options.firstIndex(of: $0) }
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element) { idx, opt in
                        let dist = centerIdx.map { abs($0 - idx) }
                        Text(opt)
                            .font(Theme.Font.l2)
                            .fontWeight(dist == 0 ? .bold : .medium)
                            .foregroundStyle(dist == 0 ? Theme.Color.accent : Theme.Color.muted)
                            .opacity(dist == 1 ? 0.7 : 1)
                            .scaleEffect(dist == 0 ? 1.06 : 1)
                            .frame(maxWidth: .infinity)
                            .frame(height: itemH)
                            .id(opt)
                            .animation(.easeOut(duration: 0.12), value: centerIdx)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: visibleH)
            .contentMargins(.vertical, (visibleH - itemH) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centered, anchor: .center)
            .onAppear {
                if let c = centered { proxy.scrollTo(c, anchor: .center) }
            }
        }
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

// MARK: - 动作选择器 Sheet（C 设计稿 Screen 9 · 计划/训练复用）

/// 选择器分组：个人置顶，其后按大肌群（顺序对齐设计稿）。
/// 既作分组键、ScrollView 定位锚点，也作右侧快捷索引项。
private enum PickerGroup: Hashable {
    case personal
    case muscle(ExerciseCategory)

    /// 分组与右侧索引顺序：个人 + 全部 ExerciseCategory 父级（枚举声明序）。
    static let order: [PickerGroup] = [.personal] + ExerciseCategory.allCases.map { .muscle($0) }

    /// 组头标题（朱砂红 mono）。
    var title: String {
        switch self {
        case .personal: return "个人"
        case .muscle(let m): return m.rawValue
        }
    }

    /// 右侧快捷索引单字（个人 = ★，肌群取首字）。
    var indexLabel: String {
        switch self {
        case .personal: return "★"
        case .muscle(let m): return String(m.rawValue.prefix(1))
        }
    }
}

/// 选择器内部行数据（携带回传 payload）。
private struct PickerRow: Identifiable {
    let id: String
    let name: String
    let muscle: String?
    let equipment: String?
    let isCustom: Bool
    let pick: ExercisePick
}

/// 组头在滚动坐标系中的 minY，用于推断「当前所在组」高亮右侧索引。
private struct GroupOffsetKey: PreferenceKey {
    static let defaultValue: [PickerGroup: CGFloat] = [:]
    static func reduce(value: inout [PickerGroup: CGFloat], nextValue: () -> [PickerGroup: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 右侧索引条总高度，用于把拖动 y 坐标映射到索引项。
private struct IndexBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 动作选择器 Sheet：去掉下拉筛选，列表直接按大肌群分组；右侧 iOS 风格快捷索引一触定位；
/// 实时搜索跨组过滤，空结果转「创建自定义」引导；点击行回传选中动作。
private struct LegacyExercisePickerView: View {
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showingCreate = false
    @State private var currentGroup: PickerGroup = .personal
    @State private var barHeight: CGFloat = 0
    let onPick: (ExercisePick) -> Void

    var body: some View {
        let groups = buildGroups()
        let ordered = PickerGroup.order.filter { groups[$0]?.isEmpty == false }
        VStack(spacing: 0) {
            header
            searchBar
            if ordered.isEmpty {
                emptyState
            } else {
                listWithIndex(groups: groups, ordered: ordered)
            }
        }
        .background(Theme.Color.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
    }

    // MARK: 顶栏（取消 / 标题 / 占位对称）

    private var header: some View {
        PaperSheetHeader(
            title: "选择动作",
            cancelTitle: "取消",
            topPadding: 24,
            bottomPadding: 12,
            background: Theme.Color.surface,
            onCancel: { dismiss() }
        )
    }

    // MARK: 搜索框（实时跨组过滤）

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Color.muted)
            TextField("", text: $query, prompt: Text("搜索动作…").foregroundColor(Theme.Color.muted))
                .font(Theme.Font.body(size: 14))
                .foregroundStyle(Theme.Color.fg)
                .submitLabel(.search)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: 分组列表 + 右侧快捷索引

    private func listWithIndex(groups: [PickerGroup: [PickerRow]], ordered: [PickerGroup]) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(ordered, id: \.self) { g in
                            groupHeader(g)
                            let rows = groups[g] ?? []
                            ForEach(rows) { r in
                                Button { onPick(r.pick); dismiss() } label: { row(r) }
                                    .buttonStyle(PressableButtonStyle())
                                if r.id != rows.last?.id { rowDivider }
                            }
                        }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 28)   // 让出右侧索引条
                }
                .coordinateSpace(name: "pickerList")
                .onPreferenceChange(GroupOffsetKey.self) { updateCurrentGroup($0) }

                indexBar(groups: groups, proxy: proxy)
                    .padding(.trailing, 5)
            }
        }
    }

    private func groupHeader(_ g: PickerGroup) -> some View {
        Text(g.title)
            .font(Theme.Font.mono(size: 10, weight: .semibold))
            .tracking(0.1 * 10)
            .foregroundStyle(Theme.Color.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
            .padding(.top, 9)
            .padding(.bottom, 6)
            .id(g)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: GroupOffsetKey.self,
                        value: [g: geo.frame(in: .named("pickerList")).minY]
                    )
                }
            )
    }

    private func row(_ r: PickerRow) -> some View {
        HStack(spacing: 12) {
            avatar(String(r.name.prefix(1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                if let meta = [r.muscle, r.equipment].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(meta)
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.muted)
                }
            }
            Spacer(minLength: 8)
            if r.isCustom { personalTag }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private func avatar(_ ch: String) -> some View {
        Text(ch)
            .font(Theme.Font.body(size: 12, weight: .bold))
            .foregroundStyle(Theme.Color.fg2)
            .frame(width: 38, height: 38)
            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
    }

    private var personalTag: some View {
        Text("个人")
            .font(Theme.Font.mono(size: 9, weight: .semibold))
            .tracking(0.04 * 9)
            .foregroundStyle(Theme.Color.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(Theme.Color.accentSofter, lineWidth: 1))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.Color.border.opacity(0.55))
            .frame(height: 1)
    }

    /// 右侧 iOS 通讯录式索引条：点或上下拖动一触定位到对应肌群组头。
    private func indexBar(groups: [PickerGroup: [PickerRow]], proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 4) {
            ForEach(PickerGroup.order, id: \.self) { g in
                let hasItems = (groups[g]?.isEmpty == false)
                let isCurrent = (currentGroup == g)
                Text(g.indexLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isCurrent ? Theme.Color.surface
                                     : (hasItems ? Theme.Color.accent : Theme.Color.border2))
                    .background(
                        Circle().fill(isCurrent ? Theme.Color.accent : .clear)
                    )
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: IndexBarHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(IndexBarHeightKey.self) { barHeight = $0 }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in jumpToIndex(at: value.location.y, groups: groups, proxy: proxy) }
        )
    }

    // MARK: 空态（无匹配 → 创建自定义引导）

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Text(query.isEmpty ? "暂无动作" : "无匹配动作")
                .font(Theme.Font.display(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text(query.isEmpty ? "点击下方创建自定义动作"
                 : "「\(query.trimmingCharacters(in: .whitespaces))」没有匹配，可创建为自定义动作")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.muted)
                .multilineTextAlignment(.center)
            Button { showingCreate = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("创建自定义动作")
                }
                .font(Theme.Font.body(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.bg)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(height: 44)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .paperShadow(.sm, cornerRadius: Theme.Radius.md)
            }
            .buttonStyle(PressableButtonStyle())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.lg)
    }

    // MARK: 数据与交互

    /// 个人组（自定义动作恒置顶）+ 各大肌群（内置库）；query 非空时跨组过滤。
    private func buildGroups() -> [PickerGroup: [PickerRow]] {
        let q = query.trimmingCharacters(in: .whitespaces)
        func match(_ name: String) -> Bool { q.isEmpty || name.localizedCaseInsensitiveContains(q) }

        var dict: [PickerGroup: [PickerRow]] = [:]

        let personal = custom
            .filter { $0.deletedAt == nil && match($0.name) }
            .map { ex in
                PickerRow(id: "c-\(ex.localId.uuidString)", name: ex.name,
                          muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: true,
                          pick: ExercisePick(builtinCode: nil, customId: ex.localId,
                                             name: ex.name, primaryMuscle: ex.primaryMuscle,
                                             equipmentType: ex.equipmentType))
            }
        if !personal.isEmpty { dict[.personal] = personal }

        for case let .muscle(m) in PickerGroup.order {
            let rows = BuiltinExercise.starter
                .filter { $0.category == m.rawValue && match($0.name) }
                .map { ex in
                    PickerRow(id: "b-\(ex.code)", name: ex.name,
                              muscle: ex.category, equipment: ex.equipmentType, isCustom: false,
                              pick: ExercisePick(builtinCode: ex.code, customId: nil,
                                                 name: ex.name, primaryMuscle: ex.category,
                                                 equipmentType: ex.equipmentType))
                }
            if !rows.isEmpty { dict[.muscle(m)] = rows }
        }
        return dict
    }

    /// 组头中最靠近顶部（已滚过顶）的组即「当前组」；都未滚过则取首个可见组。
    private func updateCurrentGroup(_ offsets: [PickerGroup: CGFloat]) {
        let threshold: CGFloat = 8
        let passed = offsets.filter { $0.value <= threshold }
        let target: PickerGroup?
        if let top = passed.max(by: { $0.value < $1.value }) {
            target = top.key
        } else {
            target = PickerGroup.order.first { offsets[$0] != nil }
        }
        if let target, target != currentGroup { currentGroup = target }
    }

    /// 把索引条上的触点 y 映射到对应肌群组头并滚动定位（点击与拖动共用）。
    private func jumpToIndex(at y: CGFloat, groups: [PickerGroup: [PickerRow]], proxy: ScrollViewProxy) {
        let items = PickerGroup.order
        guard barHeight > 0 else { return }
        let slice = barHeight / CGFloat(items.count)
        let idx = min(items.count - 1, max(0, Int(y / slice)))
        let g = items[idx]
        // 置灰（无该肌群动作）的索引项不可定位。
        guard groups[g]?.isEmpty == false else { return }
        if g != currentGroup {
            currentGroup = g
            UISelectionFeedbackGenerator().selectionChanged()
        }
        // 拖动时即时跳转（不包动画），跟手手感对齐 iOS 通讯录 A–Z 索引。
        proxy.scrollTo(g, anchor: .top)
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
            miniChart
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

    /// 每训练日最大重量序列（按时间升序）。
    private var chartData: [(idx: Int, weight: Double)] {
        history.chartPoints
    }

    @ViewBuilder private var miniChart: some View {
        let data = chartData
        if data.count >= 2 {
            Chart(data, id: \.idx) { p in
                BarMark(x: .value("次", p.idx), y: .value("kg", p.weight))
                    .foregroundStyle(Theme.Color.accentSofter)
                    .cornerRadius(2)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 46)
        }
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
