## Context

参见 `proposal.md` 的问题背景。当前 `WorkoutRestPolicy` 读取紧邻上一展示组的 `plannedRestSeconds`，但该字段只在休息启动时写入；`RestTimerController.adjust(by:)` 会更新活动计时的 `endDate` 与 `totalDuration`，完成事件却只被用于回写实际流逝时间。完成新组的路径还会先解析新休息、再收束旧休息，因此即便补充完成回写，也可能读到调整前的目标。

普通动作默认休息目前保存在训练页 `@State` 字典中；超级组轮后休息已存在 `WorkoutSupersetUnit.restAfterRoundSeconds`，并随 `Workout.units` JSON 保存。`WorkoutSet.plannedRestSeconds` / `actualRestSeconds` 已随 workout 聚合同步，后端不需要新的同步实体。

## Goals / Non-Goals

**Goals:**

- 让同一动作下一组和超级组下一轮稳定继承上一段已完成休息的最终目标，而不是初始目标或实际流逝时间。
- 复用现有完成事件和 workout 聚合同步字段，保持自然结束、提前结束、继续休息与结束训练的回填一致。
- 使普通动作默认休息成为训练单元持久状态，并保持旧 workout 可读。

**Non-Goals:**

- 不新增后端表、API 或休息同步实体。
- 不把普通动作休息配置加入计划模板，也不做跨训练历史学习。
- 不改变提醒、Live Activity 或用户全局默认休息设置的存储机制。

## Decisions

### D1. `plannedRestSeconds` 保存休息完成时的最终目标总时长

休息完成事件现有 `startedAt` 与 `plannedEndDate` 已能派生最终目标秒数：`plannedEndDate - startedAt`。用户通过 `+10s / -10s` 调整时 `plannedEndDate` 会同步变化；提前结束只改变完成时刻，不改变目标结束时刻。因此消费完成事件时：

- 首段休息以派生出的最终目标覆盖该组 `plannedRestSeconds`；
- `actualRestSeconds` 继续使用事件实际流逝秒数；
- 继续休息使用现有 `continuedRestBaseBySet` 识别追加段，将最终目标和实际时间分别累加。

选择复用现有事件时间字段，而不是新增 `targetDurationSeconds` 状态，避免同一目标同时保存在 `totalDuration`、事件字段和持久模型三个位置。秒数统一四舍五入并限制为非负。

备选方案是让 `adjust(by:)` 每次回调训练页实时写 `plannedRestSeconds`。放弃原因是这会把计时器与 SwiftData 组模型耦合，并增加每次调时的保存入口；完成事件已经是单一收束点。

### D2. 先收束旧休息，再解析新休息

普通组和超级组完成入口统一遵循：

1. 无条件调用既有活动休息收束与事件消费；
2. 在回写后的 workout 上解析当前组或当前轮的目标；
3. 写入当前锚点组的初始 `plannedRestSeconds`；
4. 目标大于 0 时启动新休息，否则确保旧休息状态已经清空。

这项顺序调整同时修复“新目标为 0 时旧倒计时仍继续”的边界。无需建立新的休息状态机。

### D3. 仅继承紧邻上一展示组的已完成休息目标

同一动作解析仍复用 `displaySortedSets`，但移除“热身组不参与继承”的例外，并要求紧邻上一组同时满足：

- `plannedRestSeconds` 非空；
- `actualRestSeconds` 非空，表示休息已经收束。

满足时使用 `plannedRestSeconds`；否则依次使用训练单元默认配置、用户全局默认和 90 秒兜底。`actualRestSeconds` 永不作为目标来源。该判断不会跨过中间未完成组向前搜索，保持“紧邻上一组”的稳定顺序语义。

### D4. 普通动作默认休息保存到 `WorkoutUnit`

为 `WorkoutUnit` 增加 optional `restAfterSetSeconds`：

- `nil`：没有动作级覆盖，使用用户全局默认；
- `0`：关闭自动休息；
- `> 0`：显式动作默认秒数。

普通动作与递减组共用该字段；菜单通过所属 `WorkoutUnit` 读写，不再维护 `restByExercise`。optional Codable 字段缺失时自动解码为 `nil`，旧 workout 保持兼容。`Workout.units` 已属于 workout 聚合的 LWW 同步内容，继续沿用既有 `localId/serverId/updatedAt/deletedAt/version` 信封、幂等 push 与软删除规则，不增加独立冲突或删除路径。

备选方案是在 `WorkoutExercise` 增列。放弃原因是需要 SwiftData、后端实体、数据库迁移和 DTO 联动，而训练单元 JSON 已是对应配置的自然归属。

### D5. 超级组按轮继承并继续复用轮末锚点组

超级组完成一轮后仍把轮后休息记录绑定到该轮最后一个成员 set；上一轮继承读取同一锚点成员的紧邻上一轮 set，并要求目标和实际记录均已存在。回退配置继续使用 `WorkoutSupersetUnit.restAfterRoundSeconds`，轮内第一个成员完成路径不进入休息解析。

这保持现有同步模型，不新增轮实体或休息实体。普通动作策略只提供“最终目标是否可继承”的判断，超级组调用方负责轮级锚点和回退配置，避免把成员动作顺序误当成轮顺序。

## Risks / Trade-offs

- [Risk] `finalize-active-rest-with-target-duration` 与本 change 同时修改组间休息回填规格，归档顺序可能覆盖内容。→ Mitigation：本 delta 保留其“结束训练时实际时间按目标总时长写入”的最终语义；归档前比较主规格的完整 requirement。
- [Risk] `add-superset-training-units` 尚未归档，超级组基础 requirement 不在主规格。→ Mitigation：本 change 使用独立的“超级组轮后休息最终目标继承”requirement，实施与归档前同时验证两个 change。
- [Risk] 旧训练只有组级预计值、没有训练单元默认配置。→ Mitigation：optional 缺失回退全局默认，不从历史组反向构造配置。
- [Risk] App 在活动休息完成事件尚未消费时被系统终止，最终调时可能未落盘。→ Mitigation：维持现有事件消费生命周期；本 change 不新增后台持久化机制，真机回归覆盖最小化与恢复路径。

## Migration Plan

1. 先更新策略与单元测试，再接入训练页完成顺序和事件双字段回填。
2. 增加 `WorkoutUnit.restAfterSetSeconds` 并将普通动作菜单从会话字典迁移到训练单元 JSON。
3. 验证旧 `units` JSON 解码、workout 聚合 push/pull 与超级组轮级路径。
4. 随 iOS 客户端发布；无后端部署与数据迁移。

回滚时移除客户端对新 optional 字段的使用即可。旧客户端会忽略 JSON 中未知字段，现有组级预计与实际字段保持兼容。

## Open Questions

无。
