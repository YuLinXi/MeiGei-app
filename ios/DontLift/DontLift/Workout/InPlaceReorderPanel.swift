import SwiftUI

/// 排序行展示项：id + 标题 + 副标题 + 可选结构图标（递减组/超级组）。
struct ExerciseOrderItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let structureKind: WorkoutStructureIconKind?

    init(id: UUID, title: String, subtitle: String, structureKind: WorkoutStructureIconKind? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.structureKind = structureKind
    }
}

/// 排序模式蒙层：压暗并吞掉落在其上的一切手势（tap/drag/scroll 起点），下方内容不可操作。
/// 直接作为内容区块的 overlay 使用，随内容布局始终贴合目标区域。
/// `horizontalBleed`/`topBleed` 为出血量：区块自带水平/顶部内边距时传入同值，让蒙层视觉满幅。
extension View {
    func reorderMasked(_ active: Bool,
                       horizontalBleed: CGFloat = 0,
                       topBleed: CGFloat = 0) -> some View {
        overlay {
            if active {
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    .accessibilityHidden(true)
                    .padding(.horizontal, -horizontalBleed)
                    .padding(.top, -topBleed)
                    .transition(.opacity)
            }
        }
    }
}

/// 通用就地排序面板：白底满幅浮层（延伸到屏幕底缘），标题 + 实心「完成」胶囊 + 可拖拽行列表。
/// 训练进行中 / 计划详情 / 计划列表三处排序模式共用，保证交互与视觉完全一致。
///
/// 使用约定：
/// - 宿主在排序模式下用「顶部内容区（reorderMasked 压暗）+ 本面板」替换原列表布局，
///   不要用外层 ScrollView 包裹本面板（嵌套 List 的拖拽手势会被外层滚动抢走）。
/// - 行的水平留白收在行内容内部：拖拽快照只渲染行内容，行内自带留白才能让浮起行
///   与白底面板保持与静止态一致的间距。
struct InPlaceReorderPanel: View {
    /// 区段标题（如「训练动作」「分组」或目标分组名）。
    let title: String
    /// 按当前草稿顺序排列的展示项。
    let items: [ExerciseOrderItem]
    let onMove: (IndexSet, Int) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text(title)
                    .font(Theme.Font.body(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Color.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button(action: onDone) {
                    Label("完成", systemImage: "checkmark")
                        .font(Theme.Font.body(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Theme.Color.accent, in: Capsule())
                        .overlay(Capsule().stroke(Theme.Color.accent, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("完成排序")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            List {
                ForEach(items) { item in
                    reorderRow(item)
                        // 行内左侧留白：拖拽快照只渲染行内容，留白必须在内容内部，
                        // 浮起时卡片左侧与白底面板之间才有与静止态一致的间距。
                        .padding(.leading, Theme.Spacing.lg)
                        .listRowSeparator(.hidden)
                        // 行底色与排序区白底一致：拖拽浮起时不出现灰/米拼接色块。
                        .listRowBackground(Theme.Color.surface)
                        // trailing 留白：让系统拖拽手柄与卡片右边缘保持距离，不贴卡片。
                        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 28))
                }
                .onMove(perform: onMove)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .padding(.top, Theme.Spacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        // 白底浮层：满幅并延伸到屏幕底缘，遮住下方米色页面背景。
        .background {
            Theme.Color.surface.ignoresSafeArea(edges: .bottom)
        }
    }

    private func reorderRow(_ item: ExerciseOrderItem) -> some View {
        HStack(spacing: 10) {
            if let kind = item.structureKind {
                WorkoutStructureIcon(kind: kind)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(Theme.Font.l2)
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(Theme.Font.l4)
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Color.accentSofter, lineWidth: 1)
        )
        .paperShadow(.sm, cornerRadius: Theme.Radius.lg)
    }
}
