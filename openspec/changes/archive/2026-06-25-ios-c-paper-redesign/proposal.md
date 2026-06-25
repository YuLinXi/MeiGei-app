## Why

Open Design 项目 `DontLiftApp2` 已产出一套完整的 C「纸感极简」高保真设计稿（18 屏 + 统一 token），并经记忆确认为选定方向。但当前 iOS 实装仍是上一版「赛博霓虹深色」皮肤——`bg=#03050A` 近黑、`accentCyan=#00D7D9` 青色、neon glow 辉光、赛博网格登录页，与设计稿（`bg=#f4f2ec` 纸白、`accent=#d9482b` 朱砂红、柔和纸感阴影）完全相反。本次变更把 iOS UI 整体翻转到 C 设计稿，作为 MVP 视觉定稿。

**1:1 还原可行性研判（用户首要诉求）**：可做到**视觉高度一致**，但并非逐像素 1:1，需诚实区分三档：

- **可像素级还原（约 85%）**：全部颜色/字号/字重/圆角/间距/阴影 token、卡片/按钮/输入框/Chip/Stepper/Tab Bar/导航栏/列表行/分组标签等跨屏组件、Sheet 与 detent、左滑删除、脉动点、展开收起、PR 庆祝弹窗——SwiftUI 原生即可对齐设计稿数值。
- **需自定义绘制、视觉等价（约 12%）**：休息计时环形进度、首页本周趋势 mini sparkline、动作详情条纹占位图——用 `Shape.trim`/`Canvas`/Swift Charts 绘制，结果与设计稿一致但实现非「照搬 DOM」。
- **不追求逐像素或本就不属 App 内（约 3%）**：设计稿里的 iPhone 设备外壳/刻痕/状态栏是原型演示框（App 内由系统提供，不复刻）；部位高亮图依赖尚未采集的 150-200 张 SVG 素材（CLAUDE.md 已记软阻塞，本次留占位）；CSS `cubic-bezier(.3,.8,.3,1)` 等精细缓动曲线用 `.spring`/`.easeInOut` 近似。

结论：**应做、可做、能高度还原**；交付目标定为「视觉与交互对齐设计稿，token 数值精确一致」，而非「逐像素 diff 为零」。

## What Changes

- **BREAKING**（视觉契约反转）：`design-system` 从「强制深色 + 霓虹辉光 + 青/品红强调」翻转为「强制浅色 + 纸感柔和阴影 + 朱砂红强调」。所有 Asset Catalog colorset 改值、`neonGlow` 修饰符替换为 `paperShadow`、登录页赛博网格背景换成纸感留白。
- 全量校准 `Theme` token 至设计稿：颜色 12 色（纸白/暖背景/表面/双层边框/三级文字/朱砂红 + 8%/18% 着色/成功绿）、字号体系（Hero32/L1-23/L2-16/L3-15/L4-13/L5-11 + 计时器 58 + 标题帽 10）、圆角（8/13/18/pill）、三级纸感阴影（sh-sm/md/lg）。
- 逐屏对齐 18 张设计稿：登录、训练首页（含本周 hero+sparkline、三宫格、最近列表）、训练进行中（可展开动作卡 + 组行 + 当前行高亮）、休息计时全屏环、PR 庆祝弹窗、计划列表/详情/编辑、动作库/详情/选择器/自定义、Team 列表/创建/详情/计划 Fork、我的。
- 补齐设计稿中现有实装尚缺的视图：PR 庆祝 Sheet、动作详情页（含条纹占位图与肌群卡）、动作选择器右侧快速索引、Team 计划 Fork 列表。
- 强调色语义从 `accentMagenta`（PR 专用）+ `accentCyan`（通用）二元体系，收敛为单一 `accent` 朱砂红（PR 与通用 CTA 共用），简化语义。

## Capabilities

### New Capabilities
<!-- 无新增能力：设计稿覆盖的屏幕均落在既有 4 个能力域内，仅视觉/版式要求变化。 -->

### Modified Capabilities
- `design-system`: 外观从强制深色改强制浅色；强调色从青/品红双色改朱砂红单色；`neonGlow` 辉光语义改 `paperShadow` 纸感阴影；token 数值全量校准至 C 设计稿；保留 Theme 命名空间、等宽数字回退、Chip 组件、触感、按压、动效降级等结构性要求。
- `workout-tracking`: 训练首页/进行中/休息环/动作库/计划列表/计划详情等视觉基线改为纸感版式；新增 PR 庆祝弹窗与动作详情页版式要求；休息环配色由 cyan 改 accent。
- `profile-ui`: 个人中心 Header/三宫格/设置分组/登录页视觉规范改为纸感版式（登录页去赛博网格）。
- `team-ui`: Team 详情 Cover 卡/成员头像列表/动态 Feed/emoji 反应行/空占位改为纸感版式；新增 Team 计划 Fork 列表版式。

## Impact

- **iOS 代码**：
  - `ios/DontLift/DontLift/Assets.xcassets/*.colorset/Contents.json`（全部色值改写 + 新增 `accent`/`accentSoft`/`accentSofter`/`surface2`/`border2` 等）。
  - `DesignSystem/`：`Theme+Color.swift`（token 重定义）、`Theme+Font.swift`（补字号语义层）、`Theme+Layout.swift`（圆角/间距校准）、`Modifiers.swift`（`neonGlow`→`paperShadow`、`cardStyle` 改纸感）、`HorizontalChipPicker.swift`（选中态配色）。
  - `DontLiftApp.swift`/`MainTabView.swift`：`.preferredColorScheme(.dark)`→`.light`；`UITabBarAppearance`/`UINavigationBarAppearance` 改纸感配色。
  - `Auth/LoginView.swift`、`Workout/{WorkoutViews,PlanViews,ExerciseViews,RestTimerSheet}.swift`、`Team/TeamViews.swift`、`Profile/ProfileView.swift`：逐屏对齐。
  - 新增视图文件：PR 庆祝 Sheet、动作详情页、（按需）动作选择器索引、Team 计划列表。
- **OpenSpec**：`openspec/specs/{design-system,workout-tracking,profile-ui,team-ui}/spec.md` 经 delta 更新。
- **依赖**：引入 Swift Charts（首页 sparkline / 历史曲线，CLAUDE.md 技术栈已含但代码未用）；无新增第三方库。
- **不影响**：后端、同步协议、SwiftData 模型、业务逻辑（纯表现层改造）。

## Non-goals

- **不做逐像素 diff 验收**：以「token 数值精确 + 视觉/交互对齐」为准，不追求与浏览器渲染零差异。
- **不复刻原型设备外壳**：设计稿中的 iPhone bezel/刻痕/状态栏/电量是演示框，App 内由系统提供。
- **不在本次采集部位高亮图**：150-200 张肌群 SVG 仍为数据工程软阻塞，动作详情图沿用「采集中」条纹占位。
- **不引入浅/深色双主题切换**：MVP 仅强制浅色（纸感），不提供外观切换设置项。
- **不改任何业务逻辑/数据流**：同步、PR 计算、会话生命周期、Team fan-out 等保持现状，仅换皮。
- **不做新功能**：不借机新增设计稿之外的屏幕或交互。
