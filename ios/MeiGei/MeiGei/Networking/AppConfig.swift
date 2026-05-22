import Foundation

/// 运行期配置。本地联调指向 brew 起的后端（localhost:8080）。
/// 注意：localhost http 需在 Info.plist 配 ATS `NSAllowsLocalNetworking`（联调任务 6.1 处理）。
enum AppConfig {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://localhost:8080")!
    /// 模拟器无法走真正的 Sign in with Apple，DEBUG 下允许用后端 dev token 造测试用户。
    static let devLoginEnabled = true
    #else
    static let apiBaseURL = URL(string: "https://api.meigei.app")!
    static let devLoginEnabled = false
    #endif

    /// APNs 环境标识，注册 device token 时上报。
    static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
