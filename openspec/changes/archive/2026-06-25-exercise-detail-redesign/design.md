## Context

`ExerciseDetailView`（`Workout/ExerciseViews.swift`）现状：`cover`（斜纹占位）+ `title`（含裸 `code`）+ `tipsCard`（占位）+ `musclesCard`（协同「—」）+ `joinCTA`（加入今日训练，调 `addToTodayWorkout()` 默默改写活跃会话）。设计稿见 Open Design `MeiGeiApp2` 的 `meigei-c-exercise-detail-v2.html`。前序 `exercise-muscle-data` 已提供 `MuscleMapView`、`BuiltinExercise` 的 region/cues、`UserProfile.sex`、`PRStats.latestPR`。

## Goals / Non-Goals

**Goals:**
- 详情页收敛为纯浏览：动作百科 + 我的历史，零写入副作用。
- 复用既有数据与组件（MuscleMapView / PRStats / Swift Charts），不新增持久化。

**Non-Goals:**
- MuscleMapView 内部实现、全屏历史页新建、自定义动作要点、详情页编辑。

## Decisions

### D1：删除 joinCTA 及其副作用
移除 `joinCTA` / `addToTodayWorkout()` / `@State startedSession` / `.navigationDestination(item:$startedSession)`；`ZStack(alignment:.bottom)` 退回普通 `ScrollView`，去掉给 CTA 让位的底部占位。
- 理由：浏览 ≠ 训练；默默改写活跃会话是数据隐患。加动作入口已由 `ExercisePickerView`/计划编辑覆盖。

### D2：高亮图段
`MuscleMapView(primary: ex.primaryRegions, secondary: ex.secondaryRegions, sex: profile.sex)`，`primaryRegions` 为空时整段 `if` 不渲染。正/背切换为段内本地 `@State`。
- profile 取当前用户（与 ProfileView 一致：`profiles.first { $0.serverUserId == session.currentUserId }`），缺失时默认 `.male`。

### D3：「你的数据」重算口径
- 上次日期 / 最近一组：遍历 `workouts`（endedAt != nil, deletedAt == nil）按 `historyKey == ex.code` 命中，取 `startedAt` 最近一次的最后一组。
- PR：复用 `PRStats.latestPR(for: ex.code, in: workouts)`。
- 迷你图：每次训练日的最大重量序列，用 Swift Charts 画 bar/line；点击进全屏历史（若无独立页，降级不可点 + TODO）。
- 无历史 → 整段降级为「还没练过」，不显 0。

### D4：要点 / 目标肌群
- `formCues` 为空隐藏要点段；regions 为空隐藏目标肌群段。
- 目标肌群色点 = MuscleMapView 三态色（accent / accentSofter），文案用 `MuscleRegion.displayName`。
- `code` 不再作为标题副信息；如需保留可 DEBUG 小字。

### D5：meta chip 可点（可选增强）
部位/器械 chip 点击回动作库并预置筛选——若导航成本高，本期可先做成纯展示，标 TODO。

## Risks / Trade-offs

- [移除 CTA 改变既有用户习惯] → 该 CTA 本就是误设计（浏览写数据）；移除是纠正，加动作主路径不受影响。
- [全屏历史页可能尚不存在] → 迷你图点击降级为不可点 + TODO，不阻塞本页交付。
- [自定义动作走同一详情组件?] → 本 change 仅重构内置动作详情（`ExerciseDetailView(exercise: BuiltinExercise)`）；自定义动作无 region/cues 时各段自然隐藏。

## Migration Plan

1. 删 joinCTA 相关代码与导航，页面结构退回 ScrollView。
2. cover → MuscleMapView（含缺数据隐藏 + 正背切换）。
3. 加「你的数据」子视图（重算 + 迷你图）。
4. tips/muscles 段接 `formCues` / regions。
5. 编译 + 对照 spec 场景核对。
- 回滚：本 change 仅触 `ExerciseDetailView`，还原该 view 即可；不影响数据与其他视图。
