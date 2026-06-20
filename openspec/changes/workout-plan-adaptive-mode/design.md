# 设计说明：训练计划严格 / 自适应模式

## 背景与目标

把「从计划开始训练」从「只决定组数、重量次数留空、完成后不反哺」升级为两种清晰心智的模式，并让自适应模式的计划随实绩进化。所有决策围绕一条统一哲学：**计划是只增不减的用户资产，实绩可以更新它，但不能替用户做减法。**

```
            严格模式 (Strict)            自适应模式 (Adaptive, 默认)
计划角色    权威剧本 (只读)              活文档 (双向)
数据流      计划 ──整组复制──▶ 训练      计划 ⇄ 训练 (完成后 upsert 回写)
必填        动作 + 组数 + 次数           仅 动作
开始训练    全字段落值                   首次/无历史用计划值落值
完成回写    ✗ 不回写                     ✓ upsert + max + 顶组代表值
```

## 决策 1：预填用「落值」而非「占位 placeholder」

**决定**：开始训练时把预填值真正写进 `WorkoutSet.weightKg/reps`，`completed=false`。

**理由**：符合预期时用户「只需打勾、无需重输」，这是相对灰字占位的核心体验红利；也让 `buildFromPlan` / 加组逻辑统一为「落值」。

**代价（必须配套处理）**：落值打破了「nil = 没做」这一天然判据，「有值」与「做了没」必须全部由 `completed` 承载，引出决策 2 与决策 6 两条铁律。

## 决策 2（铁律）：统计与历史只认 `completed`

**现状（核实结论）**：`WorkoutSet.countsForStats` 当前 = `setType != .warmup`，**不含 completed**。`PRStats` / `WorkoutWeeklyStats` / `ExerciseViews` 历史曲线均靠它（+ `reps>0` 兜底）过滤。今天不出事仅因「未完成组 = nil」被 `compactMap`/`reps>0` 自然滤掉。

**风险**：落值后未打勾的预填组 `reps>0`，会被训练量与 PR 误计入 → 直接虚增统计。

**决定**：`countsForStats` 收紧为 `setType != .warmup && completed`。这是单点修改，一次性让所有用它的口径变安全。同样地，自适应回写的「本次实绩」也只取 `countsForStats` 的组。

**待验证（Open）**：复查所有 `countsForStats` 调用点（`Workout/WorkoutViews.swift:206`、`Workout/WorkoutDetailView.swift:291` 等），确认加 `completed` 后无「展示热身/正式区分」之类纯 UI 用途被误伤；纯展示判断应直接用 `setType` 而非 `countsForStats`。

## 决策 3：`planItemId` 作为回写合并主键

**问题**：`Workout.planId` 只到计划级；`WorkoutExercise` 不知道自己来自哪个 `PlanItem`。靠 `exerciseName/code` 反查会在「同名动作 / 改过名」时写错项。

**决定**：`WorkoutExercise` 增 `planItemId: UUID?`，`buildFromPlan()` 把 `item.itemId` 带入；训练中临时新增的动作 `planItemId = nil`。回写时：

```
有 planItemId → UPDATE 对应 PlanItem
无 planItemId → INSERT 新 PlanItem (新增动作)
```

这是自适应模式的地基，严格模式不需要它（严格不回写）。

## 决策 4：自适应回写合并规则

**仅统计本次 `completed` 的正式组**（`countsForStats` 为真的组）。

```
遍历本次训练每个 WorkoutExercise:
  ├─ 有 planItemId  → UPDATE 对应 PlanItem:
  │     suggestedSets   = max(计划现值, 本次 completed 正式组数)   ← 只增不减
  │     suggestedWeightKg, suggestedReps = 顶组代表值              ← 如实写回
  └─ 无 planItemId  → INSERT 新 PlanItem (append 末尾, 按 historyKey 去重)
  计划有 / 训练无 的 PlanItem → 保留不动 (永不自动删)             ← 只增不减
```

### 决策 4a：动作 / 组数「只增不减」，重量 / 次数「如实写回」的不对称

这是有意为之、非 bug：

- 「今天没练某动作」≠「想从计划删它」 → 动作保留。
- 「今天某动作只做 3 组」是明确的强度信号 → 但取 `max`，**不让 deload 抹掉历史最多组数这个成就**。
- 「逐维度对重量/次数也取 max」会**合成虚构最佳**（例：上次 `5×8×60`、这次 `3×8×70`，逐维度 max → `5×?×70`，一个从没做到过的组合，作为下次预填会超能力）。故重量/次数**不取 max**，如实跟随最近真实强度，允许下降。

### 决策 4b：重量/次数的「顶组代表值」

`PlanItem` 是单值结构（每动作一组 `suggestedSets/Reps/WeightKg`），而本次有多组。需把多组汇成一个代表值。

**决定**：取本次 completed 正式组中**最大重量那一组**的 `(weightKg, reps)` 作为 `suggestedWeightKg/suggestedReps`（工作组顶组）。例：`60×8, 60×8, 65×5` → 回写 `65kg / 5 次`，组数与现值取 max。

**取舍**：相比「最后一组 / 众数 / 平均」，顶组最能代表「这次的工作强度」，且与 PR 口径（按最大重量）一致，用户心智统一。

### 决策 4c：新增动作的排序与去重

- **排序**：append 到计划末尾，不插入原结构中间，避免扰乱计划顺序。
- **去重**：用 `historyKey`（`builtinExerciseCode ?? customExerciseId?.uuidString ?? exerciseName`）判重——若训练中新增动作的 key 命中计划里某个 `PlanItem`，认成「更新该项」而非「新增重复项」，避免计划长出重复动作（覆盖「先删了又手动加回」的边界）。

## 决策 5：透明回执 + 撤销

物理回写最大的体验风险是「我的计划怎么自己变了」。

**决定**：完成训练页展示逐项 diff 回执，并提供「撤销此次更新」（回写前对 `WorkoutPlan` 做快照，撤销即还原 + 重新 `markDirty`）。

```
┌─────────────────────────────────┐
│ 已根据本次训练更新「推日」计划:  │
│   卧推     60kg×8  →  65kg×5     │  (改值)
│   飞鸟     新增 ✚               │  (append)
│   过顶推举 未做, 已保留          │  (不动)
│            [撤销此次更新]        │
└─────────────────────────────────┘
```

严格模式无回执（不回写）。

## 决策 6：完成训练时清理未打勾组

落值会留下「预填了但没做」的残组。**决定**：结束训练时丢弃未 `completed` 的组，训练记录与回写都只含真实发生的数据。决策 2 的统计铁律是「即使没清理也不会算错」的安全网，清理则进一步保证记录干净。

**待确认（Open）**：清理策略采「静默丢弃」（推荐）还是「弹窗确认」。当前按静默丢弃落规格，如需提示可在实现阶段加。

## 决策 7：默认自适应

**决定**：新建计划默认 `adaptive`，但新建页直接展示严格 / 自适应两个模式选项与说明，说明文案与计划详情里的模式编辑 sheet 保持一致。理由：自适应仅「动作」必填，建计划零门槛（列几个动作就能练、之后自动长起来）；严格模式「组数+次数必填」门槛高，作为「我要照剧本」的主动选择更合适。

## 决策 7a：计划展示不再估算时长

**决定**：计划列表与计划详情不展示「预计时长」。原先用 `suggestedSets * 130s` 推导出的分钟数缺乏真实来源，容易给用户错误承诺；计划卡片与详情三联数保留动作数、总组数，并把原预计时长位置替换为当前计划模式（严格 / 自适应）。

实际完成训练的真实时长、周统计平均时长不受影响，因其来自 `startedAt/timerStartedAt/endedAt`，不是估算值。

## 决策 7b：新增计划动作默认 4×10

**决定**：计划详情中添加动作时，直接写入 `suggestedSets=4`、`suggestedReps=10`，重量留空；`PlanItemEditorView` 的新项默认值也为 4 组、10 次。自适应计划无历史且计划项缺组数时，开始训练 fallback 组数为 4。

这让「添加动作」后的计划行立即可训练：从计划开始训练会直接生成 4 个未完成组，每组预设 10 次（重量可空）。

## 决策 8：Fork 只带结构、不带重量

**决定**：Fork / 复制为新计划 / Team 模板时，复制 **动作 + 组数 + 次数，重量清空**，新计划默认自适应。

**连带收益**：重量最私人（每人力量不同），不 Fork 既避免「队友拿到我的私人重量」，又**消除了「物理回写抹掉初始值」的隐患**——无需为 PlanItem 额外保存 `initial*` 字段。

## 模式切换的迁移语义

- 严格 → 自适应：已有计划值作为初次落值来源，之后开始被实绩驱动，无损。
- 自适应 → 严格：把当前（已进化的）计划值「冻结」为剧本；若此时某动作缺次数（自适应可不填），切换时 SHALL 提示补齐严格模式必填项。

## 同步与多设备

- `WorkoutPlan.mode` 是计划级字段，走同步域 LWW（按 `updatedAt`）。
- 自适应回写 = 对 `WorkoutPlan` 的一次本地编辑（`markDirty` + save），下次 `syncAll` 正常 LWW 上行——不新增特殊同步路径。
- 训练记录动 `Workout` 域、回写动 `WorkoutPlan` 域，二者是不同同步实体：「手机训练完回写计划」与「另一设备手动编辑计划」只会在 `WorkoutPlan` 域按 `updatedAt` LWW 裁决，不会与训练记录互相打架。

## Open Questions（待实现阶段收口）

1. **countsForStats 加 completed 的调用点副作用**：见决策 2 待验证，需逐点复查。
2. **未打勾组清理**：静默 vs 弹窗确认（当前规格取静默）。
3. **Flyway 版本号**：与并行的 `workout-set-type-warmup`（占 V4）等 in-progress change 协调，取下一个可用号。
