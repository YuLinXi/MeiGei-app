# DesignSystem

MeiGei iOS 的 Neon Techwear 视觉 token 层。视图代码 **禁止** 直接写 `Color(red:...)` 或 `Color.cyan`，统一从 `Theme.*` 取。

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

## 色板刷新

设计稿微调时，修改 `scripts/oklch-to-srgb.mjs` 中的 `tokens` 表，运行：

```bash
node scripts/gen-colorsets.mjs    # 重写 Assets.xcassets/*.colorset/Contents.json
```

## DEBUG 预览

`SettingsView` 的「关于 → 版本」连续点 5 次进入 `DesignSystemPreviewView`，可视化回归色板/字阶/间距/Modifier。
