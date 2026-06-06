## Why

当前训练历史、分享海报、个人中心二级页（个人信息 / 单位 / 通知）三处功能要么是占位（COMING SOON）、要么实现深度不足，散落在多个文件里增加维护与认知负担。这三块各自值得后续单独立项聚焦设计，现阶段先从 App 中干净移除，收敛 MVP 表面积，让训练记录主链路与 Team 更聚焦。

## What Changes

- **移除「训练历史」模块**（独立历史页 + 单动作历史曲线）：
  - 删除独立历史页 `TrainingHistoryView`、训练日历 `WorkoutCalendarView`、月度训练量柱状图、「本月 PR」列表。
  - 删除训练首页左上角进入历史的工具栏入口。
  - **BREAKING**（spec 行为）：删除动作详情页的 **PR 卡 + 1RM 估算曲线**（单动作历史趋势 `ExerciseHistoryChartView` / 1RM 曲线）。
  - 删除仅服务历史/本月 PR 的统计逻辑 `PRStats.newPRs()`；**保留** `PRStats.latestPR()`（动作库列表 PR 副标仍依赖）。
  - 把被广泛复用的 `WorkoutExercise.historyKey` 扩展从 `HistoryViews.swift` **迁移**到 `Models/`，避免随文件删除而丢失。
- **移除「生成分享海报」模块**：
  - 删除 `SharePosterSheet` / `SharePosterView`（`SharePoster.swift`）。
  - 删除训练完成页、Team 打卡详情页两处「生成分享海报」入口按钮与 sheet 绑定。
  - **保留** `CheckinSummary`（Team 打卡 fan-out / 摘要展示仍依赖，仅去掉其海报渲染消费方）。
- **移除「我的」三个二级页面入口**：
  - 删除「个人信息」「单位」「通知」三个 `SetItemRow` 入口及其占位目标页 `PlaceholderDetailView`。
  - 顶部三宫格统计中的「本月 PR」格子一并移除（避免保留 `PRStats.newPRs()` 依赖）。
  - **保留**「我的」主页其余部分：Profile Header、其余统计格、数据·同步组（立即同步 / HealthKit / 导出）、退出登录。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `workout-tracking`: 删除「历史（History）版式」需求；删除「动作详情 PR 卡与 1RM 曲线」需求；调整「移除首页工具栏右上角入口」相关首页入口描述（去掉历史入口）。
- `profile-ui`: 修改「三宫格统计」需求（去掉「本月 PR」格）；修改「设置分组列表」需求（移除 个人信息 / 单位 / 通知 三项及其二级页，保留同步·数据组与退出登录）。

## Impact

- **iOS 代码**：
  - 删除文件：`Workout/HistoryViews.swift`、`Workout/SharePoster.swift`。
  - 修改：`Workout/WorkoutViews.swift`（历史入口 + 海报入口/sheet）、`Team/TeamViews.swift`（海报入口/sheet）、`Profile/ProfileView.swift`（三宫格本月 PR、三个二级入口、`PlaceholderDetailView`）、`Workout/PRStats.swift`（移除 `newPRs()`）。
  - 迁移：`WorkoutExercise.historyKey` 扩展 → `Models/Workout.swift`（或同目录新文件）。
- **保留不动**：`CheckinSummary`、`PRStats.latestPR()`、动作库列表 PR 副标、Team 打卡上报链路、HealthKit / 同步 / 退出登录。
- **后端**：无改动（历史/海报均为客户端本地计算与渲染，无独立后端接口）。
- **数据**：无数据库 schema 改动；`Workout` 聚合根及其同步保持不变（历史只是其只读视图，删的是展示层）。

## Non-goals

- 不重新设计或新增任何历史 / 海报 / 个人信息 / 单位 / 通知功能——三者均留待后续各自单独立项。
- 不改动训练记录的数据模型、同步逻辑、Team 打卡上报与 emoji 表情。
- 不删除 `CheckinSummary` 与 `PRStats.latestPR()`（仍被保留功能使用）。
- 不触碰后端任何接口与数据库表。
