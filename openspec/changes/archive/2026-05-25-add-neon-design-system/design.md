## 设计目标

为 MeiGei iOS 提供一套薄而稳的视觉基线，使后续屏改造（先是训练核心三屏，后续逐 tab 推进）只关心信息结构和数据，不再讨论颜色字面量与发光阴影参数。

## Token 层级

```
Theme
 ├── Color    (语义色，对应 Asset Catalog)
 │    ├── bg / surface / surface2 / border
 │    ├── fg / fg2 / muted
 │    ├── accentCyan / accentMagenta
 │    └── danger / ok
 ├── Font     (角色字型)
 │    ├── display(size:weight:)   // PingFang SC，标题/数字大字
 │    ├── body(size:)             // 正文
 │    ├── mono(size:weight:)      // 等宽，eyebrow / 数值
 │    └── number(size:)           // mono + monospacedDigit + tracking
 ├── Spacing  (Int 常量 4/8/14/22/32/44)
 └── Radius   (sm 8 / md 14 / lg 22 / pill .infinity)
```

**为什么不直接用 `Color.cyan`**：SwiftUI 系统色随 iOS 版本/外观调整，与设计稿 oklch 调好的对比度不一致；Asset Catalog 锁 sRGB 值最稳。

**为什么不引第三方 token 库（如 Stevia / TokenKit）**：MVP 体量小，~20 个常量自己维护更轻。

## 颜色映射

设计稿用 oklch，iOS Asset Catalog 不支持 oklch（直到 iOS 18+ 的 sRGB Display P3 也只是色域，不是色彩空间表达）。**落地策略**：用 oklch → sRGB 数值转换（设计稿 HTML 在浏览器里渲染的实际像素值）作为色板录入。差异肉眼不可辨；如设计稿微调，重新跑一次转换即可。

| Token | oklch (设计稿) | sRGB hex (落地) | 用途 |
|---|---|---|---|
| `bg` | oklch(11% 0.012 250) | #0E1116 | App 底色 |
| `surface` | oklch(18% 0.016 250) | #1B1F26 | 卡片 |
| `surface2` | oklch(23% 0.018 250) | #262B33 | 嵌套层 |
| `border` | oklch(30% 0.025 250) | #353B45 | 边线 |
| `fg` | oklch(97% 0.008 220) | #F4F6F8 | 主文本 |
| `fg2` | oklch(78% 0.015 220) | #BFC4CB | 次要文本 |
| `muted` | oklch(58% 0.018 250) | #818895 | 提示/eyebrow |
| `accentCyan` | oklch(78% 0.17 195) | #4FD6E2 | CTA / 实时态 |
| `accentMagenta` | oklch(68% 0.26 350) | #E55BA8 | PR 庆祝 **仅此一用** |
| `danger` | oklch(68% 0.24 25) | #EE6A55 | 结束训练 / 退出登录 |
| `ok` | oklch(78% 0.20 145) | #6BD78B | 已同步 / 完成态 |

具体 hex 在实现期用一次性 Node 脚本（`culori` 库）输出精确值；本文档先列示意值。

## 发光阴影实现

设计稿用三层叠加阴影：

```css
0 0 0.5px <color>,
0 0 12px <color>/.55,
0 0 32px <color>/.25
```

SwiftUI 等价：用 `.shadow(color:radius:)` 叠两次（更多层在 SwiftUI 里会卡，且首层 0.5px 的内描边 SwiftUI 没法做，改用 `.overlay(RoundedRectangle().stroke(.accent.opacity(0.6), lineWidth: 1))`）。

封装为：

```swift
extension View {
  func neonGlow(_ color: Theme.GlowColor, intensity: Theme.GlowIntensity = .medium) -> some View
}
```

intensity = sm（按钮）/ medium（卡片）/ lg（PR 庆祝爆光）。

## 等宽数字

设计稿大量使用「数字 tabular + 紧字距」，例如 `28.4t`、`102.5kg`、`00:36`。两条路：

**方案 A：内置 SF Mono**
- 不增包体；iOS 13+ 原生可用 `Font.system(.body, design: .monospaced)`
- 缺点：tracking 不如 JetBrains Mono 紧，字重选择少（只有 regular/medium/bold）

**方案 B：JetBrains Mono（OFL）**
- 紧字距更接近设计稿，等宽 0/O 区分清晰
- 缺点：~200KB 包体增量；要走 `INFOPLIST_KEY_UIAppFonts` 注册

**选择：B**。理由：设计稿等宽数字是核心视觉语言（训练量/PR/计时），值这 200KB。子集化只保留数字+常用 ASCII 可压到 ~60KB。

字体加载在 `MeiGeiApp.init` 里强制 `UIFont.familyNames` 检查存在，缺失则 fallback 到 SF Mono 而不崩溃。

## Day-1 铁律是否适用

本变更不触及数据模型、不涉及同步/幂等键/软删墓碑，**Day-1 铁律对本 change 不适用**——这是一次纯 iOS 表现层基础设施变更。

## 失败模式与回退

- **字体缺失** → 自动 fallback SF Mono（已封装在 `Theme.Font.mono` 中），不弹窗不崩溃。
- **颜色集缺失（资产编译失误）** → SwiftUI 报红色感叹号占位，DEBUG 期间立刻发现。
- **Token 命名冲突** → 全部走 `Theme.X.y` 命名空间，无全局污染。
