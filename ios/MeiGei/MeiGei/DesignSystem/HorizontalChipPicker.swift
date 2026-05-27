import SwiftUI

/// 横向滑动 chip 选择器。规范见 `design-system` spec 「横向 Chip 选择器组件」：
/// 单选；chip 高 32、横 padding 14、`Theme.Radius.pill` 圆角；
/// 选中 = accentCyan 填充 + bg 文字 + cyan glow sm；
/// 未选 = surface + 1pt border + fg2 文字。
struct HorizontalChipPicker<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item.ID
    let label: (Item) -> String

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
            if !isSelected {
                selection = item.id
            }
        } label: {
            Text(label(item))
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .foregroundStyle(isSelected ? Theme.Color.bg : Theme.Color.fg2)
                .background(
                    isSelected ? Theme.Color.accentCyan : Theme.Color.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                        .stroke(isSelected ? Color.clear : Theme.Color.border, lineWidth: 1)
                )
                .conditionalGlow(isSelected)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    @ViewBuilder
    func conditionalGlow(_ on: Bool) -> some View {
        if on {
            self.neonGlow(.cyan, intensity: .sm, cornerRadius: Theme.Radius.pill)
        } else {
            self
        }
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
            .preferredColorScheme(.dark)
        }
    }
    return Demo()
}
#endif
