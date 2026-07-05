import SwiftUI

enum WorkoutStructureIconKind: Equatable {
    case dropSet
    case superset

    var systemImage: String {
        switch self {
        case .dropSet: "square.stack.3d.down.forward"
        case .superset: "square.stack.3d.up"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .dropSet: "递减组"
        case .superset: "超级组"
        }
    }
}

struct WorkoutStructureIcon: View {
    let kind: WorkoutStructureIconKind
    var size: CGFloat = 24
    var symbolSize: CGFloat = 12

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: symbolSize, weight: .bold))
            .foregroundStyle(Theme.Color.accent)
            .frame(width: size, height: size)
            .background(Theme.Color.accentSoft, in: Capsule())
            .accessibilityLabel(kind.accessibilityLabel)
    }
}

/// 训练结构添加入口：递减组 / 超级组统一使用纸感下拉菜单。
struct WorkoutStructureMenuButton: View {
    var accessibilityLabel: String = "添加训练结构"
    let onAddDropSet: () -> Void
    let onAddSuperset: () -> Void

    private var menuItems: [PaperMenuItem] {
        [
            PaperMenuItem(id: "add-drop-set",
                          title: "递减组",
                          systemImage: "square.stack.3d.down.forward",
                          action: onAddDropSet),
            PaperMenuItem(id: "add-superset",
                          title: "超级组",
                          systemImage: "square.stack.3d.up",
                          action: onAddSuperset)
        ]
    }

    var body: some View {
        PaperActionMenuButton(items: menuItems,
                              accessibilityLabel: accessibilityLabel,
                              placement: .above) { isPresented in
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isPresented ? Theme.Color.accent : Theme.Color.muted)
                .frame(width: 46, height: 40)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(isPresented ? Theme.Color.accentSofter : Theme.Color.border,
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
    }
}
