## Context

三块功能要移除，均为**纯客户端展示/渲染层**，无后端接口与数据库依赖：

- **历史模块**：`Workout/HistoryViews.swift`，含 `TrainingHistoryView`（独立历史页：时间窗 chip + 月度训练量柱状图 + 本月 PR 列表）、`WorkoutCalendarView`（训练日历）、`ExerciseHistoryChartView`（单动作 1RM/历史曲线）。入口：训练首页 `WorkoutViews.swift` 工具栏左上角 NavigationLink，以及动作详情页进入单动作曲线。
- **分享海报**：`Workout/SharePoster.swift`，含 `SharePosterSheet` + `SharePosterView`（`ImageRenderer` 渲染 + `ShareLink`）。入口：训练完成页（`WorkoutViews.swift`）与 Team 打卡详情页（`TeamViews.swift`）。
- **个人中心二级页**：`Profile/ProfileView.swift` 中三个 `SetItemRow`（个人信息 / 单位 / 通知）指向占位页 `PlaceholderDetailView`，以及顶部三宫格的「本月 PR」格。

关键耦合约束（决定删除不能一刀切）：
- `WorkoutExercise.historyKey` 扩展**定义在** `HistoryViews.swift`，却被动作库、`PRStats.latestPR()`、PersonalRecord 等**广泛复用**——随文件删除会编译失败。
- `PRStats` 双重身份：`newPRs()` 仅服务历史 + 本月 PR（随本次删除）；`latestPR()` 服务动作库列表 PR 副标（保留）。
- `CheckinSummary` 既被海报消费，也被 Team 打卡上报/摘要展示消费——只删海报消费方，类型本身保留。

## Goals / Non-Goals

**Goals:**
- 干净移除三块展示层代码，删后工程可正常编译、训练主链路与 Team 打卡不受影响。
- 移除连带的死代码（`newPRs()`、`PlaceholderDetailView`），不留悬空入口。
- 保护被复用的共享符号（`historyKey`、`latestPR()`、`CheckinSummary`），通过迁移而非删除。

**Non-Goals:**
- 不重设计/不替换被删功能（各自后续单独立项）。
- 不改后端、数据库 schema、`Workout` 同步聚合与 Team 上报链路。

## Decisions

- **`historyKey` 迁移而非删除**：把 `extension WorkoutExercise { var historyKey: ... }` 从 `HistoryViews.swift` 移到 `Models/Workout.swift`（或同目录新建 `WorkoutExercise+HistoryKey.swift`）。
  - 备选：保留 `HistoryViews.swift` 仅留扩展——否决，文件名与内容名实不符，且历史视图整删更清爽。
- **`PRStats` 拆分式清理**：仅删 `newPRs()`，保留 `latestPR()` 及其依赖。先全局搜索 `newPRs(` 确认调用点只剩历史页与 ProfileView 本月 PR 两处，删除后无悬空引用。
- **`CheckinSummary` 保留**：只删除其海报渲染消费方（`SharePosterView` 引用），`init(workout:)`、Team 解析路径不动。删 `SharePoster.swift` 后全局搜索 `SharePosterSheet(` 确保入口已清空。
- **ProfileView 局部编辑而非整删**：`ProfileView` 主体保留；删三个 `SetItemRow` + `PlaceholderDetailView` 定义 + 三宫格「本月 PR」格（连带其 `newPRs()` 调用）。三宫格改为 2 格或以另一现成统计补位（按 spec 决定，见 specs 增量）。
- **入口先删、文件后删**：先去掉所有入口（NavigationLink / Button / sheet），再删孤立文件，避免中途编译态出现引用悬空。

## Risks / Trade-offs

- [删 `HistoryViews.swift` 误伤 `historyKey` 复用方] → 先迁移扩展并编译通过，再删原文件；删除后跑 `xcodebuild` 验证。
- [`newPRs()` 仍有未知调用点] → 删前全局 grep `newPRs(`、`PRStats.newPRs`，确认仅两处。
- [三宫格删「本月 PR」后布局塌陷] → 由 `profile-ui` spec 明确改为 2 格布局，避免空位/越界。
- [Team 打卡详情删海报按钮影响 toolbar 布局] → 仅删该按钮，保留其余 toolbar 项；编译 + 目视 Team 详情页。

## Migration Plan

1. 迁移 `historyKey` 扩展到 `Models/`，编译通过。
2. 删除历史入口（首页工具栏 NavigationLink、动作详情单动作曲线入口）。
3. 删除海报入口（训练完成页 Button+sheet、Team 打卡详情 Button+sheet）。
4. 删除 Profile 三个二级入口 + `PlaceholderDetailView` + 三宫格本月 PR 格。
5. 删除孤立文件 `HistoryViews.swift`、`SharePoster.swift`；删除 `PRStats.newPRs()`。
6. `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 验证编译。
- **回滚**：本次为展示层删除，纯 git revert 即可恢复，无数据迁移、无后端发布。

## Open Questions

- 三宫格删「本月 PR」后是补一格新统计还是收为 2 格？倾向**收为 2 格**（最小改动），最终以 `profile-ui` spec 增量为准。
