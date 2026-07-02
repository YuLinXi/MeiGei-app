## Context

现有 `WorkoutSet` 是单一重量/次数结构，`WorkoutSetType` 只有 `working/warmup`。训练、统计、计划回写和 Team 打卡都围绕 `WorkoutSet.weightKg/reps` 重算。Workout 聚合子树没有独立同步信封，随 `Workout` 聚合根整树 push/pull，冲突仍由聚合根 `updatedAt` last-write-wins 决定。

用户希望 UI 上只出现「递减组」，但真实数据不需要判断递增、递减或混合方向。因此本设计把用户心智和数据语义分开：UI 文案为「递减组」，内部模型表达为「多段组」。

## Goals / Non-Goals

**Goals:**

- 训练中能快速新增递减组，并能从组级菜单把普通组切换为递减组。
- 递减组作为一个逻辑 `WorkoutSet` 参与排序、完成勾选、休息触发、备注、删除和同步。
- 递减组内部可记录多个有序 segment，每段有重量和次数。
- 统计、PR、历史曲线、计划回写、Team 打卡和海报按 segment 展开计算，逻辑组数仍按父级 set 计 1。
- 计划模板能保存、展示、预填和回写递减组处方；Team 分享/Fork 时保留结构但清空重量。
- 保持离线优先、Workout 聚合 LWW、Plan 同步域 LWW、Team 服务端权威的既有边界。

**Non-Goals:**

- 不做递增组、混合组等独立 UI 或持久化类型。
- 不校验 segment 重量必须递减。
- 不做热身递减组组合；热身与递减组互斥。
- 不新增 segment 独立同步实体，不做逐 segment 冲突合并。
- 不为递减组新增服务端写接口。

## Decisions

### 1. 内部类型用 `drop`，语义按“多段组”处理

`WorkoutSetType` 新增一个正式类 case，建议 raw value 为 `drop`，UI 显示「递减组」。虽然内部实现按多段组处理，但 raw value 使用短稳定的产品域词，便于 DTO、DB、日志和人工排查。

备选方案是 `multiSegment`。放弃原因是 raw value 会泄漏到同步 payload 和后端数据，面向排障不如 `drop` 直观。为避免误加递减校验，代码注释和 helper 命名使用 `segments` / `statEntries`，不使用 “mustDecrease” 语义。

### 2. segment 存在父级 `WorkoutSet` 内，不独立成表

iOS `WorkoutSet` 增加 `[WorkoutSetSegment]`，后端 `workout_set` 增加 `segments jsonb NOT NULL DEFAULT '[]'::jsonb`。

```text
WorkoutSet
├─ setType = working | warmup | drop
├─ weightKg / reps          // 兼容摘要
├─ completed / rest / note  // 父级生命周期
└─ segments[]               // 递减组真相
   ├─ segmentId
   ├─ segmentIndex
   ├─ weightKg
   └─ reps
```

理由：

- Workout 子树本来就是聚合整体替换，jsonb segment 不引入新同步单元。
- segment 不需要被独立查询、软删或 LWW 合并。
- 父级 set 继续承载完成、休息、备注和组序，符合“递减组是一组”的用户心智。

备选方案是新增 `workout_set_segment` 表。放弃原因是当前服务端并不对 workout 子树做局部查询，单独表会增加 mapper、删除级联和 DTO 复杂度，而不会提高当前功能正确性。

### 3. 父级 `weightKg/reps` 是兼容摘要，segments 是真相

普通组和热身组继续使用父级 `weightKg/reps`。递减组以 `segments` 为真相，并在每次 segment 变化时同步写父级摘要：

- `weightKg` 写有效 segments 中最大重量。
- `reps` 写该最大重量 segment 的 reps；无重量时取第一个有效 segment 的 reps。

理由：旧客户端或旧统计代码至少能看到一个合理顶组摘要；新统计必须走统一 helper 展开 segments。

### 4. 统计统一通过 `statEntries`

新增统一派生：

```text
WorkoutSet.statEntries
```

规则：

- `warmup` 或 `completed == false`：空。
- `drop`：返回所有有效 segment（至少有重量或次数，且 reps > 0 时才参与 PR/容量）。
- 其它正式组：返回父级 `weightKg/reps`。

所有 PR、训练量、总次数、历史曲线、训练详情聚合、Team 摘要、海报、计划回写都必须使用这个 helper。逻辑组数仍用 completed 且非 warmup 的父级 set 数。

### 5. 录入交互：底部并列入口 + 组菜单切换

动作卡底部把单一「加一组」改为两按钮：

```text
[递减组]        [加一组]
```

- 「加一组」保留当前普通组行为。
- 「递减组」新增 `setType=drop` 的父级 set，默认 2 段：第 1 段预填上一正式组重量/次数，第 2 段为空；无上一正式组时第 1 段也为空。
- 组级 `⋯` 菜单增加「改为递减组」和「改回普通组」。
- 普通组改递减组：父级重量/次数转为第 1 段，再补第 2 段。
- 递减组改普通组：用第一个有效段回填父级，丢弃其它段；因会丢数据，需要二次确认。
- 热身与递减组互斥：热身组菜单不直接提供改为递减组；递减组菜单不提供标为热身组。

### 6. 数字键盘焦点扩展到 segment

现有 `FocusedCell` 只定位 set 重量/次数。本 change 需要支持：

```text
set weight/reps
segment weight/reps
```

同一动作内焦点序列改为按展示顺序展开：

```text
普通组: set.weight → set.reps
递减组: segment0.weight → segment0.reps → segment1.weight → segment1.reps → ...
```

键盘「加一组」在 segment 焦点内保持为新增普通组，不改变现有键名；递减组内部使用行内「添加一段」按钮添加 segment。

### 7. 计划处方用可选 `setPrescriptions`，兼容现有 `suggested*`

`PlanItem` 增加：

```text
setPrescriptions?: [PlanSetPrescription]
```

每个处方包含稳定 `prescriptionId`、`setType`、`orderIndex`、普通组重量/次数或递减组 segments。缺失时继续使用现有 `suggestedSets/suggestedReps/suggestedWeightKg` 生成普通组。

严格模式：

- 若存在 `setPrescriptions`，按处方生成组，包括递减组 segments。
- 若不存在，继续按 `suggested*` 生成普通组。

自适应模式：

- 优先使用上次 completed 正式组结构，包括递减组。
- 无历史时回退 `setPrescriptions`。
- 再无则回退 `suggested*` / 默认 4 组。

保存为计划和自适应回写都写入 `setPrescriptions`，同时保留 `suggestedSets/suggestedReps/suggestedWeightKg` 作为列表摘要和旧端兼容。

### 8. Team 计划分享保留结构但清空重量

Team 计划分享仍是服务端权威版本快照。`TeamPlanService.stripWeights` 必须递归清理：

- `suggestedWeightKg` / `suggestedWeight` / `weightKg` / `weight`。
- `setPrescriptions` 内普通组重量。
- `setPrescriptions[].segments[]` 内重量。

Fork 后成员得到递减组结构、组数和次数，但所有重量为空，符合现有隐私规则。

### 9. Day-1 铁律适配

- 身份三层不变，本 change 不新增身份字段。
- 写接口不变，继续通过同步 push 与 Team REST 的既有幂等机制。
- 同步对象不新增：Workout/WorkoutPlan 继续拥有 `localId/serverId/updatedAt/deletedAt/version`。
- 冲突策略不变：Workout 聚合与 Plan 均 last-write-wins，不做 segment merge。
- 统计不入库：PR、曲线、容量仍由原始 Workout/segments 重算。
- Plan jsonb 中新增的处方项和 segment 必须有稳定 id。
- 离线优先不变：本地先写 SwiftData，`markDirty` 后由 SyncEngine 上传。

## Risks / Trade-offs

- [Risk] 旧客户端编辑同一 workout 后上传会丢失 segments。  
  Mitigation：父级摘要保留顶组；新能力仅承诺新客户端完整保真，发版说明中明确跨版本限制。

- [Risk] 统计调用点多，遗漏某处会造成数字不一致。  
  Mitigation：抽 `statEntries` / 逻辑组计数 helper，并用单元测试覆盖 PR、周统计、历史快照、计划回写、Team 摘要。

- [Risk] 计划处方字段会扩大 jsonb payload。  
  Mitigation：只存必要字段；旧 `suggested*` 仍作为摘要，不复制冗余统计。

- [Risk] SwiftData 直接新增 `[WorkoutSetSegment]` 需要轻量迁移稳定。  
  Mitigation：沿用现有 `PlanItem` Codable 数组模式；默认空数组，解码失败兜底空数组。

- [Risk] 递减组 UI 增加行高，训练中页面更拥挤。  
  Mitigation：展开态显示完整分段，折叠/详情摘要显示 `80×8 / 60×6` 或 `80×8 +2段`。

## Migration Plan

1. 后端先发 Flyway，给 `workout_set` 增加 `segments` jsonb 默认空数组；旧数据天然兼容。
2. iOS 更新模型与 DTO，旧 payload 解码为普通组或空 segments。
3. 发布新 iOS 后，递减组在新端完整录入和同步；旧端只可通过父级摘要看到顶组。
4. 如需回滚 iOS，后端保留 segments 列无害；旧端继续忽略该字段。

## Open Questions

无阻塞问题。命名决策按本设计执行：UI 叫「递减组」，内部 raw type 使用 `drop`，不做方向识别和递减校验。
