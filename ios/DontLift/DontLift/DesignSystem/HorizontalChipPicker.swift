import SwiftUI

/// 横向滑动 chip 选择器。规范见 `design-system` spec 「横向 Chip 选择器组件」：
/// 单选；chip 默认视觉高 32、实际触达至少 44，随阅读字号增长；
/// 选中 = action 深朱砂实底 + 白字（无辉光）；
/// 未选 = surface 白底 + 1pt border + fg2 文字。
struct HorizontalChipPicker<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item.ID
    let label: (Item) -> String
    /// 重复点击当前已激活 chip 时回调（selection 不变，故 onChange 不触发，用于「回顶」等场景）。
    var onReselect: ((Item.ID) -> Void)? = nil

    init(items: [Item], selection: Binding<Item.ID>,
         onReselect: ((Item.ID) -> Void)? = nil, label: @escaping (Item) -> String) {
        self.items = items
        self._selection = selection
        self.onReselect = onReselect
        self.label = label
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { item in
                    chip(for: item)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    @ViewBuilder
    private func chip(for item: Item) -> some View {
        let isSelected = selection == item.id
        Button {
            if isSelected {
                onReselect?(item.id)
            } else {
                selection = item.id
            }
        } label: {
            Text(label(item))
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: 32)
                .fixedSize(horizontal: true, vertical: true)
                .foregroundStyle(isSelected ? Color.white : Theme.Color.fg2)
                .background(
                    isSelected ? Theme.Color.action : Theme.Color.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                        .stroke(isSelected ? Color.clear : Theme.Color.border, lineWidth: 1)
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}

#if DEBUG
private struct _PreviewChip: Identifiable, Hashable {
    let id: String
    let title: String
}

#Preview {
    struct Demo: View {
        @State var sel = "all"
        let items = [
            _PreviewChip(id: "all", title: "全部"),
            _PreviewChip(id: "chest", title: "胸"),
            _PreviewChip(id: "back", title: "背"),
            _PreviewChip(id: "leg", title: "腿"),
            _PreviewChip(id: "shoulder", title: "肩"),
            _PreviewChip(id: "arm", title: "手臂"),
            _PreviewChip(id: "core", title: "核心"),
        ]
        var body: some View {
            VStack {
                HorizontalChipPicker(items: items, selection: $sel) { $0.title }
                Spacer()
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Color.bg)
            .preferredColorScheme(.light)
        }
    }
    return Demo()
}
#endif
