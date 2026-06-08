## Context

当前 iOS 实装是「Neon Design System」——`bg` 近黑 `srgb(0.010,0.018,0.030)`、`accentCyan` 青色 `srgb(0,0.844,0.850)`、`accentMagenta` 品红（PR 专用）、`neonGlow` 三层辉光、登录页赛博网格 + 双 radial。Open Design `MeiGeiApp2` 的 C「纸感极简」设计稿则是纸白底 `#f4f2ec` + 朱砂红 `#d9482b` 单点强调 + 柔和纸感阴影。两者方向完全相反。

幸运的是现有代码已高度集中化：颜色经 `Theme.Color.*`（指向 Asset Catalog colorset）、字体经 `Theme.Font.*`、间距/圆角经 `Theme.Spacing/Radius.*`、视觉质感经 `Modifiers`（`neonGlow`/`cardStyle`）、组件经 `HorizontalChipPicker`。视图层几乎不含颜色字面量（design-system spec「Theme Token 命名空间」要求强制）。因此**主题翻转可在 token 与修饰符层集中完成，视图引用基本不动**，再逐屏校准版式差异。

约束：iOS 17.4+、SwiftUI + SwiftData（纯表现层改造，不碰同步/业务逻辑/数据模型，故 Day-1 数据铁律本次不涉及新增数据对象）；工程用 `PBXFileSystemSynchronizedRootGroup`，新增 `.swift` 自动纳入 target；编译验证用 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。

## Goals / Non-Goals

**Goals:**
- 将 iOS UI 整体翻转到 C 设计稿，token 数值精确一致（颜色 hex、字号 px、圆角、阴影参数逐项对齐）。
- 视觉与交互对齐 18 屏设计稿；补齐现有实装尚缺的 PR 庆祝 Sheet、动作详情页、Team 计划 Fork 列表。
- 保持「视图不写颜色/字号字面量」的纪律，token 改值即全局生效，降低后续维护成本。

**Non-Goals:**
- 不做逐像素 diff 验收（以 token 精确 + 视觉对齐为准）。
- 不复刻原型设备外壳/状态栏/刻痕。
- 不采集部位高亮图（沿用「采集中」条纹占位）。
- 不引入浅/深色双主题切换（仅强制浅色）。
- 不改后端、同步协议、SwiftData 模型、业务逻辑。

## Decisions

### 1. 主题翻转在 Asset Catalog + 修饰符层集中完成
**选择**：直接改写既有 colorset 的 `components` 值（`bg`→纸白、`fg`→近黑、`surface`→白等），不删 colorset、不动视图引用。
**理由**：视图通过 `Theme.Color.bg` 间接引用 colorset，改值即全局翻转，零视图改动风险最低。
**备选**：新建一套 `paper*` colorset 并逐视图替换引用——改动面大、易漏、收益为零，弃用。

### 2. 强调色二元 → 单色朱砂红
**选择**：新增语义 token `Theme.Color.accent`（朱砂红 `#d9482b`）、`accentSoft`（`rgba(217,72,43,0.08)`）、`accentSofter`（`0.18`）。`accentCyan` 与 `accentMagenta` 两个旧 colorset **改值为同一朱砂红**并保留符号作为过渡别名，视图中逐步迁移到 `accent`；迁移完成后在收尾任务删除别名。
**理由**：设计稿强调色单一（PR 与 CTA 同为朱砂红），强行保留双色无依据；但一次性删除 `accentCyan`/`accentMagenta` 会触达大量视图，分两步走（先改值保符号、后清理）可让每步都能编译通过。
**权衡**：过渡期 `accentMagenta` 名义仍在但已非品红，有语义噪声 → 用收尾任务消除，并在 spec 标注 RENAMED。

### 3. `neonGlow` → `paperShadow`
**选择**：`Modifiers` 新增 `paperShadow(_ level:)`（对应设计稿 sh-sm/md/lg 三级，如 sh-md = `shadow(rgba(28,26,23,.09), radius 8, y 4)` + `0.5px` 描边近似）；`cardStyle()` 内部由 `neonGlow` 改调 `paperShadow(.sm)` + 1px `border` + 白底。`neonGlow` 保留为 no-op 兼容垫片直至视图迁移完毕，收尾删除。
**理由**：辉光与纸感是对立质感，必须换实现；保留签名让视图无需立即改。
**备选**：直接删 `neonGlow`——会让所有调用点编译失败，弃用。

### 4. 强制浅色外观
**选择**：顶层 `WindowGroup` 的 `.preferredColorScheme(.dark)` 改 `.light`；`UITabBarAppearance`/`UINavigationBarAppearance` 配色改纸感（背景纸白、分隔 `border`、tint `accent`）。colorset 维持 universal 单值（强制浅色，无需分明暗变体）。

### 5. 需自定义绘制的三处用原生方案
- **休息计时环**：`Circle().trim(from:to:).stroke(Theme.Color.accent, lineWidth:9)` + `TimelineView`（现 `RestTimerSheet` 已是此结构，仅改色 cyan→accent + 去 glow）。
- **首页本周趋势 sparkline**：引入 **Swift Charts**（`LineMark`），CLAUDE.md 技术栈已含、代码未用，本次首次引入。
- **动作详情条纹占位图**：`Canvas` 绘 `repeating` 斜条纹 + 中心「采集中」标签，不依赖未采集素材。

### 6. 新增三屏作为独立视图文件
PR 庆祝 Sheet、动作详情页、Team 计划 Fork 列表为现有实装缺口。新增 `.swift` 文件即自动纳入 target，无需改 pbxproj。

### 7. 验收方式
每个任务段以 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 编译通过为硬门槛；视觉以模拟器截图对照设计稿（人工核对 token 数值与版式），不做自动像素 diff。

## Risks / Trade-offs

- **[过渡期双色别名语义噪声]** `accentCyan`/`accentMagenta` 改值后名不副实 → 收尾任务统一改名为 `accent`/删除别名，spec 用 RENAMED 记录，避免长期遗留。
- **[视图层潜藏颜色字面量]** 若个别视图违反纪律直接写了 `Color.cyan` 之类，主题翻转会漏改 → 实施首步全局 grep `Color(` / `.cyan` / `.opacity` 硬编码颜色，建清单逐个收口。
- **[Swift Charts 首次引入]** 可能与现有最低版本/构建配置有摩擦 → iOS 17.4 已含 Charts，仅 `import Charts`，风险低；若 sparkline 表现不佳可降级为 `Canvas` 折线。
- **[纸感浅色下对比度/无障碍]** 浅底 + muted 灰文字可能不达 WCAG → 校准时核对正文 `#1c1a17`/次级 `#5e5950` 在纸白上的对比度，必要时微调 muted 档位。
- **[部位高亮图缺位]** 动作详情图仍是占位，与设计稿「最终态」有差距 → 已列 Non-goal 与软阻塞，占位条纹图保证不空窗。
- **[逐屏校准工作量]** 18 屏 + 3 新屏，单人推进耗时 → 任务按「token 层 → 跨屏组件 → 逐屏」分层，token 层完成即可见大面积翻转，收益前置。

## Migration Plan

1. **Token 层**（colorset 改值 + 字号语义层 + 圆角/阴影校准 + `paperShadow`）→ 编译，全局视觉即翻转为纸感。
2. **跨屏组件层**（`cardStyle`/`Chip`/Tab Bar/导航栏/按钮样式/Stepper/输入框）对齐。
3. **逐屏校准**（登录 → 首页 → 训练进行中 → 休息环 → 计划三屏 → 动作四屏 → Team 四屏 → 我的）。
4. **新增三屏**（PR Sheet / 动作详情 / Team 计划 Fork）。
5. **收尾**：删除 `neonGlow`/旧双色别名，grep 确认无残留赛博色，统一改名 `accent`。

回滚：纯表现层、无数据迁移，`git revert` 即可整体回退到霓虹版。

## Open Questions

- `accentMagenta`/`accentCyan` 是本次即彻底删除并改名 `accent`，还是保留别名到下个 change？（倾向本次收尾删除，已在 Decision 2 暂定）
- 首页 sparkline 用 Swift Charts 还是 `Canvas`？（倾向 Charts，留 Canvas 兜底）
