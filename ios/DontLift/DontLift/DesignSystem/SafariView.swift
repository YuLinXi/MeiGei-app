import SafariServices
import SwiftUI

// MARK: - SFSafariViewController 的 SwiftUI 包装（登录页与我的页共用）

/// 在 App 内打开网页（隐私政策 / 服务条款），不离开 App。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(Theme.Color.accent)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// 可作 `.sheet(item:)` 标识的 URL 包装（URL 自身不满足 Identifiable）。
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

extension View {
    /// 以 sheet 形式弹出 `SafariView` 打开给定 URL；URL 为 nil 时不弹。
    func safariSheet(url: Binding<IdentifiableURL?>) -> some View {
        sheet(item: url) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
