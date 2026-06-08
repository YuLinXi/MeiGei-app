import SwiftUI
import AuthenticationServices

// MARK: - 登录（Screen 0，C 纸感极简）

/// 全屏纸白底 + 品牌标识 + 大标题 + Sign in with Apple（黑色）。
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var authService: AuthService?
    @State private var errorMessage: String?
    @State private var loading = false

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                brandMark
                    .padding(.top, Theme.Spacing.lg)
                Spacer()
                copyBlock
                Spacer().frame(height: 40)
                appleButton
                legalSmallPrint
                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Font.l5)
                        .foregroundStyle(Theme.Color.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.sm)
                }
                if AppConfig.devLoginEnabled {
                    devLoginButton
                        .padding(.top, Theme.Spacing.md)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .preferredColorScheme(.light)
        .onAppear { if authService == nil { authService = AuthService(session: session) } }
    }

    /// 品牌：朱砂红 M 方块 + 大写字距「MEIGEI」。
    private var brandMark: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("M")
                .font(Theme.Font.display(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            Text("MEIGEI")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Theme.Color.fg2)
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("NO. 0001")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.Color.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("认真训练。")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Color.fg)
                Text("严肃记录。")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Color.fg)
                Text("仅此而已。")
                    .font(Theme.Font.hero)
                    .foregroundStyle(Theme.Color.fg)
            }
            Text("为认真练的人做的训练记录工具，\n和一个能互相看见的小圈子。")
                .font(Theme.Font.l3)
                .foregroundStyle(Theme.Color.fg2)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appleButton: some View {
        ZStack {
            if loading {
                ProgressView()
                    .tint(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    private var legalSmallPrint: some View {
        HStack(spacing: 6) {
            Button("服务条款") { /* 文档链接占位 */ }
                .foregroundStyle(Theme.Color.fg2)
            Text("·")
            Button("隐私政策") { /* 文档链接占位 */ }
                .foregroundStyle(Theme.Color.fg2)
        }
        .font(Theme.Font.l5)
        .foregroundStyle(Theme.Color.muted)
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.md)
    }

    /// 开发者登录：整行虚线胶囊（仅 DEBUG/模拟器）。
    private var devLoginButton: some View {
        Button { Task { await handleDev() } } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.left").font(.system(size: 11, weight: .semibold))
                Text("开发者登录（仅模拟器）")
            }
            .font(Theme.Font.l4)
            .foregroundStyle(Theme.Color.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.Color.border2, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        loading = true; defer { loading = false }
        errorMessage = nil
        do {
            try await authService?.completeAppleLogin(result)
            PushManager.shared.registerWithBackendIfReady()
        } catch is CancellationError {
            // 用户取消：不显示
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // Apple 取消：不显示
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleDev() async {
        loading = true; defer { loading = false }
        errorMessage = nil
        do {
            try await authService?.devSignIn()
            PushManager.shared.registerWithBackendIfReady()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
