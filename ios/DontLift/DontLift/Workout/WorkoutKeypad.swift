import SwiftUI

// MARK: - 训练录入专用数字键盘（自研，替代系统 decimalPad/numberPad）

/// 训练进行中录入重量/次数的底部键盘。
/// 键位：`0-9` · `.` · `⌫` · `上一项` · `下一项` + 浮动「收起」。
/// 无「完成」键——组打卡仍由每行右侧勾选按钮承担，与键盘解耦。
struct WorkoutKeypad: View {
    /// 小数点是否可用：重量态 true、次数态 false（次数为整数，`.` 灰显无效）。
    var decimalEnabled: Bool
    var onDigit: (Int) -> Void
    var onDot: () -> Void
    var onBackspace: () -> Void
    var onPrev: () -> Void
    var onNext: () -> Void
    var onDismiss: () -> Void

    /// 单键高度；数字区 4 行、右侧导航键各跨 2 行，二者等高。
    private let keyH: CGFloat = 52
    private let gap: CGFloat = 8

    private var gridHeight: CGFloat { keyH * 4 + gap * 3 }
    private var navHeight: CGFloat { keyH * 2 + gap }

    var body: some View {
        VStack(spacing: 6) {
            dismissBar
            HStack(alignment: .top, spacing: gap) {
                numberGrid
                navColumn
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(alignment: .top) {
            Theme.Color.bg
                .overlay(Rectangle().fill(Theme.Color.border).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // 顶部「收起」浮条：右上角 chevron + 文案。
    private var dismissBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                    Text("收起").font(Theme.Font.body(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.Color.fg2)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.Color.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(KeyPressStyle())
            .accessibilityLabel("收起键盘")
        }
    }

    // 4×3 数字区，底排 `. 0 ⌫`（对齐系统 decimalPad 肌肉记忆）。
    private var numberGrid: some View {
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(1...3, id: \.self) { col in
                        let d = row * 3 + col
                        digitKey(d)
                    }
                }
            }
            HStack(spacing: gap) {
                dotKey
                digitKey(0)
                backspaceKey
            }
        }
        .frame(height: gridHeight)
    }

    // 右侧导航列：上一项 / 下一项，各跨 2 行高。
    private var navColumn: some View {
        VStack(spacing: gap) {
            navKey("上一项", systemImage: "chevron.up", action: onPrev)
            navKey("下一项", systemImage: "chevron.down", action: onNext)
        }
        .frame(width: 92, height: gridHeight)
    }

    // MARK: 键

    private func digitKey(_ d: Int) -> some View {
        Button { onDigit(d) } label: {
            Text("\(d)")
                .font(Theme.Font.number(size: 24, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .frame(maxWidth: .infinity).frame(height: keyH)
                .background(Theme.Color.surface, in: keyShape)
                .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("数字 \(d)")
    }

    private var dotKey: some View {
        Button { if decimalEnabled { onDot() } } label: {
            Text(".")
                .font(Theme.Font.number(size: 24, weight: .bold))
                .foregroundStyle(decimalEnabled ? Theme.Color.fg : Theme.Color.muted.opacity(0.4))
                .frame(maxWidth: .infinity).frame(height: keyH)
                .background(Theme.Color.surface.opacity(decimalEnabled ? 1 : 0.5), in: keyShape)
                .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .disabled(!decimalEnabled)
        .accessibilityLabel(decimalEnabled ? "小数点" : "小数点，当前不可用")
    }

    private var backspaceKey: some View {
        Button(action: onBackspace) {
            Image(systemName: "delete.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
                .frame(maxWidth: .infinity).frame(height: keyH)
                .background(Theme.Color.surface, in: keyShape)
                .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("删除")
    }

    private func navKey(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 16, weight: .bold))
                Text(title).font(Theme.Font.body(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.Color.fg2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Color.surface, in: keyShape)
            .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(title)
    }

    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }
}

/// 键按压反馈：按下时轻微缩放 + 降透明。
private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
