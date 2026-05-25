## Why

MeiGei 的核心叙事是「认真训练 + 严肃记录」。`ios/design-system/MeiGeiApp/index.html` 已为训练相关 3 张主屏（训练首页 / 训练进行中 / 动作详情）出了高保真原型。当前 iOS 实现是功能性骨架（系统 List + 默认外观），需要先把这条主路径升级到设计稿的视觉强度与信息密度，让产品可以做真机演示与第一批用户邀请。其余 Tab（计划/饮食/Team/我的/动作库）暂时只继承新主题的颜色和字体，不重做布局，避免一次性铺 12 屏带来的数据缺口与工程波动。

## What Changes

- **训练首页（WorkoutListView）**：
  - 顶部新增「本周训练量」hero（大数字 + 同比 + 「已完成 X / Y 次」副标）。
  - 周统计三宫格：本周总组数 / 本周总次数 / 本周平均时长。
  - 最近训练列表升级为左侧日期块（号 + 周几）+ 右侧标题/动作组数时长 + PR 徽标。
  - 底部悬浮 CTA「开始今日训练」（accent cyan + 发光阴影）。
- **训练进行中（WorkoutSessionView）**：
  - 顶部「REC · 42:18」状态栏 + 暂停/结束按钮（结束按钮 danger 色）。
  - 「训练名 + 已完成组数/剩余/当前训练量」三联数。
  - 动作分组：完成态置灰 + 删除线 + ✓；当前组高亮 cyan 背景；未做组弱化。
  - 浮动圆环 FAB（屏幕右下）：休息倒计时进度环 + 剩余秒数；点击展开 RestTimerSheet。
  - RestTimerSheet（模态）：大圆环 + ±10s / 完成 / 最小化 + 下一组提示。
- **动作详情（ExerciseDetailView）**：
  - PR 卡片（magenta 边光 + 「★ Personal Record」+ 大数字「102.5 kg × 6」+ 较上次 PR 差值）。
  - 90 天 1RM 估算曲线（Swift Charts + cyan 渐变填充 + 终点高亮）。
  - 动作要点段（数据缺时显示「暂无要点」占位，不留空白区）。
  - 主动肌/协同 两栏卡片（数据缺时显示「—」）。
  - 底部 CTA「加入今日训练」。
- **基线视觉迁移**：其余视图（PlanListView / FoodDiaryView / TeamListView / SettingsView / ExerciseLibraryView 等）只做最小迁移——背景换 `Theme.Color.bg`、`List` 走 `.scrollContentBackground(.hidden)` + 黑底 cell，字体 navigation title 不动。**布局不重做**。
- **数据聚合补齐**：
  - 训练首页 hero/三宫格所需的「周训练量 / 周组数 / 周次数 / 周平均时长」走客户端实时计算（SwiftData query），不入库。
  - 1RM 估算用 Epley 公式 `weight * (1 + reps/30)`，按 `historyKey` 归并后取最近 90 天每日峰值。
  - 「较上次 PR」差值 = 本次 PR - 历史第二高 PR。
- **占位策略**：所有动态数据按真实值显示，无数据则显示 `—` 或「暂无」，不伪造示意数。新用户第一次进入训练首页若本周 0 训练，hero 显示「0.0 t」+「本周还没开始 · 现在开始第 1 次训练」。

## Non-goals（明确不做）

- **不改其它 Tab 布局**：计划/饮食/Team/我的/动作库本次只做主题色继承，不动信息架构。
- **不实现动作要点文案数据库**：动作详情的「动作要点」字段当下为空字符串展示「暂无要点」；专业文案采集留到内置动作库数据工程任务（tasks 3.1）。
- **不做部位高亮图**：动作详情顶部 hero 留 cover 占位（grayscale 渐变 + 部位文字标签），不画 SVG 人体。
- **不做 RPE / 休息秒数字段**：训练进行中按现有 `WorkoutSet` 模型展示重量/次数/完成，不引入新字段。
- **不做超级组（superset）渲染**：按现有 `WorkoutExercise` 顺序逐个铺；设计稿示例的「侧平举（超级组）」当作普通动作渲染。
- **不做训练首页的「同比 +12%」精确计算**：上周训练量需做存档对比，本次仅显示当周绝对值，副标改为「本周第 X 次训练」。等数据沉淀两周后再补 MoM。
- **不重做 Live Activity 视觉**：Widget Extension 的 lock screen / Dynamic Island UI 不改，本次仅改主 App 内的训练进行中页。
- **不做训练首页/动作详情的页面切换转场动画**：用 NavigationStack 默认 push。

## Capabilities

### Modified Capabilities

- `workout-tracking`: 新增对训练首页周聚合视图、训练进行中浮动休息圆环、动作详情 PR 卡与 1RM 曲线的明确行为要求；保留现有训练记录、休息计时、动作库 Requirement 不变。

## Impact

- **依赖**：本 change 依赖 `add-neon-design-system` change 已合入（token / modifier 可用）。
- **修改文件（不新建文件）**：
  - `ios/MeiGei/MeiGei/Workout/WorkoutViews.swift` (WorkoutListView / WorkoutSessionView 重写视图体)
  - `ios/MeiGei/MeiGei/Workout/ExerciseViews.swift` (ExerciseDetailView 重写视图体)
  - `ios/MeiGei/MeiGei/Workout/RestTimer.swift` (新增 RestTimerSheet 模态视图)
  - `ios/MeiGei/MeiGei/MainTabView.swift`（黑底 List 适配）
- **新增文件**：
  - `ios/MeiGei/MeiGei/Workout/WorkoutWeeklyStats.swift`（周聚合纯函数）
  - `ios/MeiGei/MeiGei/Workout/OneRepMaxChart.swift`（Swift Charts 封装）
- **数据契约**：无后端 API 变更；纯客户端聚合。
- **HealthKit / Live Activity**：行为不变。
- **回归风险**：训练进行中的休息计时核心逻辑不动（只新增一个展开/折叠的 Sheet 包装），回归面在视觉。
