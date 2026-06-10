import Foundation
import AuthenticationServices

/// 串起 Apple 登录 → 后端换自有 JWT → 写会话。
@MainActor
final class AuthService: NSObject {
    private let session: SessionStore
    private var continuation: CheckedContinuation<Void, Error>?

    init(session: SessionStore) {
        self.session = session
    }

    /// 发起 Sign in with Apple。结果通过 delegate 回调驱动 continuation。
    func signInWithApple() async throws {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            controller.performRequests()
        }
    }

    /// 供 SwiftUI `SignInWithAppleButton.onCompletion` 调用：换 JWT + 写会话。
    func completeAppleLogin(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                throw APIError.http(status: -1, body: "Apple 凭证缺失")
            }
            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let auth: AuthResponse = try await APIClient.shared.send(
                "POST", "/auth/apple",
                body: AppleLoginRequest(identityToken: identityToken),
                authorized: false)
            session.handleLogin(auth, appleSub: credential.user,
                                email: credential.email,
                                displayName: displayName.isEmpty ? nil : displayName)
        }
    }

    /// DEBUG：模拟器无法走真 Apple 登录，用后端 dev token 造测试用户。
    func devSignIn() async throws {
        guard AppConfig.devLoginEnabled else { return }
        let auth: AuthResponse = try await APIClient.shared.send(
            "POST", "/auth/dev/token", authorized: false
        )
        session.handleLogin(auth, appleSub: "dev", email: "dev@dontlift.local", displayName: "Dev")
    }

    private func exchange(identityToken: String, email: String?, displayName: String?, appleSub: String?) {
        Task {
            do {
                let auth: AuthResponse = try await APIClient.shared.send(
                    "POST", "/auth/apple",
                    body: AppleLoginRequest(identityToken: identityToken),
                    authorized: false
                )
                session.handleLogin(auth, appleSub: appleSub, email: email, displayName: displayName)
                continuation?.resume()
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: APIError.http(status: -1, body: "Apple 凭证缺失"))
            continuation = nil
            return
        }
        let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        exchange(
            identityToken: identityToken,
            email: credential.email,
            displayName: displayName.isEmpty ? nil : displayName,
            appleSub: credential.user
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
