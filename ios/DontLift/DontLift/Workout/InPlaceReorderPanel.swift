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

/// 四类宿主共用的排序草稿面板：取消丢弃，完成可靠保存后才关闭。
/// 宿主的 onDismiss 只清理草稿；保存抛错时面板保留草稿并展示重试说明。
struct InPlaceReorderPanel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var saveError: String?
    /// 区段标题（如「训练动作」「分组」或目标分组名）。
    let title: String
    /// 按当前草稿顺序排列的展示项。
    let items: [ExerciseOrderItem]
    let onMove: (IndexSet, Int) -> Void
    let onCancel: () -> Void
    let onDone: () throws -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(title: title, cancelTitle: "取消排序", confirmTitle: "完成排序",
                             onCancel: onCancel, onConfirm: submit)
            LocalSaveErrorLabel(message: saveError)
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
                .onMove { source, destination in
                    saveError = nil
                    onMove(source, destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        // 白底满幅：与 sheet 的 presentationBackground 同色，内容延伸到屏幕底缘。
        .background {
            Theme.Color.surface.ignoresSafeArea(edges: .bottom)
        }
        // 拖动排序与系统下滑关闭隔离；取消必须丢弃草稿，不能隐式提交。
        .presentationDetents(dynamicTypeSize >= .xxLarge ? [.large] : [.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Color.surface)
        .presentationCornerRadius(26)
        .interactiveDismissDisabled()
        .accessibilityAction(.escape, onCancel)
    }

    private func submit() {
        do {
            try onDone()
            saveError = nil
        } catch {
            saveError = "排序保存失败，草稿仍保留。请重试或取消。"
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
                    .lineLimit(dynamicTypeSize >= .xxLarge ? nil : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(Theme.Font.l4)
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(dynamicTypeSize >= .xxLarge ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Color.accentSofter, lineWidth: 1)
        )
        .paperShadow(.sm, cornerRadius: Theme.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue([item.structureKind?.accessibilityLabel, item.subtitle.isEmpty ? nil : item.subtitle]
            .compactMap { $0 }.joined(separator: "，"))
    }
}
