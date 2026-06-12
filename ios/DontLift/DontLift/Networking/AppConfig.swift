import Foundation

/// 运行期配置。后端环境集中在这里切换：**只改 `current` 一个值，然后 Cmd+R 重跑**。
enum AppConfig {

    /// 后端环境。DEBUG 下手动切，RELEASE 强制走线上域名。
    enum Backend {
        /// 本机 Mac 后端（`./gradlew bootRun`，端口 8001）。模拟器联调用，需后端以 `APP_DEV_TOKEN=true` 启动。
        case localhost
        /// 腾讯云公网 IP 明文 HTTP（真机临时联调）。服务器 `APP_DEV_TOKEN=false`，须走真 Apple 登录。
        /// ⚠️ 已不可用：HTTPS 上线后 Info.plist 的 `NSAllowsArbitraryLoads` 已删（2026-06-11），
        /// 公网明文会被 ATS 拦截。真机联调直接用 `.production`。
        case serverIP
        /// 线上正式域名（HTTPS）。
        case production
    }

    // ⬇️⬇️⬇️ 切换环境只改这一行 ⬇️⬇️⬇️
    #if DEBUG
    static let current: Backend = .localhost
    #else
    static let current: Backend = .production
    #endif
    // ⬆️⬆️⬆️ 切换环境只改这一行 ⬆️⬆️⬆️

    /// 当前环境的后端基址。
    static var apiBaseURL: URL {
        switch current {
        case .localhost:  return URL(string: "http://localhost:8001")!
        case .serverIP:   return URL(string: "http://124.222.79.121:8080")!
        case .production: return URL(string: "https://dontlift.peipadada.com")!
        }
    }

    /// 是否启用后端 dev token 登录。仅本机后端（开了 `APP_DEV_TOKEN=true`）可用；
    /// 公网/线上 dev token 已关，必须走真正的 Sign in with Apple。
    static var devLoginEnabled: Bool {
        switch current {
        case .localhost:            return true
        case .serverIP, .production: return false
        }
    }

    /// APNs 环境标识，注册 device token 时上报。
    static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
