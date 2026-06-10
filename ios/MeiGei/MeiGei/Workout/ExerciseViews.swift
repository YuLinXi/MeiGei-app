import SwiftUI
import SwiftData

/// 选择动作的结果：内置 code 或自定义 id 二选一。
struct ExercisePick: Identifiable, Hashable {
    var builtinCode: String?
    var customId: UUID?
    var name: String
    var primaryMuscle: String?
    var id: String { builtinCode ?? customId?.uuidString ?? name }
}

// MARK: - 3.4 动作库（Screen 04，Neon 改版）

/// 动作库筛选 chip 项。
struct LibraryChip: Identifiable, Hashable {
    let id: String
    let title: String
    let muscle: MuscleGroup?  // nil = 全部
}

/// 动作分组（复合 推 / 拉 / 腿 + 单关节）。
private enum LibraryGroup: String, CaseIterable {
    case push = "复合 · 推"
    case pull = "复合 · 拉"
    case leg  = "复合 · 腿"
    case iso  = "单关节"

    static func classify(_ code: String) -> LibraryGroup {
        switch code {
        case "BB_BENCH_PRESS", "DB_BENCH_PRESS", "INCLINE_BB_PRESS", "PUSH_UP",
             "OHP", "DB_SHOULDER_PRESS":
            return .push
        case "PULL_UP", "BB_ROW", "LAT_PULLDOWN", "DEADLIFT", "SEATED_CABLE_ROW", "FACE_PULL":
            return .pull
        case "BB_SQUAT", "LEG_PRESS", "ROMANIAN_DL", "HIP_THRUST":
            return .leg
        default:
            return .iso
        }
    }
}

/// 动作库 · Tab 根页（设计稿 Screen 10）：
/// 自绘大标题头 + 真实搜索 + 部位 chip 筛选 + 分组列表（自定义→复合推/拉/腿→单关节），行右显示 PR。
struct ExerciseLibraryView: View {
    @Query(sort: \CustomExercise.updatedAt, order: .reverse) private var custom: [CustomExercise]
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]

    @State private var query = ""
    @State private var muscle: String = "all"
    @State private var showingCreate = false

    private let chips: [LibraryChip] = [
        LibraryChip(id: "all",      title: "全部", muscle: nil),
        LibraryChip(id: "chest",    title: "胸",   muscle: .chest),
        LibraryChip(id: "back",     title: "背",   muscle: .back),
        LibraryChip(id: "leg",      title: "腿",   muscle: .legs),
        LibraryChip(id: "shoulder", title: "肩",   muscle: .shoulders),
        LibraryChip(id: "arm",      title: "手臂", muscle: .arms),
        LibraryChip(id: "core",     title: "核心", muscle: .core),
    ]

    private var selectedMuscle: MuscleGroup? {
        chips.first(where: { $0.id == muscle })?.muscle
    }

    /// 去空白后的搜索词；空则不参与名称过滤。
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// 库内动作总量（内置 + 自定义），用于搜索框占位。
    private var totalCount: Int {
        BuiltinExercise.starter.count + custom.filter { $0.deletedAt == nil }.count
    }

    /// 同时按部位 chip 与搜索词（名称子串，忽略大小写）过滤内置动作。
    private var builtinFiltered: [BuiltinExercise] {
        BuiltinExercise.starter.filter { ex in
            (selectedMuscle == nil || ex.primaryMuscle == selectedMuscle?.rawValue)
                && (trimmedQuery.isEmpty || ex.name.localizedCaseInsensitiveContains(trimmedQuery))
        }
    }

    private var customFiltered: [CustomExercise] {
        custom.filter { ex in
            ex.deletedAt == nil
                && (selectedMuscle == nil || ex.primaryMuscle == selectedMuscle?.rawValue)
                && (trimmedQuery.isEmpty || ex.name.localizedCaseInsensitiveContains(trimmedQuery))
        }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                        searchBar
                        HorizontalChipPicker(items: chips, selection: $muscle) { $0.title }
                            .padding(.horizontal, -Theme.Spacing.lg)

                        if builtinFiltered.isEmpty && customFiltered.isEmpty {
                            emptyState
                        } else {
                            groupedList
                        }
                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, 6)
                }
            }
        }
        // 自绘大标题头（对齐设计稿 .nav，与首页一致），隐藏系统导航栏。
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCreate) { CustomExerciseEditorView() }
        .navigationDestination(for: BuiltinExercise.self) { ExerciseDetailView(exercise: $0) }
    }

    // MARK: Header（设计稿 .nav：大标题「动作」+ 右侧圆形朱砂红 +）

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

    // 搜索框（真实可用）：暖底 + 实线次边框 + 放大镜 + 清除按钮。
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

    @ViewBuilder
    private var emptyState: some View {
        let searching = !trimmedQuery.isEmpty
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(searching ? "NO MATCH · 无匹配" : "EMPTY · 动作库").eyebrowStyle()
            Text(searching ? "没有匹配「\(trimmedQuery)」的动作" : "该部位暂无动作")
                .font(Theme.Font.display(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text(searching ? "试试其他关键词，或点右上 + 添加自定义动作。" : "切换部位，或点右上 + 添加自定义动作。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var groupedList: some View {
        // 内置按分组拆分
        let grouped = Dictionary(grouping: builtinFiltered) { LibraryGroup.classify($0.code) }
        let orderedGroups: [LibraryGroup] = LibraryGroup.allCases.filter { grouped[$0]?.isEmpty == false }

        if !customFiltered.isEmpty {
            sectionHeader("我的 · 自定义")
            exList {
                ForEach(Array(customFiltered.enumerated()), id: \.element.localId) { idx, ex in
                    if idx > 0 { rowDivider }
                    customRow(ex)
                }
            }
        }

        ForEach(orderedGroups, id: \.self) { g in
            sectionHeader(g.rawValue)
            let items = grouped[g] ?? []
            exList {
                ForEach(Array(items.enumerated()), id: \.element.code) { idx, ex in
                    if idx > 0 { rowDivider }
                    NavigationLink(value: ex) {
                        builtinRow(ex)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 分组标题（.grp）：等宽小字、宽字距、muted。
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Font.mono(size: 10, weight: .regular))
            .tracking(0.1 * 10)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Color.muted)
            .padding(.top, 4)
            .padding(.leading, 2)
    }

    /// 列表容器（.ex-list）：白底卡片 + 圆角裁切 + border + 纸感阴影。
    /// 阴影作用在底层「不透明圆角矩形」上（有明确路径，GPU 走 shadowPath），
    /// 避免把 `.shadow` 加在 `.clipShape` 后的复合视图上而触发离屏渲染——
    /// 后者在 LazyVStack 滚动时会产生矩形色块/黑块残影。
    private func exList<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Color.border, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Color.surface)
                    .shadow(color: Theme.Color.fg.opacity(Theme.ShadowLevel.sm.opacity),
                            radius: Theme.ShadowLevel.sm.radius, x: 0, y: Theme.ShadowLevel.sm.y)
            )
    }

    /// 行分隔线（.ex + .ex border-top）：整行通栏，无左缩进。
    private var rowDivider: some View {
        Rectangle().fill(Theme.Color.border).frame(height: 1)
    }

    private func builtinRow(_ ex: BuiltinExercise) -> some View {
        let pr = PRStats.latestPR(for: ex.code, in: workouts)
        return HStack(spacing: 12) {
            avatar(String(ex.name.prefix(1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                Text("\(ex.primaryMuscle) · \(ex.equipmentType)")
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer(minLength: 8)
            if let pr {
                prPill("PR \(formatKg(pr.weightKg))")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func customRow(_ ex: CustomExercise) -> some View {
        let pr = PRStats.latestPR(for: ex.localId.uuidString, in: workouts)
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
            if let pr {
                selfTag("\(formatKg(pr.weightKg)) kg")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }

    /// 行首方形首字头像（.av）：暖底 + border。
    private func avatar(_ ch: String) -> some View {
        Text(ch)
            .font(Theme.Font.body(size: 14, weight: .bold))
            .foregroundStyle(Theme.Color.fg2)
            .frame(width: 40, height: 40)
            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
    }

    /// 内置动作 PR 药丸（.pr）：朱砂红实心 + 白字。
    private func prPill(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.mono(size: 9, weight: .bold))
            .tracking(0.04 * 9)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.Color.accent, in: Capsule())
    }

    /// 自定义动作重量药丸（.selftag）：朱砂红描边 + 红字、无填充。
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

            // 头部：左「取消」+ 居中标题
            ZStack {
                Text("新建动作")
                    .font(Theme.Font.l1)
                    .foregroundStyle(Theme.Color.fg)
                HStack {
                    Button("取消") { dismiss() }
                        .font(Theme.Font.l3)
                        .foregroundStyle(Theme.Color.muted)
                    Spacer()
                }
            }
            .padding(.top, Theme.Spacing.lg)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            .overlay(alignment: .bottom) {
                Theme.Color.border.frame(height: 1)
            }

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
            ZStack {
                Text(kind.title)
                    .font(Theme.Font.l1)
                    .foregroundStyle(Theme.Color.fg)
                HStack {
                    Spacer()
                    Button("完成") { closeWheel(commit: true) }
                        .font(Theme.Font.l2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Color.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { Theme.Color.border.frame(height: 1) }

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
        case .muscle:    return MuscleGroup.allCases.map(\.rawValue)
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

// MARK: - 动作选择器 Sheet（C 设计稿 Screen 9 · 计划/训练复用）

/// 选择器分组：个人置顶，其后按大肌群（顺序对齐设计稿）。
/// 既作分组键、ScrollView 定位锚点，也作右侧快捷索引项。
private enum PickerGroup: Hashable {
    case personal
    case muscle(MuscleGroup)

    /// 分组与右侧索引的固定顺序：个人 / 胸 / 背 / 腿 / 臀 / 肩 / 手臂 / 核心 / 全身。
    static let order: [PickerGroup] = [
        .personal,
        .muscle(.chest), .muscle(.back), .muscle(.legs), .muscle(.glutes),
        .muscle(.shoulders), .muscle(.arms), .muscle(.core), .muscle(.fullBody),
    ]

    /// 组头标题（朱砂红 mono）。
    var title: String {
        switch self {
        case .personal: return "个人"
        case .muscle(let m): return m.rawValue
        }
    }

    /// 右侧快捷索引单字（个人 = ★，多字肌群取代表字）。
    var indexLabel: String {
        switch self {
        case .personal: return "★"
        case .muscle(let m):
            switch m {
            case .arms:     return "臂"
            case .core:     return "核"
            case .fullBody: return "全"
            default:        return m.rawValue   // 胸/背/肩/腿/臀 本就单字
            }
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
struct ExercisePickerView: View {
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
        ZStack {
            Text("选择动作")
                .font(Theme.Font.display(size: 15, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            HStack {
                Button("取消") { dismiss() }
                    .font(Theme.Font.body(size: 14))
                    .foregroundStyle(Theme.Color.muted)
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)   // 让出系统 grabber，避免标题被挤压
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
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
                                             name: ex.name, primaryMuscle: ex.primaryMuscle))
            }
        if !personal.isEmpty { dict[.personal] = personal }

        for case let .muscle(m) in PickerGroup.order {
            let rows = BuiltinExercise.starter
                .filter { $0.primaryMuscle == m.rawValue && match($0.name) }
                .map { ex in
                    PickerRow(id: "b-\(ex.code)", name: ex.name,
                              muscle: ex.primaryMuscle, equipment: ex.equipmentType, isCustom: false,
                              pick: ExercisePick(builtinCode: ex.code, customId: nil,
                                                 name: ex.name, primaryMuscle: ex.primaryMuscle))
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

struct ExerciseDetailView: View {
    let exercise: BuiltinExercise
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workout> { $0.deletedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    /// 加入今日训练后导航进入的会话。
    @State private var startedSession: Workout?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    cover
                    title
                    tipsCard
                    musclesCard
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            joinCTA
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $startedSession) { WorkoutLoggingView(workout: $0) }
    }

    // 顶部 cover：斜条纹「采集中」占位图（部位高亮图素材尚未采集，design.md Non-Goals）。
    private var cover: some View {
        ZStack {
            Theme.Color.surface2
            // 斜条纹纹理
            Canvas { ctx, size in
                let spacing: CGFloat = 14
                let lineColor = Theme.Color.border2
                var x: CGFloat = -size.height
                while x <= size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    ctx.stroke(p, with: .color(lineColor), lineWidth: 1.5)
                    x += spacing
                }
            }
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Theme.Color.muted)
                Text("部位高亮图 · 采集中").eyebrowStyle()
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.Color.border, lineWidth: 1))
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(Theme.Font.display(size: 28, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            Text(exercise.code)
                .font(Theme.Font.mono(size: 13, weight: .regular))
                .foregroundStyle(Theme.Color.muted)
            Text("\(exercise.primaryMuscle) · \(exercise.equipmentType)")
                .eyebrowStyle()
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("FORM · 动作要点").eyebrowStyle()
            // BuiltinExercise 暂无 tip 字段（任务 3.1 数据工程未完成），统一占位。
            Text("暂无要点 · 数据采集中")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var musclesCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            muscleColumn(title: "PRIMARY · 主动肌", value: exercise.primaryMuscle)
            muscleColumn(title: "SYNERGISTS · 协同", value: "—")
        }
    }

    private func muscleColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).eyebrowStyle()
            Text(value)
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(value == "—" ? Theme.Color.muted : Theme.Color.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var joinCTA: some View {
        Button { addToTodayWorkout() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("加入今日训练")
            }
            .font(Theme.Font.body(size: 16, weight: .semibold))
            .foregroundStyle(Theme.Color.bg)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .paperShadow(.md, cornerRadius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 16)
    }

    /// 加入今日训练：经单一活跃会话守卫——存在进行中会话则追加动作（即「继续」），
    /// 否则新建唯一会话。随后导航进入 Live 记录界面。
    private func addToTodayWorkout() {
        let target = WorkoutSession.activeSession(in: modelContext) ?? {
            let w = Workout(title: "训练")
            modelContext.insert(w)
            return w
        }()
        let ex = WorkoutExercise(builtinExerciseCode: exercise.code,
                                 customExerciseId: nil,
                                 exerciseName: exercise.name,
                                 primaryMuscle: exercise.primaryMuscle,
                                 orderIndex: target.exercises.count)
        ex.sets = [WorkoutSet(setIndex: 0)]
        target.exercises.append(ex)
        target.markDirty()
        try? modelContext.save()
        startedSession = target
    }
}
