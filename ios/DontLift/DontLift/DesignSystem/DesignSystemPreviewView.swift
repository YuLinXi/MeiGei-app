import SwiftUI

/// 仅 DEBUG 构建可见。色板/字阶/间距/Modifier 的可视化回归。
struct DesignSystemPreviewView: View {
    @State private var chipSelection: String = "all"
    private let chipDemos: [PreviewChip] = [
        .init(id: "all", title: "全部"),
        .init(id: "chest", title: "胸"),
        .init(id: "back", title: "背"),
        .init(id: "leg", title: "腿"),
        .init(id: "shoulder", title: "肩"),
        .init(id: "arm", title: "手臂"),
        .init(id: "core", title: "核心"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                section("Colors") { colorSwatches }
                section("Typography") { typeStack }
                section("Spacing") { spacingScale }
                section("Modifiers") { modifierExamples }
                section("Horizontal Chip Picker") {
                    HorizontalChipPicker(items: chipDemos, selection: $chipSelection) { $0.title }
                        .padding(.horizontal, -Theme.Spacing.lg)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .foregroundStyle(Theme.Color.fg)
        .navigationTitle("Design System")
    }

    // MARK: - Sections

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title).eyebrowStyle()
            content()
        }
    }

    private var colorSwatches: some View {
        let items: [(String, Color)] = [
            ("bg", Theme.Color.bg),
            ("surface", Theme.Color.surface),
            ("surface2", Theme.Color.surface2),
            ("border", Theme.Color.border),
            ("fg", Theme.Color.fg),
            ("fg2", Theme.Color.fg2),
            ("muted", Theme.Color.muted),
            ("border2", Theme.Color.border2),
            ("accent", Theme.Color.accent),
            ("accentSoft", Theme.Color.accentSoft),
            ("accentSofter", Theme.Color.accentSofter),
            ("danger", Theme.Color.danger),
            ("ok", Theme.Color.ok),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
            ForEach(items, id: \.0) { name, color in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(color)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Color.border, lineWidth: 1)
                        )
                    Text(name).font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.fg2)
                }
            }
        }
    }

    private var typeStack: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Display 32").font(Theme.Font.display(size: 32))
            Text("Display 22").font(Theme.Font.display(size: 22))
            Text("Body 16 正文中文混排 abc 123").font(Theme.Font.body(size: 16))
            Text("Body 14").font(Theme.Font.body(size: 14)).foregroundStyle(Theme.Color.fg2)
            HStack(spacing: Theme.Spacing.lg) {
                Text("00:36").numStyle(size: 28)
                Text("102.5kg").numStyle(size: 28)
                Text("28.4t").numStyle(size: 28).foregroundStyle(Theme.Color.accent)
            }
            Text("EYEBROW · TINY MONO").eyebrowStyle()
        }
    }

    private var spacingScale: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach([
                ("xs", Theme.Spacing.xs),
                ("sm", Theme.Spacing.sm),
                ("md", Theme.Spacing.md),
                ("lg", Theme.Spacing.lg),
                ("xl", Theme.Spacing.xl),
                ("xxl", Theme.Spacing.xxl),
            ], id: \.0) { name, v in
                HStack {
                    Text(name).font(Theme.Font.mono(size: 11)).frame(width: 36, alignment: .leading)
                    Rectangle().fill(Theme.Color.accent).frame(width: v, height: 14)
                    Text("\(Int(v))").font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.muted)
                }
            }
        }
    }

    private var modifierExamples: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("VOLUME").eyebrowStyle()
                Text("28,420 kg").numStyle(size: 28)
                Text("本周总训练量").font(Theme.Font.body(size: 13)).foregroundStyle(Theme.Color.fg2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            HStack(spacing: Theme.Spacing.md) {
                Text("开始训练")
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .paperShadow(.sm)

                Text("PR + 5kg")
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .paperShadow(.lg)
            }
        }
    }
}

private struct PreviewChip: Identifiable, Hashable {
    let id: String
    let title: String
}

#if DEBUG
#Preview {
    NavigationStack { DesignSystemPreviewView() }
        .preferredColorScheme(.dark)
}
#endif
