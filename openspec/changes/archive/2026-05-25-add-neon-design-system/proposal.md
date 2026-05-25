## Why

iOS 端当前使用 SwiftUI 系统默认外观（`List` / `Label(systemImage:)` / 系统色板），没有统一的 Design Tokens 层。`ios/design-system/MeiGeiApp/index.html` 已定稿「Neon Techwear」方向（纯黑深空底 + 电光青 + 霓虹品红 + 等宽数字 + 发光阴影），需要在 iOS 端落一个可复用的 Token 层和通用 ViewModifier，避免后续每张屏都各自硬编码颜色字面量。

## What Changes

- **强制深色**：App 顶层加 `.preferredColorScheme(.dark)`，移除浅色 fallback（产品定位决定，不做自适应）。
- **颜色 Token**：新增 `Asset Catalog` 颜色集（BG / Surface / Surface2 / Border / FG / FG2 / Muted / AccentCyan / AccentMagenta / Danger / OK），全部以设计稿 oklch 值的 sRGB 近似落地。Accent 仅用于 CTA 与单处数据高亮；Magenta 严格保留给 PR 庆祝。
- **字型 Token**：定义 `Theme.Font` 静态属性（display = PingFang SC，body/mono = SF Mono / JetBrains Mono），数字字段统一走 `.monospacedDigit()`。
- **间距与圆角 Token**：`Theme.Spacing`（4/8/14/22/32/44）、`Theme.Radius`（sm 8 / md 14 / lg 22 / pill 999）。
- **通用 Modifier**：
  - `.neonGlow(.cyan | .magenta, intensity:)` —— 发光阴影
  - `.cardStyle()` —— Surface + Border + Radius
  - `.eyebrowStyle()` —— 等宽小字 ALL CAPS + tracking
  - `.numStyle(size:)` —— 等宽数字
- **图标**：iOS 端继续用 SF Symbols（设计稿的线条 SVG 风格与 SF Symbols regular weight 吻合），不引第三方字体图标。
- **示例屏**：提供一个 `DesignSystemPreviewView`（仅 DEBUG 构建可见），用于回归 token 视觉。

## Non-goals（明确不做）

- **不做浅色主题**：设计稿仅深色，浅色不在 MVP 范围。
- **不做动态主题切换**：「我的」页里的"外观"项 MVP 锁死为「深色」，不做选择器。
- **不引入第三方 UI 框架**：纯 SwiftUI + Asset Catalog，不上 swiftui-introspect 等。
- **不做 Live Activity / Widget 端的 token 复用**：Widget Extension 独立配色（其设计稿尚未出），本次只覆盖主 App。
- **不替换 SF Symbols 为自定义图标**：等宽数字需要自定义字体，但图标继续用系统。
- **不做无障碍 Dynamic Type 全适配**：MVP 仅保证固定字号在 iPhone 15 Pro 标准字号下不溢出，更小/更大字号留到后续。

## Capabilities

### Modified Capabilities

无 capability spec 改动。本次仅落 iOS 端基础设施代码（`ios/MeiGei/MeiGei/DesignSystem/`），不涉及行为契约变更。

## Impact

- **新增目录**：`ios/MeiGei/MeiGei/DesignSystem/`（Theme.swift / Modifiers.swift / DesignSystemPreviewView.swift）。
- **新增字体资源**：JetBrains Mono Regular/Bold（OFL 1.1，可商用），通过 `INFOPLIST_KEY_UIAppFonts` 注入。
- **新增 Asset Catalog 颜色集**：约 11 个颜色集。
- **不破坏现有视图**：所有现存 View 不强制迁移，token 仅在「redesign-workout-core-screens」change 内使用；保留原始系统外观作为渐进迁移过渡。
- **包体增量**：JetBrains Mono ~200KB（subset 后），可接受。
