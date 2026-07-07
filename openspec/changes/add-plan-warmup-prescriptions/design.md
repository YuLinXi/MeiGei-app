## Context

训练记录侧已经有热身组语义：`WorkoutSet.isWarmup` / 旧 `setType == warmup` 兼容、`countsForStats = completed && !isWarmup`，并且训练 UI 能把普通组标记为「热」。计划侧也已有 `PlanSetPrescription.isWarmup`，但产品形态没有收口：普通动作编辑页没有把热身处方作为明确能力展示，自适应预填和回写主要围绕 `countsForStats`，容易把热身组排除掉。

本变更只把热身组纳入普通动作计划项。递减组和超级组继续不支持计划热身组，避免把热身语义扩散到复杂训练单元。

## Goals / Non-Goals

**Goals:**

- 普通动作计划项可定义前置热身组，每组有独立重量和次数。
- 计划详情弱化展示热身信息：正式组仍是主摘要，热身默认折叠。
- 从计划开始训练时，普通动作生成热身组和正式组，全部为未完成落值。
- 自适应模式能同步普通动作热身处方，但强度摘要仍只来自正式组。
- Team 分享和 Fork 保留热身结构与次数，清空重量。
- 不新增后端 schema、同步实体或 API。

**Non-Goals:**

- 不支持递减组热身。
- 不支持超级组热身轮或超级组内热身组。
- 不做自动热身算法、百分比推算、全局热身模板或推荐。
- 不改变训练统计、PR、历史曲线排除热身组的口径。

## Decisions

### D1. 复用 `PlanSetPrescription.isWarmup`

普通动作计划项继续使用 `setPrescriptions` 表达逐组处方：

```text
PlanItem(unitKind = singleExercise)
└─ setPrescriptions
   ├─ isWarmup = true   // 热身组
   └─ isWarmup = false  // 正式组
```

不新增 `warmupCount`、`warmupPrescriptions` 或独立 `WarmupPlan`。热身组数从 `setPrescriptions.filter(\.isWarmupEffective)` 派生。

原因：现有 jsonb 计划项已支持稳定 `itemId` 和逐组处方，后端同步只需透传 JSON；新增字段会增加兼容面但不提供必要收益。

### D2. 热身只对普通动作计划项生效

`PlanItem.unitKind == singleExercise` 时，`isWarmup` 有效。`dropSet` 和 `superset` 计划项不得展示热身入口，保存时也不得产生热身处方。

实现上需要在计划编辑、预填、回写、保存为模板、Team 去重量时统一过滤：

- 普通动作：保留 `setPrescriptions` 中的热身组。
- 递减组：只保留递减组结构和 segments，不保存热身标记。
- 超级组：只保留成员、轮数和成员默认处方，不保存热身轮。

这是产品边界，不是能力缺口。以后如果要支持复杂训练单元热身，应单独建 change。

### D3. 展示主摘要只看正式组

计划列表和计划详情的主摘要继续回答「下次正式训练怎么练」。热身只做次级摘要：

```text
卧推
下次 4 正式组 · 80 kg × 8
热身 2 组 · 20×10 / 40×5
```

热身明细默认折叠，避免普通用户一进计划编辑就看到复杂表格。只有用户添加或展开热身组时，才显示逐组重量/次数。

### D4. 自适应拆成执行处方口径和统计强度口径

当前 `countsForStats` 正确地排除热身，但计划预填不能只依赖它，否则会丢失热身流程。

本 change 引入两条逻辑口径：

- **执行处方口径**：普通动作的 completed 组，包含热身，用于下次预填和热身处方回写。
- **统计强度口径**：`countsForStats`，用于 PR、训练量、正式组数、`suggestedWeightKg/suggestedReps` 顶组摘要。

自适应回写普通动作时，系统先按执行处方口径保存热身和正式逐组处方，再按统计强度口径更新 `suggestedSets/suggestedWeightKg/suggestedReps`。本次只完成热身而没有正式组时，不更新强度摘要；已有正式处方不因这次跳过而被删除。

### D5. Team/Fork 保留结构、清空重量

热身组和正式组一样属于计划处方结构。复制、Fork、分享到 Team 时保留组序、热身标记和次数，清空所有重量字段。

这延续现有重量隐私规则：组数和次数用于计划结构，重量属于个人能力数据，不随分享扩散。

### D6. 同步仍走既有 LWW

计划热身处方仍是 `WorkoutPlan.items` jsonb 的一部分，随 `WorkoutPlan` 同步实体上传下载。同步字段、软删除、幂等键和 last-write-wins 规则不变：

- 不新增后端表。
- 不新增独立同步域。
- 不新增逐字段 merge。
- 计划项继续依赖稳定 `itemId` 定位。

## Risks / Trade-offs

- [Risk] 自适应历史预填如果仍只读 `countsForStats`，热身组会被丢失。
  Mitigation：为普通动作新增包含热身的执行处方读取路径，并用测试覆盖。

- [Risk] 计划总组数如果直接数全部 `setPrescriptions`，会把热身算进强度摘要。
  Mitigation：计划主摘要和 `totalSuggestedSets` 明确只统计正式组；热身组单独展示。

- [Risk] 递减组历史里可能已有 `isWarmup` 数据。
  Mitigation：计划侧保存和回写递减组时忽略热身标记，训练历史仍按原始记录保留。

- [Risk] Team 去重量递归清理漏掉热身处方重量。
  Mitigation：复用现有递归清理，并补充热身组处方测试。

## Migration Plan

1. iOS 先调整普通动作计划处方 helper：拆分热身/正式组、派生摘要、过滤递减组/超级组热身。
2. 更新计划编辑 UI，普通动作增加默认折叠的热身组区域。
3. 更新 `PlanPrefill` 和 `PlanWriteback`，确保普通动作自适应保留热身处方。
4. 更新 Team 分享、Fork、保存为计划模板的去重量和结构保留测试。
5. 运行 iOS 相关测试与 simulator build。

Rollback：如果 UI 风险过大，可先隐藏热身编辑入口；已写入的 `isWarmup` 处方仍随 jsonb 保留，旧逻辑会把它作为普通 set 处方读取，不破坏计划同步。

## Open Questions

无阻塞问题。默认执行当前边界：只做普通动作计划热身组，递减组和超级组不支持热身。
