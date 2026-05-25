## 1. 前置依赖

- [x] 1.1 [iOS] 确认 `add-neon-design-system` change 已合入，`Theme.*` 与 `.neonGlow / .cardStyle / .numStyle / .eyebrowStyle` Modifier 可用

## 2. 周聚合纯函数

- [x] 2.1 [iOS] 新建 `Workout/WorkoutWeeklyStats.swift`：输入 `[Workout]` + reference date，输出 `WeeklyStats(volumeKg, sessionCount, setCount, repCount, avgDurationSec)`
- [x] 2.2 [iOS] 「本周」定义：取本地时区当周周一 00:00 到次周一 00:00（与设计稿"本周"语义一致）
- [x] 2.3 [iOS] 单元测试覆盖：跨周边界 / 空集 / 单次训练 / 多次训练加权平均时长

## 3. 训练首页（WorkoutListView）

- [x] 3.1 [iOS] 用 `@Query` 拉本周 + 历史 `[Workout]`（按 startedAt 倒序）
- [x] 3.2 [iOS] 顶部 Hero：本周训练量大数字（`.numStyle(56)` + cyan 发光），副标「已完成 X / Y 次」（Y 为用户当前激活计划的每周训练次数，无激活计划时副标改为「本周第 X 次训练」）
- [x] 3.3 [iOS] 三宫格：总组数 / 总次数 / 平均时长，三栏等分 + 1px 内分隔
- [x] 3.4 [iOS] 最近训练列表项：左日期块（`b 05` + `周四`）+ 右标题/动作组数时长 + 命中 PR 时显示 `▲ <动作> PR <重量>` magenta 文字
- [x] 3.5 [iOS] 悬浮 CTA「开始今日训练」：底部固定，黄道 90pt（tab bar 之上），`.neonGlow(.cyan, .medium)`
- [x] 3.6 [iOS] Empty state：本周 0 训练时 hero 改为「准备好了吗？」+ CTA「开始第 1 次训练」
- [x] 3.7 [iOS] 顶部导航 right items：搜索图标 + 加号图标（先占位，搜索 sheet 留到后续 change）

## 4. 训练进行中（WorkoutSessionView）

- [x] 4.1 [iOS] 顶部 `LiveHeaderView` 子组件：「REC · MM:SS」（脉冲红点 + mono 字体）+ 暂停/结束按钮（结束 = danger 圆角方块）
- [x] 4.2 [iOS] 三联数：已完成组 / 剩余动作 / 当前训练量（kg·rep 累加）
- [x] 4.3 [iOS] 动作分组卡：完成态置灰删除线 + ✓ cyan 圆环；当前组高亮 cyan 半透明背景 + cyan 数字；未做组弱化（`Theme.Color.muted`）
- [x] 4.4 [iOS] 浮动圆环 FAB：`Circle().trim` 进度环 + 中心 mono 数字 `MM:SS`；点击 `withAnimation(.spring()) { isRestExpanded.toggle() }`
- [x] 4.5 [iOS] FAB 与 RestTimer 现有 `endDate` 绑定（已是墙钟基准）；剩余秒数走 `TimelineView(.periodic(1s))` 不靠手动 Timer
- [x] 4.6 [iOS] 当 `restRemaining <= 0` 时 FAB 隐藏（淡出）

## 5. 休息计时弹窗（RestTimerSheet）

- [x] 5.1 [iOS] 新建 `Workout/RestTimerSheet.swift`：`if isRestExpanded` 时 ZStack overlay 在 WorkoutSessionView 之上
- [x] 5.2 [iOS] 背景：`.background(.bg.opacity(0.92)).background(.ultraThinMaterial)`，点击空白处不关闭（设计稿明确「最小化」按钮才折叠）
- [x] 5.3 [iOS] 弹窗内容：顶部 pill「手机震动」「最小化」+ 「REST · 休息计时」eyebrow + 大圆环（170×170 + cyan 发光）+ ±10s / 完成 三按钮 + 「下一组：动作名 · 第 N 组」提示
- [x] 5.4 [iOS] ±10s 按钮调整 `endDate ± 10s`；完成按钮立即将 `restRemaining = 0` 并触发 haptic
- [x] 5.5 [iOS] 转场：`.transition(.scale(scale: 0.92).combined(with: .opacity))`

## 6. 动作详情（ExerciseDetailView）

- [x] 6.1 [iOS] 顶部 cover：`LinearGradient` surface→bg + 部位文字 eyebrow（不画 SVG 人体）
- [x] 6.2 [iOS] 标题区：display 28 中文名 + mono 13 英文副名 + eyebrow「复合 · 推 · 杠铃」
- [x] 6.3 [iOS] PR 卡组件：magenta 边光 + 左侧 3px magenta 竖条 + 「★ Personal Record」eyebrow + 大数字（display 32）+「2026-05-05 · 较上次 PR +2.5kg」
- [x] 6.4 [iOS] PR 数据源：复用现有 `PersonalRecord.swift` 的 historyKey 归并逻辑；差值 = 当前 PR - 历史第二高 PR；无 PR 时整张卡隐藏
- [x] 6.5 [iOS] 新建 `Workout/OneRepMaxChart.swift`：90 天 1RM Epley 估算 + Swift Charts 折线 + cyan area 渐变 + 终点圆点；数据 < 3 时显示「数据不足 · 至少需要 3 次记录」
- [x] 6.6 [iOS] 动作要点段：读 `BuiltinExercise.tip` 字段（数据缺时显示「暂无要点 · 数据采集中」），不留空白
- [x] 6.7 [iOS] 主动肌/协同两栏卡：`primaryMuscles` / `synergists`（缺值显示「—」）
- [x] 6.8 [iOS] 底部悬浮 CTA「加入今日训练」

## 7. 其它 Tab 视觉迁移（最小动作）

- [x] 7.1 [iOS] `MainTabView` 整体 `.tint(Theme.Color.accentCyan)` + `UITabBar.appearance()` 黑底配置
- [x] 7.2 [iOS] 所有 `NavigationStack` 顶层加 `.toolbarBackground(Theme.Color.bg, for: .navigationBar)` + `.toolbarColorScheme(.dark, for: .navigationBar)`
- [x] 7.3 [iOS] `PlanListView` / `FoodDiaryView` / `TeamListView` / `SettingsView` / `ExerciseLibraryView` 的根 `List` 改为 `.scrollContentBackground(.hidden).background(Theme.Color.bg)`，cell 背景 `.listRowBackground(Theme.Color.surface)`
- [x] 7.4 [iOS] 不重做这些视图的布局；目标仅"不刺眼"，验收口径：与新主题色调和即可

## 8. 验收

- [x] 8.1 [iOS] `xcodebuild` Debug 编译通过
- [ ] 8.2 [iOS] 模拟器跑通：登录 → 进入训练首页（空数据态） → 开始训练 → 完成一组 → 浮动 FAB 出现 → 点开弹窗 → ±10s/完成 → 结束训练 → 看到本周训练量 + 1
- [ ] 8.3 [iOS] 截图与设计稿 01/02/02b/03 四张并排对比，关键发光/字距/间距对齐
- [ ] 8.4 [iOS] Live Activity 回归：开始训练后锁屏倒计时仍正常
- [ ] 8.5 [iOS] 历史数据回归：旧用户升级后 `WorkoutListView` 不崩溃，PR 卡显示正确
