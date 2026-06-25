## Why

动作详情页（`ExerciseDetailView`）自 MVP 起是占位：斜纹「采集中」配图、空要点、协同肌「—」，底部还有个「加入今日训练」CTA——它从浏览场景**默默新建/改写当前训练会话**，是隐患。前序 `exercise-muscle-data` change 已产出 `MuscleMapView` 高亮图组件与 150 条 region/要点数据。本 change 把详情页从「半个加动作入口」重构为纯粹的**动作百科 + 我的历史**。

## What Changes

- 配图占位 → **`MuscleMapView` 肌群高亮图**（按用户 `sex` 选底图，正/背可切）；无细分数据（自定义动作）则隐藏该段。
- 新增 **「你的数据」段**：上次训练日期 / 最近一组 / PR / 估算曲线迷你图，全部按 `workouts` 重算、不持久化；点曲线进全屏历史。
- **要点填实**（`formCues`）、**目标肌群填实**（primary/secondary regions 中文名 + 与高亮图同源三态色点）。
- **BREAKING（页面行为）**：删除底部「加入今日训练」CTA 及其 `addToTodayWorkout()` / `startedSession` 导航——浏览页不再写训练数据。加动作入口仍在训练会话的 `ExercisePickerView` 与计划编辑。
- 用户侧不再展示内部 `code`（降为可选小字脚注或隐藏）；meta chip（部位/器械）可点回动作库筛选。

## Capabilities

### New Capabilities
<!-- 无新增 capability -->

### Modified Capabilities
- `workout-tracking`: 新增「动作详情页（ExerciseDetail）版式与行为」requirement —— 五段结构、消费 `MuscleMapView`、「你的数据」重算口径、移除加入训练 CTA 的行为契约。

## Impact

- **iOS 视图层**：重写 `Workout/ExerciseViews.swift` 的 `ExerciseDetailView`（cover/title/tips/muscles/CTA 五处）；接入 `MuscleMapView`；新增「你的数据」子视图（复用 `PRStats.latestPR` + 直接遍历 `workouts`）；Swift Charts 迷你图。
- **依赖**：`exercise-muscle-data`（`MuscleRegion` / `BuiltinExercise.primaryRegions/secondaryRegions/formCues` / `UserProfile.sex` / `MuscleMapView`）必须先落地。
- **导航**：移除 `ExerciseDetailView` 内 `addToTodayWorkout()` 与 `.navigationDestination(item: $startedSession)`；详情页唯一出口型交互改为「进全屏历史」。
- **非影响**：不改动作库（`ExerciseLibraryView`）、`ExercisePickerView`、计划编辑等加动作入口；不改 PR/historyKey 计算口径。

## Non-goals

- **不做** `MuscleMapView` 本身的渲染/数据（已属 `exercise-muscle-data`）。
- **不做**全屏历史曲线页的新建——复用既有历史/PR 展示路径；若暂无独立全屏页，则曲线点击降级为不可点（留 TODO），不阻塞本页。
- **不做**自定义动作详情的要点/高亮（自定义动作无 region/cues 时相应段隐藏）。
- **不做**动作详情页的编辑能力（内置动作只读）。
