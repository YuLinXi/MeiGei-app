## 1. 移除加入训练 CTA（iOS 端）

- [x] 1.1 删 `ExerciseDetailView` 的 `joinCTA` / `addToTodayWorkout()` / `@State startedSession` / `.navigationDestination(item:$startedSession)`
- [x] 1.2 `ZStack(alignment:.bottom)` 退回普通 `ScrollView`，去掉底部 CTA 让位占位

## 2. 高亮图段（iOS 端）

- [x] 2.1 cover 占位 → `MuscleMapView(primary:secondary:sex:)`，取当前用户 `profile.sex`（缺失默认 `.male`）
- [x] 2.2 `primaryRegions` 为空 → 整段隐藏（不显斜纹占位）
- [x] 2.3 段内正/背切换（本地 `@State` + 分段控件），默认面由组件决定

## 3. 你的数据段（iOS 端）

- [x] 3.1 重算上次训练日期 + 最近一组（按 `historyKey == ex.code` 命中 `workouts`，最近 `startedAt`）
- [x] 3.2 PR 复用 `PRStats.latestPR`；展示 PR 重量
- [x] 3.3 迷你强度图（Swift Charts BarMark，每训练日最大重量）；**无独立全屏历史页 → 暂降级为不可点（TODO 待历史页）**
- [x] 3.4 无历史降级「还没练过」，不显 0 / 空图

## 4. 要点与目标肌群（iOS 端）

- [x] 4.1 要点段接 `formCues`（编号短句列表）；空则隐藏
- [x] 4.2 目标肌群段接 primary/secondary regions，用 `displayName` + 三态色点；无 region 隐藏
- [x] 4.3 不再把 `code` 作为标题副信息展示；meta chip（部位/器械）保留（可点回筛选为可选 TODO）

## 5. 验收

- [x] 5.1 `xcodebuild` 编译通过；动作库/选择器/计划编辑等加动作入口不回归
- [x] 5.2 代码层核对 spec 场景（进入不写入=已删 CTA/会话写入；五段结构；regions/cues 空各段隐藏；无历史降级；标题不含 code）
- [x] 5.3 模拟器目检：详情页五段渲染、点击进入正常
