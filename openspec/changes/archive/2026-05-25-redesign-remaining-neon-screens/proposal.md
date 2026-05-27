## Why

Neon Design System 已落地（`add-neon-design-system`），训练核心三页（列表 / 进行中 / 休息计时）也已按设计稿 `ios/design-system/MeiGeiApp/index.html` 改造完成（`redesign-workout-core-screens`）。但设计稿一共有 **12 屏**，目前仍有 **9 屏**未按高保真原型还原：

- screen-04 动作库（Exercise Library）
- screen-05 计划列表（Plan List）
- screen-06 计划详情（Plan Detail）
- screen-07 饮食日记（Food Diary）
- screen-08 食材选择器（Food Picker）
- screen-09 Team 动态流（Team Feed）
- screen-10 历史/日历（History）
- screen-11 个人中心（Profile / Settings）
- screen-12 登录（Login）

这些页目前仍是 SwiftUI 默认浅灰外观（List/Form 风格），与已改造的训练页风格断层严重，视觉上无法成为统一的「严肃健身工具」MVP，影响真机联调 6.x 前的体验完整度。

## What Changes

- 将设计稿中 9 屏的版式、间距、卡片结构、霓虹辉光、品红 PR 语义等映射到现有 SwiftUI 视图。
- 全部使用 `Theme.*` token 与已有 Modifier（`.cardStyle / .neonGlow / .numStyle / .eyebrowStyle`），**不新增**颜色字面量。
- 仅做视觉与版式还原，**不改动数据模型、同步契约、API**；既有 `@Query` / `TeamService` / `NutritionMath` 等数据流维持原样。
- 动作库与食材选择器引入「搜索 + 部位/分组横向 chip + 卡片网格/列表」的统一壳；计划详情引入 `jsonb` 解码后的「动作项 → 组数 reps 区间」展示卡。
- 饮食日记顶部三联宏量进度环 + 餐次分段；食材选择器支持「最近 / 收藏 / 复制昨天」三入口（数据层已存在，仅做 UI 还原）。
- Team 动态流改造为「打卡卡片 + 4 emoji 反应行 + Owner 模板入口」；个人中心改造为「头像 + 周训练里程碑 + 设置分组」。
- 登录页改造为「Logo 大字 + 副标 + Sign in with Apple 黑底白字 + 法务小字」。

**Non-goals（本次明确不做）：**

- 不新增任何业务功能（不接搜索 sheet、不做新的同步实体、不做新的 REST 端点）。
- 不做 widget / Live Activity / Watch 端的设计还原（不在原型 12 屏范围内）。
- 不做内置动作的部位高亮 SVG、不做食材数据采集（属于 `meigei-mvp` 任务 3.1/4.1）。
- 不做骨架屏、不做 SwiftUI 转场动画的精细打磨（除原型明确标注的展开/折叠之外）。
- 不动 `WorkoutListView / WorkoutSessionView / RestTimerSheet`（上一个 change 已完成）。

## Capabilities

### New Capabilities

- `nutrition-ui`：饮食日记与食材选择器的版式、配色、宏量进度环、餐次分段、搜索/收藏/复制昨天入口的呈现规范。
- `team-ui`：Team 动态流、打卡卡片、4 emoji 反应、Owner 模板入口的呈现规范。
- `profile-ui`：个人中心 / 设置页 / 登录页（Sign in with Apple）的呈现规范。

### Modified Capabilities

- `design-system`：补充「全局 List/Form 背景必须为 `Theme.Color.bg`、不允许 iOS 默认浅灰 GroupedListBackground」与「横向 chip 选择器规范」两条要求。
- `workout-tracking`：补充动作库（Exercise Library）、计划列表、计划详情、历史/日历四屏的视觉与版式要求（行为不变）。

## Impact

- 受影响 Swift 代码：
  - `Workout/PlanViews.swift`、`Workout/HistoryViews.swift`、`Workout/WorkoutViews.swift` 中的 ExerciseLibrary 子视图
  - `Nutrition/FoodDiaryView.swift`、`Nutrition/FoodPickerViews.swift`、`Nutrition/NutritionGoalViews.swift`、`Nutrition/NutritionProgressView.swift`
  - `Team/TeamViews.swift`
  - `Auth/LoginView.swift`
  - `App/` 下个人中心 / Settings 入口（若不存在则在 `MainTabView.swift` 的「我的」tab 下新建 `Profile/ProfileView.swift`）
- 不影响：`Models/*`、`Networking/*`、`Sync/*`、`Persistence/*`、`Push/*`、`Team/TeamService.swift`、所有后端代码。
- 资源：复用已存在的 11 个 colorset + JetBrainsMono；不新增图片、不新增字体。
- 测试：纯 UI 改动，沿用现有单元测试；新增 SwiftUI Preview 覆盖 9 屏。
- 验证：`xcodebuild -scheme MeiGei -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` 必须通过。
