import SwiftUI
import AuthenticationServices

/// 登录页：Sign in with Apple（唯一正式登录方式），DEBUG 下提供 dev 登录便于模拟器联调。
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var authService: AuthService?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("MeiGei")
                .font(.largeTitle.bold())
            Text("严肃健身工具")
                .foregroundStyle(.secondary)
            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal)

            if AppConfig.devLoginEnabled {
                Button("开发者登录（模拟器）") {
                    Task { await handleDev() }
                }
                .font(.footnote)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding()
        .onAppear { if authService == nil { authService = AuthService(session: session) } }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        do {
            try await authService?.completeAppleLogin(result)
            PushManager.shared.registerWithBackendIfReady()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleDev() async {
        do {
            try await authService?.devSignIn()
            PushManager.shared.registerWithBackendIfReady()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
