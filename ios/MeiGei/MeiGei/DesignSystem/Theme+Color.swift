import SwiftUI

extension Theme {
    enum Color {
        // 表面层
        static let bg        = SwiftUI.Color("bg")
        static let surface   = SwiftUI.Color("surface")
        static let surface2  = SwiftUI.Color("surface2")
        static let border    = SwiftUI.Color("border")

        // 文字
        static let fg        = SwiftUI.Color("fg")
        static let fg2       = SwiftUI.Color("fg2")
        static let muted     = SwiftUI.Color("muted")

        // 强调色
        static let accentCyan    = SwiftUI.Color("accentCyan")
        /// 严格保留给 Personal Record 相关元素；非 PR 场景禁用。
        static let accentMagenta = SwiftUI.Color("accentMagenta")

        // 状态
        static let danger    = SwiftUI.Color("danger")
        static let ok        = SwiftUI.Color("ok")

        /// 严格保留给饮食「脂肪」语义；非脂肪场景禁用。
        static let macroFat  = SwiftUI.Color("macroFat")
    }
}
