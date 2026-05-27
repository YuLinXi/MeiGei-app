## Context

设计稿 `ios/design-system/MeiGeiApp/index.html` 12 屏中，剩余 9 屏仍是 SwiftUI 默认 `List` / `Form` 浅灰风格，与已改造的训练核心三页（黑底 + 霓虹辉光 + JetBrainsMono 数字）视觉割裂。

可用基础：

- Theme token：`Theme.Color.{bg, surface, surface2, border, fg, fg2, muted, accentCyan, accentMagenta, danger, ok}`、`Theme.Font.{display, body, mono, numeric}`、`Theme.Spacing.*`、`Theme.Radius.*`。
- Modifier：`.cardStyle()`、`.neonGlow(.cyan / .magenta, .sm / .md / .lg)`、`.numStyle(_:weight:)`、`.eyebrowStyle()`。
- 数据层（不动）：`@Query` (SwiftData)、`WorkoutPlan.itemsJSON` (jsonb 字符串)、`TeamService` REST、`NutritionMath`、`SyncEngine`。

约束：

- iOS 17.4+，SwiftUI；不引入新的第三方库。
- 「严肃健身工具」定位，禁止使用 Apple SF Symbol 多彩 icon 或拟物渐变；图标统一 stroke 1.5pt outlined。
- Day-1 数据铁律不变（视觉改动不涉及数据建模）。

## Goals / Non-Goals

**Goals:**

- 9 屏全部从 List/Form 改造为 `ScrollView` + `LazyVStack` + `.cardStyle()` 自绘版式，与设计稿 1:1 对位（容差 ±2pt）。
- 输出 3 个新 spec 文件（`nutrition-ui` / `team-ui` / `profile-ui`）+ 2 个增量 spec（`design-system` / `workout-tracking`）。
- 全局消除 List 浅灰背景，所有 `List` / `Form` 替换为 ScrollView 或通过 `.scrollContentBackground(.hidden).background(Theme.Color.bg)` 强制黑底。
- 复用现有 Modifier，不在视图层出现 `Color(red:…)` 字面量。

**Non-Goals:**

- 不改动 SwiftData schema / 同步契约 / REST 端点。
- 不新增 Live Activity / Watch 端 UI。
- 不实现搜索 sheet 真实逻辑（只占位 UI，输入框点击 noop）。
- 不实现海报生成、不实现 Owner 模板新建流程（视觉占位 + 点击 noop）。
- 不打磨复杂转场动画（除已有 `.transition(.scale)` 之外）。

## Decisions

### D1：所有 9 屏统一用 `ScrollView { LazyVStack(spacing:) {} }` 而非 `List`

- **Why**：iOS `List` 强插入的 `UITableView` 背景与 separator inset 与设计稿不一致，配 `.scrollContentBackground` 仍残留浅灰；自绘 VStack + 手动 `Divider().background(Theme.Color.border)` 才能精准还原 1px 内分隔。
- **Alternative**：保留 `Form` 配 `.scrollContentBackground(.hidden)`。**否决** — Form 的 Section header padding 与设计稿的 `eyebrow`（10px / `Theme.Font.mono` / `muted` / letter-spacing 0.1em / uppercase）差距过大，且 Form row 高度无法精确控制。

### D2：`design-system` 新增「自绘 List 替代」规范

- 在 `design-system` spec 中追加 Requirement：**新视图 MUST NOT 使用 SwiftUI `List` / `Form` 作为顶层容器**；如必须使用（无障碍 / 滑动删除等），MUST 通过 `.scrollContentBackground(.hidden)` + `.background(Theme.Color.bg)` 隐藏默认背景。
- 增加 `HorizontalChipPicker` 组件：横向滚动 chip 选择器，48 高、`Theme.Spacing.sm` 间距、选中态用 `Theme.Color.accentCyan` 填充 + `Theme.Color.accentInk` 文字，未选中态用 `Theme.Color.surface` + `border`。

### D3：jsonb 计划详情解码策略

- `WorkoutPlan.itemsJSON` 是字符串形式的 JSON 数组；`PlanDetailView` 解码到本地结构 `PlanItemView`（含 `itemId / exerciseRef / sets / reps / rpe / restSec / supersetWith`）。
- 解码失败时显示「计划数据损坏，请重建」占位卡（不静默 crash），用 `Theme.Color.danger` 文字。
- **Why**：MyBatis 端写入的 jsonb 序列化稳定后，解码错误极少；占位卡兜底用户体验同时把问题暴露出来。

### D4：Team 动态卡 — 表情反应 4 个固定 emoji

- 设计稿示意 emoji：🔥 / 💪 / 😱 / 👏（取常用 4 个）。
- 反应按钮采用「emoji + 计数」chip 样式，计数为 0 时只显示 emoji 占位灰色，>0 时切到 `Theme.Color.surface2` 填充 + `fg` 文字。
- **Why**：`TeamService` 已支持 emoji 字段（任意字符串），UI 层只需固定 4 个常量并保持顺序稳定。

### D5：宏量进度环 (`MacroRingView`) 用 Swift Charts？

- **No** — Swift Charts 没有环形百分比组件。改用 `ZStack { Circle().trim(from:to:).stroke(...) }`，与 `RestTimerSheet` 的圆环一致，可直接复用样式常量。
- 进度色：热量 cyan / 蛋白 cyan / 碳水 `oklch(72% 0.16 195)` ≈ Theme.Color.accentCyan / 脂肪 `oklch(72% 0.18 35)` 新增一个 `Theme.Color.macroFat`（暖橙）。需要在 Assets 新增 1 个 colorset：`macroFat`。
- **Why**：设计稿 4 个宏量用不同色区分；不引入额外颜色 token 会导致碳水/脂肪同色。新增的 `macroFat` 严格只用于「饮食 - 脂肪进度条」语义，不外泄。

### D6：登录页 cyber 网格背景实现

- 用 `ZStack` + 4 层渐变：水平 / 垂直 1px 线网（`LinearGradient` repeat 40pt）+ 两个 `RadialGradient`（cyan @ 80% 20%、magenta @ 10% 90%）+ scanline（horizontal 2pt 间隔）。
- 因 SwiftUI `LinearGradient.repeat` 无法直接复制 CSS 行为，用 `Canvas` 自绘网格更可控（性能可接受，登录页只渲染一次）。
- **Why**：背景是设计灵魂，retro-cyber 调性必须保留；其他屏不需要这种背景，所以效果只局限于 `LoginView` 内部，不抽出 Modifier。

### D7：个人中心 = Settings 还是独立 ProfileView？

- 现状 `MainTabView.swift` 「我的」tab 当前指向哪？— 若已绑定 SettingsView 则直接在 Settings 里重做；若未实现就新建 `Profile/ProfileView.swift`，**首选后者**（语义更清晰：Profile 内含 Settings 入口）。
- 「我的」tab → `ProfileView` 顶层；底部 sec-list 各项点击进入二级页（个人信息 / 体重记录 / 训练目标 / HealthKit / 单位 / 通知），二级页本次仅做空架壳（NavigationLink + 「即将上线」占位），**不实现编辑**。
- 「退出登录」入口走 `SessionStore.signOut()`（已存在），点击后弹原生 confirm。

### D8：减少冗余 — 复用已有 `WorkoutWeeklyStats` 与 `OneRepMaxChart`

- HistoryView 顶部统计区直接调 `WorkoutWeeklyStats`（按 30 天窗口重新实例化）；月度训练量条形图改用 `Chart { BarMark }`（Swift Charts），数据按周聚合，最近一周用 magenta 高亮（设计稿语义=最新一柱 PR 色）。
- ExerciseLibraryView 中每个动作的 PR 副标走与 `OneRepMaxChart` 同源的 PR 计算函数（如尚未抽出，作为本次小重构：把 `WorkoutListView` 里 PR 计算抽到 `Workout/PRStats.swift`）。

## Risks / Trade-offs

- [自绘列表丢失系统手势] → ExerciseLibrary 与 Plan/Food 选择器无 swipe-to-delete；MVP 不需要（设计稿本身也无），后续若需要再回退到 List。
- [新增 colorset `macroFat`] → 偏离「只 11 个色板」承诺；权衡：宏量区分是产品语义刚需。在 `design-system` spec 追加「`macroFat` 仅可用于饮食脂肪类视觉」约束。
- [`WorkoutPlan.itemsJSON` 解码 schema 漂移] → 解码失败兜底占位卡，并在 OSLog 记录原始 payload 前 200 字符，方便定位。
- [Login cyber 背景 Canvas 性能] → 仅在 LoginView 渲染一次，不在导航栈深处，影响可忽略；如 iPhone XS 上掉帧再退化为静态 PNG（不在本次范围）。
- [Profile 二级页占位] → 用户点进去看到「即将上线」可能差评；用户告知 MVP 这一阶段会先消化主流程，二级页留到 6.x 真机联调后再补，本次不阻塞。

## Migration Plan

无数据迁移；纯 UI 改动。

部署：

1. 拉新分支 `feat/redesign-remaining-screens`。
2. 按 `tasks.md` 顺序逐屏改造，每屏改完跑 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
3. 全部完成后在模拟器 iPhone 17 Pro 截 9 张图，与 `ios/design-system/MeiGeiApp/index.html` 设计稿肉眼对比。
4. 合主分支前确认 `DesignSystemPreviewView` 内的 11 色板预览未受影响。

回滚：直接 revert 单个 commit；UI 改动天然可回滚，不影响数据。

## Open Questions

- ExerciseLibrary 中的 178 个动作目前数据未采集（属于 `meigei-mvp` 任务 3.1）。本次按「内置数据 0 条 + 自定义 N 条」组合渲染；当数据 0 条时显示「数据库尚未采集，请添加自定义动作」占位。是否接受？— 默认接受，不阻塞本次。
- Profile 二级页范围是否扩到 Apple 账户解绑？— 默认不做；解绑流程涉及后端 `identity_provider` 接口，留到独立 change。
