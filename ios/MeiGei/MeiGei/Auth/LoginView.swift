import SwiftUI
import AuthenticationServices

// MARK: - 登录（Screen 0，C 纸感极简，对齐 meigei-c-login.html）

/// 全屏纸白底：顶部品牌（App Icon + 品牌名）→ 底部编号 + 反转主张大字 + tagline
/// + 黑底 Sign in with Apple + 合规链接 + 模拟器开发者入口。
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
                    .padding(.top, Theme.Spacing.md)
                Spacer(minLength: Theme.Spacing.lg)
                copyBlock
                Spacer(minLength: 26)
                appleButton
                legalSmallPrint
                    .padding(.top, Theme.Spacing.md)
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

    /// 品牌：App Icon 方块 + mono 小字距品牌名。
    /// 图标底色与纸白页面几乎同色，加 hairline 边框保证方块轮廓可读。
    private var brandMark: some View {
        HStack(spacing: 10) {
            Image("brandIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.Color.border, lineWidth: 1)
                )
            Text("别练了 · BIELIANLE")
                .font(Theme.Font.mono(size: 12))
                .tracking(1.8)
                .foregroundStyle(Theme.Color.muted)
        }
    }

    /// 编号 + 三行反转主张（「彦祖」朱砂红单点）+ tagline。
    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NO. 0001")
                .font(Theme.Font.mono(size: 12))
                .tracking(2)
                .foregroundStyle(Theme.Color.accent)
            (Text("别练了。\n再练就成\n")
                + Text("彦祖").foregroundStyle(Theme.Color.accent)
                + Text("了。"))
                .font(Theme.Font.display(size: 40, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(Theme.Color.fg)
                .padding(.top, Theme.Spacing.md)
            Text("我们只负责记录\n变帅变美这事儿\n全是你自己练的\n可不关我们事儿")
                .font(Theme.Font.body(size: 16))
                .foregroundStyle(Theme.Color.fg2)
                .lineSpacing(7)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appleButton: some View {
        ZStack {
            if loading {
                ProgressView()
                    .tint(.white)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
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
        .font(Theme.Font.body(size: 12))
        .foregroundStyle(Theme.Color.muted)
        .frame(maxWidth: .infinity)
    }

    /// 开发者登录：整行虚线框（仅 DEBUG/模拟器），mono 小字。
    private var devLoginButton: some View {
        Button { Task { await handleDev() } } label: {
            Text("⌥ 开发者登录（仅模拟器）")
                .font(Theme.Font.mono(size: 11))
                .foregroundStyle(Theme.Color.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(Theme.Color.border2, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
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
