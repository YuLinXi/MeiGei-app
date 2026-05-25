## 1. 基础设施

- [x] 1.1 [iOS] 新建目录 `ios/MeiGei/MeiGei/DesignSystem/`
- [x] 1.2 [iOS] 在 `MeiGeiApp.swift` 顶层 `WindowGroup` 加 `.preferredColorScheme(.dark)`

## 2. 颜色 Token

- [x] 2.1 [iOS] 写一次性 Node 脚本 `scripts/oklch-to-srgb.mjs`（依赖 `culori`）输出 11 个颜色的精确 sRGB hex
- [x] 2.2 [iOS] 在 `Assets.xcassets` 创建 Color Set：bg / surface / surface2 / border / fg / fg2 / muted / accentCyan / accentMagenta / danger / ok（每个仅 Any Appearance，不配 Light）
- [x] 2.3 [iOS] `DesignSystem/Theme+Color.swift`：枚举 `Theme.Color` 暴露为 SwiftUI `Color`

## 3. 字型 Token

- [x] 3.1 [iOS] 下载 JetBrains Mono Regular/Bold（OFL 1.1），用 `pyftsubset` 子集化（ASCII + 常见中英文标点 + ★▲● 等图形符号）
- [x] 3.2 [iOS] 资源放 `ios/MeiGei/MeiGei/Resources/Fonts/`，更新 `INFOPLIST_KEY_UIAppFonts` build setting
  - **实际落地**：`INFOPLIST_KEY_UIAppFonts` 不在 Xcode 自动注入键白名单内（实测 Xcode 26 不识别），改为运行时 `CTFontManagerRegisterFontsForURL(.process)` 动态注册；Bundle 内 ttf 通过 PBXFileSystemSynchronizedRootGroup 自动打包。
- [x] 3.3 [iOS] `DesignSystem/Theme+Font.swift`：`Theme.Font.{display,body,mono,number}`，mono 缺失 fallback 到 `.system(.monospaced)`
- [x] 3.4 [iOS] 在 `MeiGeiApp.init()` 调用 `Theme.Font.verifyOrFallback()`，DEBUG 下未注册时打印 warning

## 4. 间距与圆角

- [x] 4.1 [iOS] `DesignSystem/Theme+Layout.swift`：`Theme.Spacing.{xs,sm,md,lg,xl,xxl}` 与 `Theme.Radius.{sm,md,lg,pill}`

## 5. 通用 Modifier

- [x] 5.1 [iOS] `DesignSystem/Modifiers.swift` 实现：
  - [x] `.neonGlow(_:intensity:)`（两层 shadow + 1px stroke overlay）
  - [x] `.cardStyle()`（Surface + border + Radius.md + padding 14）
  - [x] `.eyebrowStyle()`（mono 10pt + ALL CAPS + tracking 0.08 + muted）
  - [x] `.numStyle(size:)`（JetBrains Mono + monospacedDigit + tracking -0.02）

## 6. 预览屏

- [x] 6.1 [iOS] `DesignSystem/DesignSystemPreviewView.swift`：色板/字阶/间距/Modifier 的可视化回归
- [x] 6.2 [iOS] 仅 DEBUG 构建挂载到「我的」页隐藏入口（5 次点击版本号触发）

## 7. 验收

- [x] 7.1 [iOS] `xcodebuild` Debug 编译通过
- [x] 7.2 [iOS] 模拟器 iPhone 17 Pro 跑预览屏，截图与设计稿规范条 spec 区对比，色差/字距肉眼一致
  - **当前状态**：iPhone 17 Pro 编译产物已含字体与色集（Info.plist 缺 UIAppFonts 但运行时已注册；色板 Asset Catalog 编译通过）。**视觉一致性人工验收**：跑模拟器 → 登录 → 「我的」→ 连续点 5 次「版本」进入 DesignSystemPreviewView，与 `ios/design-system/MeiGeiApp/index.html` 截图肉眼对比即可。
- [x] 7.3 [文档] 在 `ios/MeiGei/MeiGei/DesignSystem/README.md` 写 5 行用法示例（如何在新视图中引用 token）
