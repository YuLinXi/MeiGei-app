import SwiftUI
import SwiftData

// MARK: - 首登资料补全（Screen 0B，C 纸感极简，对齐 meigei-c-onboarding-profile.html）

/// Apple 登录成功后强制前置：补全称呼（必填）+ 性别（默认男）才进 App。
/// 整屏纸白、顶部留白、一句话欢迎；称呼非法时主按钮灰态禁用；含提交中 / 失败可重试状态机。
struct ProfileCompletionView: View {
    @Environment(SessionStore.self) private var session
    @Query private var profiles: [UserProfile]

    @State private var name = ""
    @State private var sex: BodySex = .male
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var prefilled = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var nameValid: Bool { !trimmedName.isEmpty && trimmedName.count <= 20 }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            GeometryReader { viewport in
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
                .clipped()
            }
        }
        .preferredColorScheme(.light)
        .onAppear(perform: prefillIfNeeded)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            title
                .padding(.top, Theme.Spacing.md)
            subtitle
                .padding(.top, Theme.Spacing.sm)

            fields
                .padding(.top, 28)
                .disabled(submitting)

            Spacer(minLength: Theme.Spacing.lg)

            if submitting {
                submittingButton
            } else {
                ctaButton
            }
            if let errorMessage {
                failLine(errorMessage)
                    .padding(.top, Theme.Spacing.sm)
            }
            signOutLink
                .padding(.top, Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - 文案区

    private var eyebrow: some View {
        Text("NO. 0042 · 资料补全")
            .font(Theme.Font.mono(size: 12))
            .tracking(2)
            .foregroundStyle(Theme.Color.action)
    }

    private var title: some View {
        Text("来都来了，\n先认识一下。")
            .font(Theme.Font.display(size: 34, weight: .heavy))
            .tracking(-1)
            .foregroundStyle(Theme.Color.fg)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subtitle: some View {
        (Text("登录成功 · 补全后")
            + Text("开始记录训练").foregroundStyle(Theme.Color.fg))
            .font(Theme.Font.body(size: 14))
            .foregroundStyle(Theme.Color.fg2)
    }

    // MARK: - 采集字段

    private var fields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            nameField
            sexField
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("称呼")
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            TextField("请输入称呼", text: $name, prompt: Text("请输入称呼").foregroundColor(Theme.Color.muted))
                .focused($nameFocused)
                .font(Theme.Font.body(size: 16))
                .foregroundStyle(Theme.Color.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(nameFieldBorder, lineWidth: 1)
                )
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .accessibilityLabel("称呼")
            if !trimmedName.isEmpty && trimmedName.count > 20 {
                Text("称呼不超过 20 字")
                    .font(Theme.Font.mono(size: 11))
                    .foregroundStyle(Theme.Color.danger)
            }
        }
    }

    private var nameFieldBorder: Color {
        (!trimmedName.isEmpty && trimmedName.count > 20) ? Theme.Color.danger : Theme.Color.border2
    }

    private var sexField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("性别")
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            HStack(spacing: 6) {
                ForEach(BodySex.allCases) { s in
                    sexPill(s)
                }
            }
        }
    }

    private func sexPill(_ s: BodySex) -> some View {
        let selected = sex == s
        return Button {
            guard sex != s else { return }
            sex = s
            Theme.Haptics.selection()
        } label: {
            Text(s.displayName)
                .font(Theme.Font.body(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Theme.Color.fg2)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(minWidth: 72, minHeight: 44)
                .background(selected ? Theme.Color.action : Theme.Color.surface2, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.Color.border, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("性别：\(s.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 主按钮 / 状态机

    private var ctaButton: some View {
        Button { Task { await submit() } } label: {
            Text("开始训练")
                .font(Theme.Font.body(size: 16, weight: .bold))
                .foregroundStyle(nameValid ? Color.white : Theme.Color.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 52)
                .background(nameValid ? Theme.Color.action : Theme.Color.surface2,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(!nameValid)
    }

    private var submittingButton: some View {
        HStack(spacing: 9) {
            ProgressView().tint(.white)
            Text("提交中…")
                .font(Theme.Font.body(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .background(Theme.Color.action.opacity(0.9), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    /// 逃生出口：补全页是登录后的硬门，提供「退出登录 / 换账号」兜底——
    /// 防止异常态（如失效 token 被路由到此页、或想换 Apple 账号）被无出口困住。
    private var signOutLink: some View {
        Button {
            Theme.Haptics.selection()
            session.logout()
        } label: {
            Text("退出登录 / 换账号")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
                .underline()
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func failLine(_ message: String) -> some View {
        Text(message)
            .font(Theme.Font.mono(size: 11))
            .foregroundStyle(Theme.Color.danger)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - 逻辑

    /// 用 Apple 首登回传的全名（存于本地 UserProfile.displayName）预填称呼，仅一次。
    private func prefillIfNeeded() {
        guard !prefilled else { return }
        prefilled = true
        if let local = profiles.first(where: { $0.serverUserId == session.currentUserId })?.displayName,
           !local.trimmingCharacters(in: .whitespaces).isEmpty {
            name = local
        }
    }

    private func submit() async {
        guard nameValid, !submitting else { return }
        submitting = true
        defer { submitting = false }
        errorMessage = nil
        do {
            try await session.submitProfileCompletion(displayName: trimmedName, sex: sex)
            // 成功：RootView 监听 needsProfileCompletion == false 自动切到 MainTabView
        } catch {
            guard !error.isCancellationError else { return }
            errorMessage = (error as? APIError)?.errorDescription ?? "网络异常，资料未保存，请重试"
        }
    }
}
