import SwiftUI

extension Theme {
    enum Color {
        // 表面层（纸感）：bg 纸白底 / surface 卡片白 / surface2 暖底 / border 主边框 / border2 次边框（虚线等）
        static let bg        = SwiftUI.Color("bg")
        static let surface   = SwiftUI.Color("surface")
        static let surface2  = SwiftUI.Color("surface2")
        static let border    = SwiftUI.Color("border")
        static let border2   = SwiftUI.Color("border2")

        // 文字
        static let fg        = SwiftUI.Color("fg")
        static let fg2       = SwiftUI.Color("fg2")
        static let muted     = SwiftUI.Color("muted")

        // 强调色（纸感极简：朱砂红单点强调，PR 与 CTA 共用）
        static let accent        = SwiftUI.Color("accent")
        /// 8% 朱砂红浅底（LIVE 横幅 / 选中浅底）。
        static let accentSoft    = SwiftUI.Color("accentSoft")
        /// 18% 朱砂红浅边。
        static let accentSofter  = SwiftUI.Color("accentSofter")

        // 状态
        static let danger    = SwiftUI.Color("danger")
        static let ok        = SwiftUI.Color("ok")
    }
}
