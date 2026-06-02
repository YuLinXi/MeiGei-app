# 设计：训练会话生命周期

## 背景

当前 `Workout` 只有一个隐式状态（`endedAt` 是否为 nil），但进行中页 `WorkoutLoggingView` 在两种状态下复用同一界面、且各状态允许的操作自相矛盾（见 proposal「Why」）。本设计将训练会话定义为一个显式有限状态机，并据此重构呈现与操作约束。

## 状态机

```
                  begin(单例守卫:已有进行中→拦截)
   ●───────────────────────────▶  ┌─────────────┐
        (无会话)                    │   ACTIVE     │  Live 记录界面
                                    │  进行中(唯一) │  墙钟计时(无暂停)
                                    └─────────────┘
                                     │           │
                          discard ◀──┘           └──▶ finish(二次确认)
                             │                          │
                             ▼                          ▼
                         (软删墓碑)              ┌─────────────┐
                                                 │  FINISHED    │  只读摘要界面
                                                 │   已完成      │  计时冻结
                                                 └─────────────┘
                                                   │          │
                                           edit ◀──┘          └──▶ delete(左滑)
                                           (原地编辑,                   │
                                            存盘重算PR/更新打卡,         ▼
                                            仍是FINISHED)          (软删墓碑→后端)
```

状态判定（派生，不新增持久化字段）：

| 状态 | 判定条件 |
|------|---------|
| 无会话 | 不存在 `deletedAt == nil && endedAt == nil` 的 `Workout` |
| ACTIVE | `deletedAt == nil && endedAt == nil`（**全局至多一个**） |
| FINISHED | `deletedAt == nil && endedAt != nil` |

## 关键决策

### D1：会话计时为墙钟，移除暂停（不新增字段）

- 决策：会话总时长 = `endedAt − startedAt`（墙钟，含组间休息）。删除进行中页暂停按钮及 `paused` 状态。
- 理由：严肃力量训练中组间休息本就是训练的一部分，「我练了 75 分钟」含休息是真实指标，亦是 Strong/Hevy 等品类标准；「歇一下」的真实交互需求由既有 `RestTimerController`（组间倒计时 + Live Activity）承载。会话级暂停是在重复解决已解决的问题，且当前实现仅产 bug。
- 取舍：放弃「有效训练时长（剔除休息）」指标。若未来确需，再引入 `accumulatedActiveSeconds` + `pausedAt` 并处理后台/锁屏边界——届时单独立项，不在本 change。

### D2：结束 = 二次确认 + 计时冻结

- 决策：「结束」按钮触发确认弹窗，展示「X 动作 · Y 组完成」摘要；确认才置 `endedAt = .now` 并执行归档副作用（HealthKit 写入、PR 检测、Team 打卡）；取消回到 ACTIVE。已完成后计时文本冻结为 `formatHMS(endedAt − startedAt)`，不再随 `TimelineView` 增长。
- 理由：结束是不可逆归档动作（无「恢复到进行中」），误触代价高，需确认；冻结消除「结束后秒数还在跑」的 bug。
- 实现要点：将 REC 计时从无条件 `TimelineView` 改为——ACTIVE 用 `TimelineView` 实时墙钟；FINISHED 用静态 `Text`。

### D3：已完成 = 只读摘要 + 显式编辑，编辑后重算派生数据

- 决策：进行中（Live 记录）与已完成（只读摘要）为两套呈现。已完成态默认只读：隐藏「添加动作」入口、`SetRow` 完成勾选与输入框禁用。提供显式「编辑」进入可编辑态；编辑保存后 MUST 重新执行 PR 检测，并更新该训练对应的 Team 打卡摘要（若已打卡）。
- 理由：人在训练中手滑常见，必须可改；但「在 Live 界面里随便改」语义混乱（当前 bug）。显式编辑态把「结束后还能加动作」从「漏写守卫的意外」变为「一致、可控的编辑动作」，直接消解矛盾。同时修复「结束后再改导致 PR/打卡静默不一致」。
- 取舍：不做「恢复到进行中（重新计时）」——跨天、计时回跳语义别扭，且编辑已覆盖该需求。
- 时长可编辑：编辑态允许调整 `startedAt` / `endedAt`（修正墙钟计时被遗弃拉长的脏数据），作为 D1 移除暂停后的兜底。

### D4：单一活跃会话守卫

- 决策：所有「开始训练」入口（`startBlank` / `start(from:)` / `PlanDetailView.startWorkout` / `ExerciseDetailView.addToTodayWorkout`）统一经一个 `beginSession` 守卫。存在 ACTIVE 会话时不直接新建，而是提示「继续 / 丢弃」：「继续」打开既有会话；「丢弃」对既有会话执行软删后再新建。
- 理由：消除多开活跃会话与动作归属不确定的 bug；逼迫用户处理遗弃会话，杜绝鬼影记录；为「进行中」赋予明确语义与入口（首页横幅）。
- 呈现：训练首页顶部，若存在 ACTIVE 会话，渲染醒目「继续训练」横幅（区别于「最近训练」常规行）；ACTIVE 会话 MUST NOT 再以普通已完成行混入最近列表。

### D5：删除（软删墓碑）

- 决策：FINISHED 训练记录支持列表左滑删除；进行中会话经 D4「丢弃」删除。两者均调用 `Workout.markDeleted()` 走软删墓碑，由 `SyncEngine` push 至后端。
- 风险/核对项：CLAUDE.md 已知坑——MyBatis-Plus `updateById` 不写 `@TableLogic` 字段，墓碑推不上去；`Workout` 聚合根删除另需连带删子树（`workout_exercise` / `workout_set`，ON DELETE CASCADE）。需核对后端 `Workout` 的 `softDelete` mapper 与 push 分支是否已就绪，缺失则补齐（见 tasks 后端段）。
- 删除确认：左滑删除 SHALL 二次确认（与「结束确认」区分语气：结束=归档、删除=移除）。

## 未决问题

- 「丢弃」是否对从未同步过（`serverId == nil`）的进行中会话直接硬删（`modelContext.delete`）以免留无意义墓碑？倾向：`serverId == nil` 硬删、否则软删墓碑。实现时按此处理，spec 仅约束「删除后不再出现且不计入统计」的可观察行为。
