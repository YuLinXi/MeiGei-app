# DesignSystem

DontLift iOS 的 Neon Techwear 视觉 token 层。视图代码 **禁止** 直接写 `Color(red:...)` 或 `Color.cyan`，统一从 `Theme.*` 取。

## 5 行示例

```swift
import SwiftUI

struct VolumeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("VOLUME").eyebrowStyle()
            Text("28,420 kg").numStyle(size: 28).foregroundStyle(Theme.Color.accentCyan)
            Text("本周总训练量").font(Theme.Font.body(size: 13)).foregroundStyle(Theme.Color.fg2)
        }
        .cardStyle()
        .neonGlow(.cyan, intensity: .sm)
    }
}
```

## Token 速查

- 颜色：`Theme.Color.{bg,surface,surface2,border,fg,fg2,muted,accentCyan,accentMagenta,danger,ok}`
- 字体：`Theme.Font.display(size:)` / `body(size:)` / `mono(size:)` / `number(size:)`
- 间距：`Theme.Spacing.{xs,sm,md,lg,xl,xxl}` = 4 / 8 / 14 / 22 / 32 / 44
- 圆角：`Theme.Radius.{sm,md,lg,pill}` = 8 / 14 / 22 / 999
- Modifier：`.cardStyle()` / `.eyebrowStyle()` / `.numStyle(size:)` / `.neonGlow(.cyan|.magenta, intensity:)`

## 红线

- `Theme.Color.accentMagenta` **仅** 用于 Personal Record 相关视觉（PR 卡边光/徽标/庆祝），非 PR 场景禁用，普通错误用 `danger`，普通高亮用 `accentCyan`。
- App 顶层已锁 `.preferredColorScheme(.dark)`，不再做浅色适配。
- 等宽字体走 JetBrains Mono（Bundle 内 ttf），缺失自动 fallback `.system(.monospaced)`，详见 `Theme+Font.swift` 的 `verifyOrFallback()`。

## 页面 Header / 导航栏

统一规范（见 OpenSpec change `unify-page-header`）。两套范式：

- **Tab 根页**（训练 / 计划 / 动作 / Team / 我的）：隐藏系统导航栏（`.toolbar(.hidden, for: .navigationBar)`）+ 自绘大标题 `Theme.Font.display(size: 36, weight: .heavy)` + `tracking(-1.08)`，左对齐，右上可挂 `CircleAddButton`。
- **子页**（push/sheet 二级及以上）：统一用 `.paperToolbar(title:onBack:trailing:)`，内部封装 `navigationBarBackButtonHidden` + iOS 26 双环处理（`sharedBackgroundVisibility(.hidden)`）+ 左返回 / 中标题（`Theme.Font.l2`）/ 右操作三槽位。

```swift
// 仅返回
.paperToolbar(title: "记录中", onBack: { dismiss() })
// 返回 + ⋯ 菜单
.paperToolbar(title: team.name, onBack: { dismiss() }) {
    CircleIconMenu(systemName: "ellipsis") { /* Menu items */ }
}
```

**圆形图标钮单一来源**：`CircleIconButton`（点击版）/ `CircleIconMenu`（Menu 版）共用 `CircleIconLabel` 外观。默认直径 **36**，图标字号按直径 ×0.42 推导（勿在调用点硬编码）。支持 `active`（accent 高亮）/ `rotated`（旋转 90°）。**禁止**在页面内本地复制等价圆钮实现。

## 纸感动作菜单

统一使用 `PaperMenuItem` + `CircleIconMenu` / `PaperActionMenuButton` 渲染，不在页面内自定义同类菜单行。菜单行规范集中在 `PaperActionMenuMetrics`：

- 行高 **52**，水平内边距 **14**，图标与文字间距 **10**。
- SF Symbol 图标 **15pt semibold**，固定占位宽 **20pt**。
- 菜单文字 **14pt semibold**。
- 普通项图标用 `Theme.Color.accent`、文字用 `Theme.Color.fg`；危险项图标和文字统一用 `Theme.Color.danger`。

## 色板刷新

设计稿微调时，修改 `scripts/oklch-to-srgb.mjs` 中的 `tokens` 表，运行：

```bash
node scripts/gen-colorsets.mjs    # 重写 Assets.xcassets/*.colorset/Contents.json
```

## DEBUG 预览

`SettingsView` 的「关于 → 版本」连续点 5 次进入 `DesignSystemPreviewView`，可视化回归色板/字阶/间距/Modifier。
