import SwiftUI
import UIKit
import CoreText
import OSLog

extension Theme {
    enum Font {
        /// 基准尺寸和阅读角色；由统一修饰符根据当前环境缩放一次。
        struct Token {
            enum Family {
                case system(SwiftUI.Font.Design)
                case custom(String)
            }

            let size: CGFloat
            let weight: SwiftUI.Font.Weight
            let relativeTo: SwiftUI.Font.TextStyle
            var family: Family = .system(.default)
            var tabularDigits = false

            func monospacedDigit() -> Self {
                var copy = self
                copy.tabularDigits = true
                return copy
            }
        }

        // PostScript 名（由 .ttf 决定，可在 Xcode 控制台用 UIFont.familyNames 验证）
        static let monoRegularPS = "JetBrainsMono-Regular"
        static let monoBoldPS    = "JetBrainsMono-Bold"

        // MARK: - C 设计稿字号语义层（数值对齐「纸感极简」设计稿）

        /// 品牌/特大标题 32pt。
        static var hero: Token { display(size: 32, weight: .bold, relativeTo: .largeTitle) }
        /// 屏幕级大标题 23pt。
        static var l1:   Token { display(size: 23, weight: .bold) }
        /// 卡片标题/按钮文字 16pt（semibold）。
        static var l2:   Token { display(size: 16, weight: .semibold, relativeTo: .headline) }
        /// 小标题/分类 15pt。
        static var l3:   Token { display(size: 15, weight: .medium, relativeTo: .subheadline) }
        /// 正文/次级信息 13pt。
        static var l4:   Token { body(size: 13) }
        /// 标签/说明 11pt。
        static var l5:   Token { body(size: 11, relativeTo: .caption) }
        /// 计时器大数字 58pt（等宽 tabular）。
        static var timer: Token { number(size: 58, weight: .bold, relativeTo: .largeTitle) }

        /// 标题/数字大字：用 PingFang SC，按系统字体渲染（中文友好）。
        static func display(size: CGFloat, weight: SwiftUI.Font.Weight = .bold,
                            relativeTo: SwiftUI.Font.TextStyle = .title2,
                            design: SwiftUI.Font.Design = .default) -> Token {
            Token(size: size, weight: weight, relativeTo: relativeTo, family: .system(design))
        }

        /// 正文。
        static func body(size: CGFloat = 16, weight: SwiftUI.Font.Weight = .regular,
                         relativeTo: SwiftUI.Font.TextStyle = .body,
                         design: SwiftUI.Font.Design = .default) -> Token {
            Token(size: size, weight: weight, relativeTo: relativeTo, family: .system(design))
        }

        /// 等宽字。JetBrains Mono 缺失时自动 fallback 到系统等宽。
        static func mono(size: CGFloat, weight: SwiftUI.Font.Weight = .regular,
                         relativeTo: SwiftUI.Font.TextStyle = .caption) -> Token {
            if monoAvailable {
                let name = weight >= .semibold ? monoBoldPS : monoRegularPS
                return Token(size: size, weight: weight, relativeTo: relativeTo, family: .custom(name))
            }
            return Token(size: size, weight: weight, relativeTo: relativeTo, family: .system(.monospaced))
        }

        /// 等宽数字：mono + tabular figures。
        static func number(size: CGFloat, weight: SwiftUI.Font.Weight = .regular,
                           relativeTo: SwiftUI.Font.TextStyle = .body) -> Token {
            mono(size: size, weight: weight, relativeTo: relativeTo).monospacedDigit()
        }

        // MARK: - 注册校验

        private static let log = Logger(subsystem: "com.yulinxi.app.DontLift", category: "Font")
        private static var monoAvailable: Bool = false
        private static var verified = false

        /// 在 `DontLiftApp.init()` 调用一次。优先靠 `INFOPLIST_KEY_UIAppFonts` 自动注册；
        /// 若 Bundle 内字体尚未注册（项目改用 synchronized group 时常见），用 CoreText 动态注册。
        /// 全部失败时 DEBUG 打 warning，Release 静默 fallback 到 `.system(.monospaced)`。
        static func verifyOrFallback() {
            guard !verified else { return }
            verified = true
            registerBundledFontsIfNeeded()
            let fonts = UIFont.fontNames(forFamilyName: "JetBrains Mono")
            monoAvailable = fonts.contains(monoRegularPS) && fonts.contains(monoBoldPS)
            #if DEBUG
            if !monoAvailable {
                log.warning("JetBrains Mono 字体或字重未注册，等宽数字 fallback 到系统 .monospaced。已扫描到的字体: \(fonts)")
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

extension View {
    func font(_ token: Theme.Font.Token) -> some View {
        modifier(ThemeFontModifier(token: token))
    }
}

private struct ThemeFontModifier: ViewModifier {
    let token: Theme.Font.Token
    @ScaledMetric private var scaledSize: CGFloat

    init(token: Theme.Font.Token) {
        self.token = token
        _scaledSize = ScaledMetric(wrappedValue: token.size, relativeTo: token.relativeTo)
    }

    func body(content: Content) -> some View {
        let resolved: SwiftUI.Font
        switch token.family {
        case .system(let design):
            resolved = .system(size: scaledSize, weight: token.weight, design: design)
        case .custom(let name):
            // ScaledMetric 已按阅读角色缩放，custom 字体不能再次自动放大。
            resolved = .custom(name, fixedSize: scaledSize)
        }
        return content.font(token.tabularDigits ? resolved.monospacedDigit() : resolved)
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
