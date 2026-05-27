import SwiftUI
import AuthenticationServices

// MARK: - 登录（Screen 12，Neon 改版）

/// 全屏黑底 + cyber 网格 + 大标题 + Sign in with Apple。
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var authService: AuthService?
    @State private var errorMessage: String?
    @State private var loading = false

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            CyberGridBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                copyBlock
                Spacer().frame(height: 48)
                appleButton
                legalSmallPrint
                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.danger)
                        .padding(.top, Theme.Spacing.sm)
                }
                if AppConfig.devLoginEnabled {
                    Button("开发者登录（模拟器）") { Task { await handleDev() } }
                        .font(Theme.Font.mono(size: 11))
                        .foregroundStyle(Theme.Color.muted)
                        .padding(.top, Theme.Spacing.md)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .preferredColorScheme(.dark)
        .onAppear { if authService == nil { authService = AuthService(session: session) } }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 6) {
                Rectangle().fill(Theme.Color.accentCyan).frame(width: 18, height: 3)
                Rectangle().fill(Theme.Color.accentMagenta).frame(width: 18, height: 3)
                Rectangle().fill(Theme.Color.ok).frame(width: 18, height: 3)
            }
            Text("MEIGEI · NO.0001")
                .font(Theme.Font.mono(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.Color.muted)

            VStack(alignment: .leading, spacing: 6) {
                Text("认真训练。")
                    .font(Theme.Font.display(size: 36, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("严肃记录。")
                    .font(Theme.Font.display(size: 36, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("仅此而已。")
                    .font(Theme.Font.display(size: 36, weight: .bold))
                    .foregroundStyle(Theme.Color.accentCyan)
            }
            Text("一款不打鸡血、不发朋友圈的严肃健身工具。三个人就是一个小圈子。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
                .frame(maxWidth: 260, alignment: .leading)
        }
    }

    private var appleButton: some View {
        ZStack {
            if loading {
                ProgressView()
                    .tint(Theme.Color.fg)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Color.border, lineWidth: 1))
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private var legalSmallPrint: some View {
        HStack(spacing: 4) {
            Text("继续即代表同意")
            Button("服务条款") { /* 文档链接占位 */ }
                .foregroundStyle(Theme.Color.fg2)
            Text("与")
            Button("隐私政策") { /* 文档链接占位 */ }
                .foregroundStyle(Theme.Color.fg2)
        }
        .font(Theme.Font.mono(size: 10))
        .foregroundStyle(Theme.Color.muted)
        .padding(.top, Theme.Spacing.md)
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

// MARK: - Cyber 网格背景（仅登录页使用，不抽出 Modifier）

private struct CyberGridBackground: View {
    var body: some View {
        ZStack {
            // 1px 横竖网格
            Canvas { ctx, size in
                let spacing: CGFloat = 40
                let lineColor = Color.white.opacity(0.05)
                var x: CGFloat = 0
                while x <= size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(p, with: .color(lineColor), lineWidth: 1)
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(lineColor), lineWidth: 1)
                    y += spacing
                }
            }
            // 右上 cyan radial
            RadialGradient(
                colors: [Theme.Color.accentCyan.opacity(0.35), .clear],
                center: .init(x: 0.85, y: 0.18),
                startRadius: 0,
                endRadius: 320
            )
            // 左下 magenta radial
            RadialGradient(
                colors: [Theme.Color.accentMagenta.opacity(0.32), .clear],
                center: .init(x: 0.12, y: 0.88),
                startRadius: 0,
                endRadius: 320
            )
            // 横向 scanline
            Canvas { ctx, size in
                let spacing: CGFloat = 4
                let lineColor = Color.white.opacity(0.025)
                var y: CGFloat = 0
                while y <= size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(lineColor), lineWidth: 2)
                    y += spacing
                }
            }
            .blendMode(.plusLighter)
        }
    }
}
