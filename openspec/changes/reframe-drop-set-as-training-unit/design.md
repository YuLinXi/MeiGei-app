## Context

当前训练模型已经有一级训练单元 `WorkoutUnitKind.singleExercise / superset`，超级组按一级结构保存；但递减组仍是普通动作内部某个 `WorkoutSet` 的 `setType = drop`，并通过 `segments` 保存内部组。计划侧同样是 `PlanUnitKind.singleExercise / superset`，递减组藏在单动作计划项的 `setPrescriptions[].setType = drop` 里。

这个状态带来两个产品不一致：

- 超级组是“训练单元”，递减组却是“组内类型”，普通动作可以混合普通组和递减组。
- 热身被编码成 `setType = warmup`，递减组被编码成 `setType = drop`，因此同一个递减组无法同时表达“递减结构”和“热身语义”。

本变更以当前实现为基础做收敛：产品上严格定义普通组、超级组、递减组三选一；技术上优先复用既有 Workout 聚合、计划 jsonb、`segments` 字段和同步路径，不新增独立同步域。

## Goals / Non-Goals

**Goals:**

- 增加 `dropSet` 作为与普通组、超级组平级的训练单元类型。
- 保证一个训练单元创建后只属于普通组、超级组、递减组三者之一，且不可互相转换。
- 支持普通组、超级组、递减组都能标记热身。
- 将递减组统计从父级 1 个逻辑组改为内部有效 segments 计 N 组。
- 收敛添加入口：主入口“添加动作”创建普通组，结构菜单创建递减组或超级组。
- 更新计划预填、自适应回写、Team summary、海报和详情展示，使它们使用同一训练单元与统计口径。

**Non-Goals:**

- 不做普通组、递减组、超级组之间的转换或解除联动。
- 不做旧递减组数据向新训练单元的兼容迁移；当前递减组虽已上线，但尚无人使用，可直接改语义。
- 不校验递减组内部重量方向。
- 不新增后端独立表、独立同步实体或统计缓存。
- 不扩展超级组到 3 个及以上动作、嵌套超级组或超级组内递减组。

## Decisions

### D1. `dropSet` 成为一级训练单元，底层暂时复用 `WorkoutSet.segments`

产品模型收敛为：

```text
Workout
└─ units
   ├─ singleExercise  // 普通组
   ├─ superset        // 超级组
   └─ dropSet         // 递减组
```

实现上优先采用渐进结构：

- `WorkoutUnitKind` 新增 `dropSet`。
- `WorkoutUnit.dropSet` 可先复用 `singleExerciseId` 指向唯一动作，或新增轻量 payload 保存该动作引用；实现时二选一，但领域 helper 必须统一暴露为 drop set unit。
- 该动作下保存一个父级 `WorkoutSet(setType = drop, segments = [...])`，父级承载完成状态、备注、休息、删除和排序。
- 领域 invariant：`setType = drop` 只能出现在 `WorkoutUnitKind.dropSet` 指向的动作里；普通 `singleExercise` 动作不得再包含递减组 set。

选择该方案的原因：现有 iOS、后端、DTO、Team summary 和海报已经能传递 `segments`，继续复用可以降低变更风险。备选方案是彻底移除 `WorkoutSetType.drop` 并把 segments 直接挂到 `WorkoutUnit.dropSet` 上，模型更纯粹，但会重写更多同步和展示代码；当前收益不足。

### D2. 热身从 `setType` 拆成独立标记

新语义下，`setType` 不再同时承担“结构类型”和“是否热身”两种职责。新增 canonical 热身标记：

```text
WorkoutSet
├─ structural type: working | drop
└─ isWarmup: Bool
```

普通组：每个普通 set 可独立 `isWarmup = true`。

超级组：热身按整轮生效。用户标记某轮为热身时，同一 round index 下两个成员 set 的 `isWarmup` 必须同步为相同值，不支持只把其中一个成员标热身。

递减组：热身按整个递减组生效。父级 drop set 的 `isWarmup = true` 时，全部有效 segments 都按热身组处理。

`WorkoutSetType.warmup` 可在实现期作为旧 raw 值兜底读取，但新写入不得依赖 `setType = warmup` 表达热身。统计 helper 统一改为 `completed && !isWarmup`。

计划侧如果需要保存热身处方，应同样使用 `isWarmup`，而不是把热身编码进 `setType`。普通计划项可在 `PlanSetPrescription` 上保存 `isWarmup`；递减组计划单元可保存 unit/set 级 `isWarmup`；超级组计划若需要热身轮，则两个成员同一轮必须同步。

### D3. 递减组按内部有效 segments 计 N 组

递减组统计入口统一为 `statEntries`：

```text
普通正式 set completed && !isWarmup => 1 entry
递减组 completed && !isWarmup       => 有效 segments 数量个 entry
热身或未完成                       => 0 entry
```

有效 segment 指至少有重量或次数的 segment；完全空白 segment 不参与训练量、总次数、PR、组数或回写。递减组父级 set 仍可保留摘要重量/次数用于兼容展示，但统计必须展开有效 segments。

影响口径：

- 周总组数、完成页已完成组数、训练详情聚合、Team summary、海报组数都按 segments 数量计。
- 训练量、总次数、PR、历史曲线继续按 segments 展开。
- 自适应回写中的 `suggestedSets` 使用本次正式统计 entry 数量，递减组 3 个有效 segments 就贡献 3 组。

### D4. 添加入口只保留一个结构菜单

底部入口结构：

```text
[结构菜单图标] [ + 添加动作 ]

结构菜单:
  - 递减组
  - 超级组
```

“添加动作”是普通组主入口，保持最高频路径。递减组和超级组进入二级菜单，避免底部堆叠多个大按钮。普通动作卡内不再显示“递减组”快速入口；组级更多菜单不再提供“改为递减组 / 改回普通组”。超级组的“解除超级组”也移除，因为它属于跨类型转换。

### D5. 计划项同样使用三选一单元

`PlanUnitKind` 新增 `dropSet`，计划结构与训练结构保持同层级：

```text
WorkoutPlan.items
├─ singleExercise
├─ superset
└─ dropSet
```

递减组计划单元保存一个动作和有序 segments。严格模式从计划开始训练时生成一个 drop set unit 并落值 segments；自适应模式优先使用上次同类型 drop set 实绩结构，无历史再回退计划结构。保存为计划、Team 分享计划和 Fork 保留递减组结构与次数，但继续清空重量字段。

普通、递减、超级三种计划单元创建后不可互转；计划编辑只允许编辑同类型内部参数，例如动作、组数、segments、成员默认重量/次数，不提供类型切换。

### D6. 同步仍走既有聚合与 jsonb

Workout 聚合仍随 `Workout` 根 push/pull，不新增递减组独立同步信封。训练计划仍以 jsonb 保存；每个计划单元继续保持稳定 `itemId`。后端写接口继续遵守幂等键；同步实体继续遵守 `serverId/localId/updatedAt/deletedAt/version` 与 last-write-wins。

因为用户明确旧递减组无人使用，本变更不设计旧递减组数据迁移。开发/测试 fixtures 可直接按新结构重写。对于已存在的普通历史训练，旧普通组仍可按 singleExercise 读取；对于旧 `setType = warmup`，实现可用一次性轻量迁移或 decode fallback 写入 `isWarmup`。

## Risks / Trade-offs

- [Risk] 热身从 `setType` 拆为 `isWarmup` 会触碰大量统计和 UI 判断。  
  → Mitigation：集中建立 `countsForStats`、`isWarmup`、`statEntries` helper，禁止视图层直接拼接 `setType != .warmup`。

- [Risk] 暂时保留 `WorkoutSetType.drop` 会让代码看起来仍像“组内递减组”。  
  → Mitigation：用领域 invariant 和命名收口，只有 `dropSet` unit 的父级 set 能为 drop；普通动作路径隐藏并禁止创建 drop set。

- [Risk] 递减组按 N 组计数会改变所有摘要数字。  
  → Mitigation：在周统计、完成确认、计划摘要、Team summary、海报共用同一个统计派生 helper，避免各处口径漂移。

- [Risk] 移除“解除超级组”和“组内切递减组”会减少快速修改能力。  
  → Mitigation：这是产品边界换来的概念稳定；用户需要改类型时删除并重新添加。

- [Risk] 新旧 active OpenSpec 中超级组曾定义“不支持热身”和“可解除超级组”。  
  → Mitigation：本 change 明确作为后续收敛，implementation 时需同步更新超级组相关规格和已完成代码。

## Migration Plan

1. iOS 先引入 `isWarmup`、`dropSet` unit kind 和统一统计 helper，更新本地 fixtures。
2. 更新训练 UI，移除组级递减转换和超级组解除，新增底部结构菜单。
3. 更新计划模型与计划编辑/预填/回写，支持 `PlanUnitKind.dropSet`。
4. 更新同步 DTO、Team summary、海报与详情展示，确保 segments 和 `isWarmup` 原样传递。
5. 后端如需 schema 变更，仅补充 `is_warmup` 或对应 JSON 字段透传；不新增独立同步域。
6. 运行 OpenSpec validate、后端测试、iOS simulator build 和相关统计/计划单元测试。

Rollback 策略：本变更尚未面对真实递减组用户数据。若实现中途回滚，可隐藏递减组/超级组结构菜单入口，并保留模型字段不暴露 UI；普通训练记录仍按 singleExercise 工作。

## Open Questions

无阻塞问题。默认按本设计执行：超级组热身为整轮热身，递减组热身为整体热身，三种训练单元不可互转。
