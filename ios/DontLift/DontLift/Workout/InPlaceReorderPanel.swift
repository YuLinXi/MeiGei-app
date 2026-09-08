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

/// 通用排序弹窗：以系统 `.sheet` 呈现（与「编辑动作」等弹层统一），原生支持下滑关闭；
/// 白底满幅内容，标题 + 实心「完成」胶囊 + 可拖拽行列表。
/// 训练进行中 / 计划详情 / 计划列表三处排序共用，保证交互与视觉完全一致。
///
/// 使用约定：
/// - 宿主用 `.sheet(isPresented:onDismiss:)` 呈现；排序期间页面被系统 scrim 封锁，无需自绘蒙层。
/// - 「完成」与下滑关闭统一走 sheet 的 `onDismiss` 提交草稿顺序（宿主把 onDone 设为关闭 sheet）。
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
        // 白底满幅：与 sheet 的 presentationBackground 同色，内容延伸到屏幕底缘。
        .background {
            Theme.Color.surface.ignoresSafeArea(edges: .bottom)
        }
        // 统一 sheet 呈现：默认 60% 高度、可上拉全屏，下滑关闭交给系统（门把手可见），与「编辑动作」等弹层一致。
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Color.surface)
        .presentationCornerRadius(26)
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
