import SwiftUI
import UIKit
import CoreText
import OSLog

extension Theme {
    enum Font {
        // PostScript 名（由 .ttf 决定，可在 Xcode 控制台用 UIFont.familyNames 验证）
        static let monoRegularPS = "JetBrainsMono-Regular"
        static let monoBoldPS    = "JetBrainsMono-Bold"

        // MARK: - C 设计稿字号语义层（数值对齐「纸感极简」设计稿）

        /// 品牌/特大标题 32pt。
        static var hero: SwiftUI.Font { display(size: 32, weight: .bold) }
        /// 屏幕级大标题 23pt。
        static var l1:   SwiftUI.Font { display(size: 23, weight: .bold) }
        /// 卡片标题/按钮文字 16pt（semibold）。
        static var l2:   SwiftUI.Font { display(size: 16, weight: .semibold) }
        /// 小标题/分类 15pt。
        static var l3:   SwiftUI.Font { display(size: 15, weight: .medium) }
        /// 正文/次级信息 13pt。
        static var l4:   SwiftUI.Font { body(size: 13) }
        /// 标签/说明 11pt。
        static var l5:   SwiftUI.Font { body(size: 11) }
        /// 计时器大数字 58pt（等宽 tabular）。
        static var timer: SwiftUI.Font { number(size: 58, weight: .bold) }

        /// 标题/数字大字：用 PingFang SC，按系统字体渲染（中文友好）。
        static func display(size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }

        /// 正文。
        static func body(size: CGFloat = 16, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }

        /// 等宽字。JetBrains Mono 缺失时自动 fallback 到系统等宽。
        static func mono(size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            if monoAvailable {
                let name = weight >= .semibold ? monoBoldPS : monoRegularPS
                return .custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .monospaced)
        }

        /// 等宽数字：mono + tabular figures。
        static func number(size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            mono(size: size, weight: weight).monospacedDigit()
        }

        // MARK: - 注册校验

        private static let log = Logger(subsystem: "com.yulinxi.app.MeiGei", category: "Font")
        private static var monoAvailable: Bool = false
        private static var verified = false

        /// 在 `MeiGeiApp.init()` 调用一次。优先靠 `INFOPLIST_KEY_UIAppFonts` 自动注册；
        /// 若 Bundle 内字体尚未注册（项目改用 synchronized group 时常见），用 CoreText 动态注册。
        /// 全部失败时 DEBUG 打 warning，Release 静默 fallback 到 `.system(.monospaced)`。
        static func verifyOrFallback() {
            guard !verified else { return }
            verified = true
            registerBundledFontsIfNeeded()
            let fonts = UIFont.fontNames(forFamilyName: "JetBrains Mono")
            monoAvailable = fonts.contains(monoRegularPS)
            #if DEBUG
            if !monoAvailable {
                log.warning("JetBrains Mono 未注册，等宽数字 fallback 到系统 .monospaced。已扫描到的字体: \(fonts)")
            }
            #endif
        }

        private static func registerBundledFontsIfNeeded() {
            for name in [monoRegularPS, monoBoldPS] {
                guard !UIFont.fontNames(forFamilyName: "JetBrains Mono").contains(name) else { continue }
                guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                    #if DEBUG
                    log.warning("字体资源缺失：\(name).ttf 不在 main bundle 中")
                    #endif
                    continue
                }
                var err: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) {
                    #if DEBUG
                    let e = err?.takeRetainedValue()
                    log.warning("CTFontManager 注册失败 \(name): \(String(describing: e))")
                    #endif
                }
            }
        }
    }
}

private func >= (lhs: SwiftUI.Font.Weight, rhs: SwiftUI.Font.Weight) -> Bool {
    func score(_ w: SwiftUI.Font.Weight) -> Int {
        switch w {
        case .ultraLight: return 100
        case .thin:       return 200
        case .light:      return 300
        case .regular:    return 400
        case .medium:     return 500
        case .semibold:   return 600
        case .bold:       return 700
        case .heavy:      return 800
        case .black:      return 900
        default:          return 400
        }
    }
    return score(lhs) >= score(rhs)
}
