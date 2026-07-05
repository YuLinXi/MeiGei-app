## Context

当前 iOS 端已有三块相关能力：

- 训练正向计时：`Workout.timerStartedAt` 是本次训练的计时起点，App 内 REC header 与 LIVE 悬浮胶囊基于它展示已训练时长。
- 组间休息计时：`RestTimerController` 以墙钟 `endDate` 为基准，驱动 App 内 FAB、休息弹窗、本地通知、声音、触觉和休息 Live Activity。
- Widget Extension：`RestActivityAttributes` 与 `RestTimerLiveActivity` 只表达休息倒计时，休息开始时创建 Activity，休息结束或训练结束时销毁。

新需求不是新增一个独立训练 Activity，而是把系统级持续展示面从“休息短窗口”升级为“训练会话状态”。这能避免两个 Live Activity 争抢 Dynamic Island，也让用户在非休息阶段离开 App 时仍能看到本次训练正向计时。

本变更不改后端 API、不新增同步实体、不新增持久化模型字段。训练会话仍由本地 `Workout` 聚合根表示，符合现有离线优先与 last-write-wins 同步规则；Live Activity 状态是本机系统展示状态，不作为云同步真相源，也不涉及身份三层、幂等键或软删除模型变更。

## Goals / Non-Goals

**Goals:**

- 使用单一训练会话 Live Activity 覆盖训练正向计时与组间休息倒计时。
- 在训练计时开始后创建或更新 Live Activity，phase 为 `workout` 时展示从 `timerStartedAt` 起算的正向计时。
- 休息开始时将同一个 Activity 更新为 `rest` phase，展示 `restEndDate` 倒计时与下一组摘要。
- 休息结束后恢复为 `workout` phase，不让灵动岛整体消失。
- 结束训练、放弃训练或活跃训练会话失效时立即结束 Activity。
- 保持 App 内休息 FAB、本地通知、声音、触觉反馈的现有行为。

**Non-Goals:**

- 不运行两个并行 Live Activity。
- 不引入远程 push 更新 Live Activity。
- 不新增 WatchKit app 或 Watch 专用布局；Watch Smart Stack 继续作为平台条件能力。
- 不改变 `Workout` / `WorkoutSet` 同步契约，不新增后端字段或接口。
- 不改变训练前未开始计时时的产品行为；用户仅创建会话但未开始计时时不需要展示系统级 Live Activity。

## Decisions

### 1. 单 Activity + phase，而不是两个 Activity

采用一个 `WorkoutActivityAttributes`（或等价重命名后的 Activity attributes）表示整场训练会话。`ContentState` 中加入 `phase`：

```text
WorkoutActivityAttributes
├─ workoutId
├─ workoutTitle
├─ startedAt
└─ ContentState
   ├─ phase: workout | rest
   ├─ completedSetCount
   ├─ remainingExerciseCount
   ├─ nextSet?
   ├─ restEndDate?
   └─ restTotalDuration?
```

理由：ActivityKit 对 Dynamic Island 的展示优先级由系统管理，两个并行 Activity 无法保证稳定同时展示或按业务优先级切换。训练与休息同属一场会话，用 phase 建模更符合用户心智，也简化结束训练时的收束逻辑。

备选方案：保留现有 `RestActivityAttributes`，再新增 `WorkoutActivityAttributes`。放弃原因是状态竞争和边界复杂：休息结束、训练结束、App Intent 按钮、系统预算都会变成双 Activity 协调问题。

### 2. Live Activity 控制权从 RestTimer 上移到训练会话层

新增一个主 App 内的会话 Activity 控制器，例如 `WorkoutLiveActivityController`。它负责：

- `startWorkout(workout:)`：训练计时开始时创建 Activity，或更新已存在 Activity 为 `workout` phase。
- `enterRest(...)`：休息开始时更新为 `rest` phase。
- `exitRest(...)`：休息自然结束或提前结束时更新回 `workout` phase。
- `endWorkout()`：结束或放弃训练时立即结束 Activity。

`RestTimerController` 继续负责休息倒计时、本地通知、声音、触觉和完成事件。它不再直接拥有“整场训练会话 Activity”的生命周期，只在休息开始、调时、结束时通过训练会话层触发 phase 更新。

理由：当前 `RestTimerController` 的生命周期只覆盖休息，无法表达非休息阶段的训练正向计时。将 Activity 所有权上移后，训练会话是唯一真相，休息只是状态切换。

### 3. 正向计时使用系统自走文本，避免每秒更新

phase 为 `workout` 时，Widget 端使用 attributes 中的 `startedAt` 计算正向计时。Activity 不应为了秒级变化频繁 update；只有离散事件触发更新：

- 训练计时开始
- 完成组数或剩余动作变化
- 进入休息
- 调整休息时长
- 休息结束
- 结束或放弃训练

理由：ActivityKit 更新有系统预算，秒级 update 没有必要。现有休息倒计时已经使用 `Text(timerInterval:)` 自走，训练正向计时也应采用同类系统计时文本。

### 4. 休息 App Intent 只结束休息 phase

现有「结束」按钮来自 `EndRestIntent`，它的业务语义是提前结束当前休息。迁移后按钮仍只发出“结束休息”信号：

- 如果当前 Activity phase 为 `rest`，主 App 收到信号后走 `RestTimerController.completeEarly()`，再由训练会话层更新回 `workout` phase。
- 如果主 App 未及时唤起，widget 进程可结束或更新可见的休息状态，但不得把用户的整场训练记录标为结束。

理由：灵动岛上的“结束”在休息语境下不是“结束训练”。避免一个系统按钮造成训练归档或丢弃的高风险副作用。

### 5. Widget UI 按 phase 复用品牌与信息密度

Dynamic Island / 锁屏视图分两套信息语义：

- `workout` phase：展示 `REC`、正向计时、已完成组、剩余动作、下一组摘要。
- `rest` phase：展示 `REST`、倒计时、下一组动作、组序号、重量、次数，不在 Live Activity 上提供操作按钮。

颜色使用现有 widget 资源和项目 UI 规范。compact / minimal 尽量保持稳定：leading 为 App icon，trailing 根据 phase 显示正向计时或倒计时。

## Risks / Trade-offs

- [Risk] Activity attributes 重命名后 App 与 Widget 端类型不一致会导致 ActivityKit 匹配失败。
  Mitigation：同一份 attributes 源码同时编进 App 与 `DontLiftWidgetsExtension`，并用 `xcodebuild` 验证 target membership。

- [Risk] 休息结束后 App 在后台无法及时 update 回 `workout` phase，灵动岛可能短暂停在归零休息态。
  Mitigation：休息 phase 的 `staleDate` 使用 `restEndDate`，并保留回前台兜底；实现时评估 widget 进程或本地任务在预算内的自动回切策略。如果系统不允许后台可靠回切，则验收口径允许短暂宽限，但不能长期残留错误倒计时。

- [Risk] Live Activity 禁用或系统预算不足时，用户看不到灵动岛。
  Mitigation：保持 App 内 REC/FAB/弹窗、本地通知、声音、触觉完全独立，不能依赖 Activity 成功。

- [Risk] phase 更新点分散在训练完成组、休息调时、结束训练等路径，遗漏会造成显示陈旧。
  Mitigation：把 Activity update 收敛到训练会话层的少数公开方法，并在任务中覆盖关键路径。

## Migration Plan

1. 新增或重命名 Activity attributes 与 Widget 视图，使 App 和 Widget extension 共享同一类型。
2. 新增训练会话 Live Activity 控制器，先接入训练计时开始、结束训练、放弃训练。
3. 将休息开始、调时、提前结束、自然结束改为 phase update，保留本地通知与 App 内休息逻辑。
4. 更新 App Intent，使「结束休息」只退出 `rest` phase。
5. 使用 iPhone Simulator 构建验证；真机阶段再验锁屏、Dynamic Island、Watch Smart Stack 条件呈现。

Rollback 策略：如果新 Activity 控制器不稳定，可回退到现有休息 Activity 行为；由于不改后端和持久化数据，回滚只影响 iOS 展示面。

## Open Questions

- 休息自然结束且 App 已在后台挂起时，是否能在目标系统版本上稳定自动回切到 `workout` phase，需要真机验证 ActivityKit 的后台 update 时机。
- `WorkoutActivityAttributes` 是否直接替换 `RestActivityAttributes` 文件名，还是保留旧文件名但改内部类型名，取决于实现时对 pbxproj Sources membership 的最小改动成本。
