import SwiftUI

/// 表单提交失败时保留草稿，原确认按钮继续承担重试操作。
struct LocalSaveErrorLabel: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(Theme.Font.l4)
                .foregroundStyle(Theme.Color.danger)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .accessibilityIdentifier("localSave.error")
        }
    }
}

/// 就地编辑的失败提示；用户仍能看到当前更改，并可明确重试本地保存。
struct LocalSaveRetryBanner: View {
    var message = "保存失败，当前更改仍保留。"
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(message)
                .font(Theme.Font.l4)
                .foregroundStyle(Theme.Color.fg)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("重试", action: onRetry)
                .font(Theme.Font.l3)
                .frame(minWidth: 60, minHeight: 44)
                .buttonStyle(.bordered)
                .tint(Theme.Color.fg)
                .accessibilityLabel("重试保存")
                .accessibilityIdentifier("localSave.retry")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Color.surface)
    }
}
