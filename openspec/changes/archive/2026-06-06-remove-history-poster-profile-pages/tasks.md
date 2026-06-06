## 1. 保护共享符号（先迁移，保证后续删除可编译）

- [x] 1.1 将 `WorkoutExercise.historyKey` 扩展从 `Workout/HistoryViews.swift` 迁移到 `Models/Workout.swift`（或新建 `Models/WorkoutExercise+HistoryKey.swift`），编译通过
- [x] 1.2 全局搜索 `newPRs(` / `PRStats.newPRs`，确认调用点仅 `TrainingHistoryView` 与 `ProfileView` 本月 PR 两处（删除前的依赖核对）
- [x] 1.3 全局搜索 `SharePosterSheet(` / `SharePosterView(`，确认入口仅训练完成页与 Team 打卡详情页两处

## 2. 移除历史模块

- [x] 2.1 删除 `Workout/WorkoutViews.swift` 训练首页工具栏左上角进入 `TrainingHistoryView` 的 NavigationLink 入口
- [x] 2.2 删除动作详情页进入单动作历史/1RM 曲线（`ExerciseHistoryChartView`）的入口
- [x] 2.3 删除文件 `Workout/HistoryViews.swift`（`TrainingHistoryView` / `WorkoutCalendarView` / `ExerciseHistoryChartView` 及私有组件 `HistoryChip`/`VolumeBar`/`CalendarGrid`）
- [x] 2.4 删除 `Workout/PRStats.swift` 中的 `newPRs()`；确认 `latestPR()` 及其依赖保留

## 3. 移除分享海报模块

- [x] 3.1 删除 `Workout/WorkoutViews.swift` 训练完成页「生成分享海报」Button 与 `.sheet(item: $sharingSummary)` 绑定（含 `sharingSummary` 状态）
- [x] 3.2 删除 `Team/TeamViews.swift` 打卡详情页 `CheckinDetailView` 的海报分享 Button 与 sheet 绑定（含其 `sharingSummary` 状态），保留 toolbar 其余项
- [x] 3.3 删除文件 `Workout/SharePoster.swift`（`SharePosterSheet` / `SharePosterView`）
- [x] 3.4 确认 `Team/CheckinSummary.swift`、Team 打卡上报与摘要展示链路不受影响（仅删海报消费方）

## 4. 移除「我的」二级页面与本月 PR 格

- [x] 4.1 删除 `Profile/ProfileView.swift` 中「个人信息」「单位」「通知」三个 `SetItemRow` 入口行
- [x] 4.2 删除 `Profile/ProfileView.swift` 中占位目标页 `PlaceholderDetailView` 定义
- [x] 4.3 将顶部三宫格改为 1×2（「总训练 / 最长连续」），移除「本月 PR」格及其 `PRStats.newPRs()` 调用，确认布局无空位
- [x] 4.4 确认「我的」主页其余部分（Profile Header、数据·同步组、退出登录）完整保留

## 5. 验证

- [x] 5.1 `xcodebuild -project MeiGei.xcodeproj -scheme MeiGei -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build` 编译通过
- [x] 5.2 目视核对：训练首页工具栏左右上角均无历史/搜索入口；训练完成页与 Team 打卡详情无海报按钮；「我的」页无三个二级入口、统计为 2 格
- [x] 5.3 回归核对：动作库列表 PR 副标（`latestPR()`）正常；Team 打卡上报、emoji 表情、同步链路正常
