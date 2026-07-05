import SwiftUI

// MARK: - 训练录入专用数字键盘（自研，替代系统 decimalPad/numberPad）

/// 训练进行中录入重量/次数的底部键盘。
/// 键位：`0-9` · `.` · `⌫` · `上一项` · `下一项` · `加一组` + 右上角图标「收起」。
/// 无「完成」键——组打卡仍由每行右侧勾选按钮承担，与键盘解耦。
struct WorkoutKeypad: View {
    /// 小数点是否可用：重量态 true、次数态 false（次数为整数，`.` 灰显无效）。
    var decimalEnabled: Bool
    var onDigit: (Int) -> Void
    var onDot: () -> Void
    var onBackspace: () -> Void
    var onPrev: () -> Void
    var onNext: () -> Void
    /// 「加一组」：在当前动作追加一组待填写组并聚焦其重量（高频操作不离键盘）。
    var onAddSet: () -> Void
    var onDismiss: () -> Void

    /// 单键高度；数字区 4 行、右侧导航列三等分对齐其总高。
    private let keyH: CGFloat = 52
    private let gap: CGFloat = 8

    private var gridHeight: CGFloat { keyH * 4 + gap * 3 }

    var body: some View {
        // 「收起」按钮悬浮于面板上方（纸感底不覆盖它，二者留间隔）；
        // 收起时按钮快速渐隐、面板下滑，避免按钮随面板慢慢滑到底「抢戏」。
        VStack(spacing: 8) {
            dismissBar
                // 出现：随面板慢淡入（不突兀）；收起：快速淡出（不跟面板慢滑「抢戏」）。
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.3)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))))
            keypadPanel
                // 面板整体上下滑 + 淡入淡出；曲线继承父视图 focused 动画（与 inset 收起、内容回流同步），不单独覆盖。
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // 主键盘面板：数字区 + 导航列，纸感底 + 顶边 1px 细分隔线。
    private var keypadPanel: some View {
        HStack(alignment: .top, spacing: gap) {
            numberGrid
            navColumn
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

    // 顶部「收起」浮条：右上角苹果风「收键盘」图标按钮（键盘 + 向下箭头），悬浮于面板之上。
    private var dismissBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 40, height: 30)
                    .background(Theme.Color.surface, in: keyShape)
                    .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(KeyPressStyle())
            .accessibilityLabel("收起键盘")
        }
        .padding(.horizontal, Theme.Spacing.md)
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

    // 右侧导航列：上一项 / 下一项 / 加一组，三等分对齐数字区总高。
    private var navColumn: some View {
        VStack(spacing: gap) {
            navKey("上一项", systemImage: "chevron.up", action: onPrev)
            navKey("下一项", systemImage: "chevron.down", action: onNext)
            navKey("加一组", systemImage: "plus", action: onAddSet)
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

/// 表单数字键盘：用于计划/创建类表单中的重量、次数、组数输入。
/// 复用训练键盘的数字区视觉，但右侧动作为「上一项 / 下一项 / 完成」，避免带入训练中的「加一组」语义。
struct NumericFormKeypad: View {
    var decimalEnabled: Bool
    var onDigit: (Int) -> Void
    var onDot: () -> Void
    var onBackspace: () -> Void
    var onPrev: () -> Void
    var onNext: () -> Void
    var onDone: () -> Void

    private let keyH: CGFloat = 52
    private let gap: CGFloat = 8

    private var gridHeight: CGFloat { keyH * 4 + gap * 3 }

    var body: some View {
        VStack(spacing: 8) {
            dismissBar
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.3)),
                    removal: .opacity.animation(.easeOut(duration: 0.12))))
            keypadPanel
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var keypadPanel: some View {
        HStack(alignment: .top, spacing: gap) {
            numberGrid
            navColumn
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

    private var dismissBar: some View {
        HStack {
            Spacer()
            Button(action: onDone) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 40, height: 30)
                    .background(Theme.Color.surface, in: keyShape)
                    .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(KeyPressStyle())
            .accessibilityLabel("收起键盘")
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

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

    private var navColumn: some View {
        VStack(spacing: gap) {
            navKey("上一项", systemImage: "chevron.up", action: onPrev)
            navKey("下一项", systemImage: "chevron.down", action: onNext)
            navKey("完成", systemImage: "checkmark", action: onDone)
        }
        .frame(width: 92, height: gridHeight)
    }

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
        .accessibilityLabel(title == "完成" ? "完成输入" : title)
    }

    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }
}

/// 纯数字键盘：用于组间休息自定义秒数，只保留 0-9 和删除。
struct CompactNumberKeypad: View {
    var onDigit: (Int) -> Void
    var onBackspace: () -> Void

    private let keyH: CGFloat = 52
    private let gap: CGFloat = 8
    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }

    var body: some View {
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
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: keyH)
                digitKey(0)
                backspaceKey
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func digitKey(_ d: Int) -> some View {
        Button { onDigit(d) } label: {
            Text("\(d)")
                .font(Theme.Font.number(size: 24, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .frame(maxWidth: .infinity)
                .frame(height: keyH)
                .background(Theme.Color.surface, in: keyShape)
                .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("数字 \(d)")
    }

    private var backspaceKey: some View {
        Button(action: onBackspace) {
            Image(systemName: "delete.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
                .frame(maxWidth: .infinity)
                .frame(height: keyH)
                .background(Theme.Color.surface, in: keyShape)
                .overlay(keyShape.stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel("删除")
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
