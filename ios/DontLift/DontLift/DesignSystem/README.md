# DesignSystem

DontLift iOS 使用浅色 Paper 视觉：纸白背景、白卡与暖底、近黑正文、朱砂红强调。当前视觉以 `Theme+Color.swift`、`Theme+Font.swift`、`Theme+Layout.swift` 和实际颜色资源为准；App 顶层固定 `.preferredColorScheme(.light)`。

## 颜色与字体

- 表面：`Theme.Color.{bg,surface,surface2,border,border2}`。
- 正文：`Theme.Color.{fg,fg2,muted}`；`muted` 仍承载内容，须满足所在浅底的正文对比度。
- 品牌装饰：`accent`、`accentSoft`、`accentSofter`。操作文字和白字按钮使用深朱砂 `action`；错误用 `danger`，成功用 `ok`。颜色不能单独表达状态。
- 字体：`Theme.Font.display(size:weight:relativeTo:design:)`、`body`、`mono`、`number`，以及 `hero`、`l1`–`l5`、`timer` 语义 token。
- 字号传入默认阅读尺寸，由公共字体修饰符按角色和当前 Dynamic Type 环境缩放一次；不再叠加 `UIFontMetrics` 或 `@ScaledMetric` 预缩放。
- 等宽数据使用已注册的 JetBrains Mono；缺失时回退系统等宽，保留相同缩放规则。固定导出画布可固定字号，但预览操作和辅助功能摘要继续响应系统设置。

```swift
VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
    Text("本周训练量").font(Theme.Font.l3).foregroundStyle(Theme.Color.muted)
    Text("28,420 kg").font(Theme.Font.number(size: 28, weight: .bold))
        .foregroundStyle(Theme.Color.fg)
}
.cardStyle()
```

间距 `xs/sm/md/lg/xl/xxl` 为 4/8/14/22/32/44pt；圆角 `sm/md/lg/pill` 为 8/13/18/999pt。优先复用 token，避免在页面另建相同用途的颜色或组件。

## 导航与操作

- Tab 根页隐藏系统导航栏，保留现有自绘标题；子页使用 `.paperToolbar(title:onBack:trailing:)`。
- `CircleIconButton` 与 `CircleIconMenu` 共用 `CircleIconLabel`。默认视觉直径 36pt，实际目标至少 44pt；添加按钮视觉 42pt、实际目标 48pt。调用处提供明确操作名称。
- 动作菜单使用 `PaperMenuItem`、`CircleIconMenu` 或 `PaperActionMenuButton`。52pt 是行高下限，长文字和大字号可增高；受限高度时滚动，保留取消操作。
- 菜单基准水平内边距 14pt，图文间距 10pt，图标 15pt 并占位 20pt，文字 14pt；普通图标使用 `action`、正文使用 `fg`，危险项使用 `danger`。
- Sheet 使用 `PaperSheetHeader`；长标题或长操作随内容换行或纵排。短操作按钮最小 74×48pt，用实际呈现尺寸核对至少 44pt 触达。只读无操作标题可使用 `PaperSheetTitleHeader`。
- 原生 Button、Toggle 等控件优先保留原生角色。装饰图形可隐藏，名称、选中状态、数值、展开状态和默认动作需要可查询、可执行。

## 资源与验证

当前色板保存在 `Assets.xcassets/*.colorset/Contents.json`。`scripts/gen-colorsets.mjs` 和 `scripts/oklch-to-srgb.mjs` 仍为历史霓虹色板工具，不适用于当前 Paper 色板；不要用它们重写当前资源。若未来恢复自动生成，应先对齐当前 token 并以资源对比测试验证结果。

字体与颜色分别由 `ThemeTypographyTests`、`ThemeColorContrastTests` 定向验证；交互需在实际页面覆盖默认、XXXL 和辅助功能最大字号。编译、辅助功能树与截图各自只证明对应范围，不能替代真实 VoiceOver 或设备验收。

DEBUG 构建可在「我的 → 关于 → 版本」连续点击 5 次进入 `DesignSystemPreviewView`；该预览辅助观察，不作为全产品验收。
