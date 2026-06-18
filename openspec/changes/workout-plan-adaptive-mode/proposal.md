## Why

当前「从计划开始训练」的预填很弱：`buildFromPlan()` 只用 `suggestedSets` 决定组数（缺省 3），**重量/次数一律留空**，连计划项里已存的 `suggestedReps/suggestedWeightKg` 都被丢弃；训练完成后也**不会把实绩反哺回计划**。后果是计划永远停在「初次填写时的静态预设」，既不能照剧本严格执行（重量次数不预填），也不能跟随用户进步（练得再重，计划数字纹丝不动）。竞品（《训记》《One More》及 Strong/Hevy 一脉）的共识是「计划提供结构、历史/实绩提供数值锚点」，让每次训练都站在上次的肩膀上。

本 change 给训练计划引入**两种模式**，把「计划是死剧本还是活文档」做成用户可见、可选的开关：

- **严格模式（Strict）**——计划是权威剧本，开始训练时把预设（组数/次数/重量）**整组复制落值**，照着练、打勾确认；完成后**不回写**计划。适合跟练 / 康复 / 教练给定的固定课表。
- **自适应模式（Adaptive，默认）**——计划是活文档，首次用计划预设落值，之后用户**完成训练后实绩自动 upsert 回写计划**，计划跟着人一起变强。适合自由训练、追求渐进超负荷的大众。

回写遵循一条统一哲学——**计划是只增不减的成就板，实绩只能往上顶它，任何减法都得用户亲手到计划里做**：动作只增不减（训练里新增的并入计划、跳过的保留不删）、组数只增不减（取历史与本次的较大值）；而重量/次数如实跟随最近真实强度（可升可降，不合成虚构最佳）。

## What Changes

- **预填改为「落值」而非占位**：开始训练时把预填值**真正写进** `WorkoutSet.weightKg/reps`（`completed=false`），用户符合预期时只需打勾、无需重输；「有值」与「做了没」彻底由 `completed` 区分。
- **计划新增模式字段**：`WorkoutPlan` 增 `modeRaw: String`（默认 `"adaptive"`），由可扩展枚举 `WorkoutPlanMode { strict, adaptive }` 承载（raw-string 存储，复刻 `SyncStatus`/`setTypeRaw` 风格）。
- **严格模式**：必填 = 动作 + 组数 + 次数（重量选填）；`buildFromPlan()` 按 `suggestedSets` 建组并**整组落值** `suggestedReps/suggestedWeightKg`；完成训练不触发回写。
- **自适应模式（默认）**：必填 = 仅动作；首次/无历史时用计划预设落值；完成训练后对来源计划做一次 **upsert 合并回写**（规则见下）。
- **动作级来源 id（合并地基）**：`WorkoutExercise` 增 `planItemId: UUID?`，`buildFromPlan()` 把 `PlanItem.itemId` 带入；训练中临时新增的动作 `planItemId = nil`。它是区分「更新已有项 / 新增项」的合并主键。
- **自适应 upsert 回写规则**（仅统计 `completed` 的正式组）：
  - **动作**：只增不减。训练含、计划无（`planItemId == nil`）→ append 到计划末尾（按 `historyKey` 去重）；计划含、训练无 → 保留不动（永不自动删）。
  - **组数**：只增不减。`suggestedSets = max(计划现值, 本次 completed 正式组数)`。
  - **重量/次数**：如实写回（可升可降）。取本次 completed 正式组中**最大重量那一组**的 `(weightKg, reps)` 作为 `suggestedWeightKg/suggestedReps`。
- **透明回执 + 撤销**：完成训练页展示「已根据本次训练更新『X』计划」的逐项 diff（改值 / 新增 / 已保留），并提供「撤销此次更新」入口，把隐式跨域副作用变成用户可见、可反悔的动作。
- **完成训练时清理未打勾组**：自适应落值后，未 `completed` 的预填残留组在结束训练时被丢弃，保证训练记录与回写均为真实发生的数据。
- **统计口径收紧（必须，落值前提）**：`WorkoutSet.countsForStats` 从 `setType != .warmup` 收紧为 `setType != .warmup && completed`。否则落值后未打勾的预填组（`reps>0`）会被 PR / 周训练量误计入。
- **Fork 语义**：自适应计划被实绩浸透后，Fork（复制为新计划 / Team 模板）**只带 动作 + 组数 + 次数，重量清空**（重量最私人，每人力量不同），Fork 出的新计划默认自适应模式。

## Capabilities

### New Capabilities
<!-- 无新增 capability -->

### Modified Capabilities
- `workout-tracking`: 新增「训练计划模式（严格 / 自适应）」「自适应模式实绩回写计划」「开始训练预填落值与未打勾组清理」「计划 Fork 字段规则」四条 requirement；修改「计划详情版式」（模式标识与说明）、并将「统计仅计正式组」口径收紧为「正式组且已完成」。

## Impact

- **数据模型（iOS）**：`Models/WorkoutPlan.swift` 加 `modeRaw` + `WorkoutPlanMode` 枚举；`Models/Workout.swift` 的 `WorkoutExercise` 加 `planItemId: UUID?`，`WorkoutSet.countsForStats` 收紧为 `setType != .warmup && completed`。
- **开始训练（iOS）**：`Workout/PlanViews.swift` 的 `buildFromPlan()` 改为带 `itemId`、按模式落值（严格全落值 / 自适应首次落值）。
- **完成训练（iOS）**：结束训练流程新增「自适应回写 + 未打勾组清理」步骤；新增回写合并器（upsert + max + 顶组代表值）与「撤销」快照。
- **回执 UI（iOS）**：完成训练页新增计划更新 diff 卡 + 撤销按钮；计划详情页加模式标识与说明。
- **统计（iOS）**：`countsForStats` 收紧后，`PRStats` / `WorkoutWeeklyStats` / `ExerciseViews` 历史曲线自动只计已完成正式组；需复查所有 `countsForStats` 调用点确认加 `completed` 无展示副作用（详见 design 待验证项）。
- **数据模型（后端）**：`workout_plan` 加 `mode text NOT NULL DEFAULT 'adaptive'`；`workout_exercise` 加 `plan_item_id uuid NULL`（顺延下一个可用 Flyway 版本号，注意与并行的组类型 change 不冲突）；对应实体加字段，随聚合树 / 同步 DTO 上线。
- **同步契约**：`WorkoutPlan` 仍走同步域（jsonb items + 计划级字段 LWW）；回写是对 `WorkoutPlan` 的本地编辑 → `markDirty` → 正常 LWW 上行。`WorkoutExercise.planItemId` 随 workout 聚合整树全量替换，无独立信封。
- **Team（联动）**：Fork / 复制为新计划处按「带动作+组数+次数、清空重量、默认自适应」执行。
- **非影响**：不改休息计时 / Live Activity；不引入 e1RM 估算或「整组取优」的综合最优算法；不做计划的周期化 / 周计划结构。

## Non-goals

- **不做**「整组取优」（按 e1RM/volume 选最强一组整体写回）——重量/次数采用「最大重量顶组」单一代表值即可，不引入估算模型。
- **不做**重量/次数的「只增不减」——它们如实跟随最近真实强度，允许 deload 下降，不合成虚构最佳组合。
- **不做**计划动作的自动删除——跳过的动作永远保留，删除一律由用户在计划模板内手动操作。
- **不做**逐组明细回写——`PlanItem` 维持单值结构（每动作一组 `suggestedSets/Reps/WeightKg`），不为计划项引入逐组数组。
- **不做** Fork 时携带重量 / 历史实绩——Fork 只复制可共享的计划结构。
- **不做**严格模式的「锁定输入」——严格仅约束「初始预填来源为整组复制」，临场仍可改值与打勾。
