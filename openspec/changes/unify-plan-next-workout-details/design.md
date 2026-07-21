## Context

`PlanDetailView` 已通过 `refine-plan-exercise-card-details` 形成“折叠卡快速扫读、详情卡按需展开”的结构。普通动作和递减组的详情目前分别渲染静态 `PlanItemDisplay.planGroups` 与动态 `PlanPrescriptionPreview.sets`：前者只显示计划次数，后者只显示下次重量。同一组次因此出现两遍，而且自适应预填实际上会从历史复制完整组快照，静态次数不一定等于真正开始训练时的次数。

计划构建已有明确的单一事实来源：普通动作和递减组由 `PlanPrefill.sets` 生成，`PlanPrescriptionPreview.make` 复用同一规则；超级组由 `PlanWorkoutBuilder` 直接按 `PlanItem.supersetRounds` 与成员 `suggestedWeightKg/suggestedReps` 生成。本 change 只重组纯展示派生，不新增持久化字段，也不改变 `WorkoutPlan` jsonb、稳定 `itemId`、同步信封、软删除、幂等或 LWW 边界。

本 change 以 `refine-plan-exercise-card-details` 的最终交互为基线。归档 OpenSpec 时应先归档该基线 change，再归档本 change，避免需求重命名顺序冲突。

## Goals / Non-Goals

**Goals:**

- 让展开详情直接回答“现在点击开始后，这个动作会生成什么训练安排”。
- 在同一行组合组次、重量与次数，避免用户跨两个列表自行配对。
- 对普通组、热身组、递减组和超级组保持真实结构，并与训练构建结果一致。
- 仅在静态模板与实际下次安排不同时显示紧凑对照，不重复完整模板表。
- 保持现有展开手势、原生 `List`、稳定行身份和无大面积布局动画。

**Non-Goals:**

- 不改变自适应历史优先、严格模式复制、实绩回写或开始训练校验。
- 不改变任何模型、同步 payload、后端 API、数据库或 Flyway。
- 不调整计划列表、训练进行中、已完成训练、Team 分享计划或海报。
- 不解决“手动编辑自适应模板是否应覆盖历史”的独立产品决策。
- 不增加详情内二级折叠、横向表格或新的交互模式。

## Decisions

### D1. 展开详情以实际训练构建数据为主

普通动作与递减组继续调用 `PlanPrescriptionPreview.make(for:mode:lookup:planId:)`，再把 `preview.sets` 转换成现有 `PlanItemGroupDisplay`。每个 `PlanItemGroupValue` 已同时包含 `weightKg` 与 `reps`，详情行一次性渲染完整值，不再分别遍历静态组与下次组。

严格模式同样使用 preview 中按计划复制的 sets，只把标题显示为“训练安排”并附带“严格模式 · 完成后不更新”。这样严格与自适应共用一条详情渲染路径，但数据来源仍遵守各自既有规则。

备选方案是继续保留两块列表并缩小间距；它不能消除次数与实际预填不一致，也仍要求用户跨区配对，因此不采用。

### D2. 来源标签与完整安排共享同一 preview

自适应详情标题使用“下次训练安排”，在标题附近显示 `preview.badgeText`，并以次级文案显示 `preview.detailText`。来源、组数、重量和次数都来自同一个 preview，禁止在视图层分别重新查询历史或推导另一套来源。

来源信息不单独占用一个大区块，也不在每个组行重复，避免历史日期挤压训练数据。

### D3. 静态模板只在有语义差异时作为一行基准

新增纯展示比较函数，将 `PlanPrefill.plannedSets(for:)` 与 preview sets 规范化后比较：

- 比较组顺序、组类型、热身属性、重量、次数；
- 递减组继续比较全部有序 segment 的重量与次数；
- 忽略 `UUID`、本地身份和其他不影响训练落值的字段。

仅当两者存在语义差异时，在详情底部显示“模板基准”单行摘要；相同则完全隐藏。摘要优先表达组数、次数和可真实概括的统一重量；逐组值不同或递减结构复杂时使用“各组设置不同”等诚实文案，不选取一个虚假代表组。模板基准不再展开为第二份组表。

备选方案是始终显示模板基准；在首次训练或严格模式下它与主安排完全重复，增加视觉噪音，因此不采用。

### D4. 不同训练单元使用同一阅读语法

- 普通组/热身组：左侧显示组类型与序号，右侧显示 `重量 × 次数`。
- 递减组：先显示逻辑组标题，再逐段显示完整 `重量 × 次数`，不得把 segments 合并成一个代表值。
- 超级组：显示统一轮数；每个成员一行显示动作名和完整 `重量 × 次数`；最后显示轮后休息。展示值直接来自 `PlanWorkoutBuilder` 当前使用的成员字段，不为超级组另造普通动作历史 preview。

普通组与递减组继续使用 `PlanItemDisplay` 的纯展示结构；超级组继续使用 `PlanItemDisplay.supersetMembers`，只调整组合文案与布局。备选动作保留在完整安排之后。

### D5. 空重量按动作语义显示

展示层使用 `resolvedEquipmentType` 判断明确的 `EquipmentType.bodyweight`：重量为空时显示“自重”。其他允许空重量的动作显示“训练时填写”，不把可选值误报为配置错误。组数或次数不满足严格模式要求时仍沿用既有“未设置”展示与开始训练拦截。

该规则只改变文案，不把“自重”写成 `0 kg`，也不修改训练量统计或保存数据。

### D6. 保留现有展开与同步边界

`expandedItemId`、独立 `List` 行、无显式布局动画、动作菜单与删除确认均保持不变。所有新增比较与格式化均为内存中的纯展示派生，不调用 `markDirty`、不保存 SwiftData、不触发同步，也不影响身份三层、幂等键、同步字段和软删除规则。

## Risks / Trade-offs

- [Risk] 模板与 preview 的比较若遗漏 warmup 或 segment 字段，会错误隐藏模板差异。→ 使用规范化快照比较并覆盖普通组、热身组、递减组测试。
- [Risk] 一行同时显示重量与次数后，在较大 Dynamic Type 或长数值下可能换行。→ 允许值文本自然换行或转为上下布局，禁止横向滚动与截断关键数值，并做 Simulator 辅助功能字号回归。
- [Risk] “自重”判断依赖动作器械分类质量。→ 只对明确等于 `EquipmentType.bodyweight.rawValue` 的动作显示“自重”，未知类型仍显示“训练时填写”。
- [Risk] 超级组缺少普通动作式的独立历史 preview。→ 严格复用 `PlanWorkoutBuilder` 真实读取的成员字段，不在本 change 扩展历史规则。
- [Trade-off] 隐藏相同模板基准减少重复，但用户无法在详情中看到两份相同数据。→ 主安排已经是完整值，折叠卡继续提供静态摘要，编辑入口仍可查看和修改模板。

## Migration Plan

随 iOS 客户端正常发布，无数据迁移和后端部署顺序要求。旧计划直接使用既有 `PlanItem` 与训练历史生成新展示。回滚仅恢复原详情布局，不影响计划数据、训练历史或同步状态。

OpenSpec 归档顺序为：先归档 `refine-plan-exercise-card-details`，再归档 `unify-plan-next-workout-details`。

## Open Questions

无。本 change 明确保留当前自适应历史优先规则；手动编辑覆盖语义如需调整，应另建行为 change。
