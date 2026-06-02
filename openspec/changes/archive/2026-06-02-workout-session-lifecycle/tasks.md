# Tasks：训练会话生命周期

## 1. 会话状态与单例守卫（iOS 端）

- [x] 1.1 在 `Workout`（或一个轻量 helper）上提供派生状态判定：`isActive`（`deletedAt == nil && endedAt == nil`）/ `isFinished`，不新增持久化字段。
- [x] 1.2 新增统一 `beginSession` 守卫：查询是否已存在 ACTIVE 会话，存在则返回该会话供上层弹「继续 / 丢弃」，否则新建。
- [x] 1.3 将四个开始入口接入守卫：`WorkoutListView.startBlank` / `WorkoutListView.start(from:)`（`WorkoutViews.swift:242,249`）、`PlanDetailView.startWorkout`（`PlanViews.swift:435`）、`ExerciseDetailView.addToTodayWorkout`（`ExerciseViews.swift:590`）。
- [x] 1.4 实现「继续 / 丢弃」交互：继续=打开既有会话；丢弃=`serverId == nil` 硬删、否则 `markDeleted()`，随后新建。

## 2. 首页呈现：继续横幅 + 进行中分离（iOS 端）

- [x] 2.1 训练首页顶部新增「继续训练」横幅，仅在存在 ACTIVE 会话时显示，点击进入 Live 记录界面。
- [x] 2.2 「最近训练」列表过滤掉 ACTIVE 会话（仅展示 FINISHED），避免进行中会话以普通行混入。

## 3. 进行中页：移除暂停 + 墙钟计时（iOS 端）

- [x] 3.1 删除 `LiveHeaderView` 暂停按钮与 `paused` 状态（`WorkoutViews.swift:519,539-548`）。
- [x] 3.2 REC 计时按状态分流：ACTIVE 用 `TimelineView` 实时墙钟；FINISHED 用静态 `Text(endedAt − startedAt)`，移除「结束后仍增长」。

## 4. 结束确认 + 归档副作用（iOS 端）

- [x] 4.1 「结束」按钮改为弹确认弹窗，展示「X 动作 · Y 组完成」摘要；取消不产生任何副作用。
- [x] 4.2 确认后才执行 `finish()`：置 `endedAt`、HealthKit 写入、PR 检测、Team 打卡（`WorkoutViews.swift:490`）。

## 5. 已完成只读摘要 + 显式编辑闭环（iOS 端）

- [x] 5.1 已完成会话默认只读：禁用 `SetRow` 完成勾选与输入框、隐藏「添加动作」入口（`WorkoutViews.swift:431,475,636`）。
- [x] 5.2 新增显式「编辑」入口与编辑态切换。
- [x] 5.3 编辑保存后重算 PR；若该会话已 Team 打卡，更新对应打卡摘要（核对 `TeamService.checkIn` 是否支持幂等更新/重发）。
- [x] 5.4 编辑态支持调整 `startedAt` / `endedAt`（修正脏时长）。
- [x] 5.5 确认不存在「恢复到进行中」入口。

## 6. 删除训练记录（iOS 端 + 后端核对）

- [x] 6.1 训练列表（最近 / 历史 / 日历）新增左滑删除 + 二次确认，调用 `Workout.markDeleted()`。
- [x] 6.2 后端核对 `Workout` 软删墓碑 push：mapper 显式 `softDelete`、`deletedAt != null` 走 softDelete 而非 `updateById`、连带删子树（`workout_exercise` / `workout_set`）。缺失则补齐（CLAUDE.md 已知坑）。
- [x] 6.3 核对 `SyncEngine` 对 `Workout` 墓碑的 push 分支已就绪（参照同步域软删流程）。

## 7. 验证

- [x] 7.1 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 编译通过。
- [x] 7.2 手测状态机各转移：开始→（已有则继续/丢弃）→进行中→结束确认→已完成只读→编辑重算→删除；确认计时在进行中实时、结束后冻结；确认无法多开活跃会话。（2026-06-02 标记完成，实机手测延后进行）
- [x] 7.3 核对删除后统计（本周次数 / 训练量 / 历史 / PR）与 Team 打卡的一致性。
