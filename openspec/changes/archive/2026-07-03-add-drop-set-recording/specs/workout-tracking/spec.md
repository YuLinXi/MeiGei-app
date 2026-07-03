## ADDED Requirements

### Requirement: 递减组录入与内部组记录

系统 SHALL 支持「递减组」作为训练中单组记录的一种正式类组型。递减组在 UI 中 MUST 始终显示为「递减组」，但系统 MUST NOT 校验、推断或持久化其真实重量方向；递增、递减或混合输入均 SHALL 只作为用户录入的有序内部组保存。

递减组 MUST 是一个父级 `WorkoutSet`：组编号、完成勾选、组间休息、备注、删除、排序和同步均作用于父级 set。递减组内部 SHALL 包含一个或多个有序内部组，每个内部组至少包含稳定 `segmentId`、`segmentIndex`、`weightKg` 与 `reps`。递减组与热身组 MUST 互斥；递减组 SHALL 作为正式类组计入统计。

动作卡底部 SHALL 在「加一组」左侧并列展示「递减组」快速添加入口。每组右侧更多操作菜单 SHALL 支持普通组改为递减组，以及递减组改回普通组。

#### Scenario: 快速新增递减组
- **WHEN** 用户在某动作卡底部点击「递减组」
- **THEN** 系统在该动作末尾新增一个父级 `WorkoutSet`
- **AND** 该组 UI 显示为「递减组」
- **AND** 该组默认包含至少 2 个内部组
- **AND** 若存在上一正式组，首个内部组预填上一正式组的重量与次数

#### Scenario: 普通组改为递减组
- **WHEN** 用户在普通正式组右侧更多操作里选择「改为递减组」
- **THEN** 系统将该父级 set 标记为递减组
- **AND** 原普通组的 `weightKg/reps` 成为第 1 个内部组
- **AND** 系统追加一个空白内部组供继续录入

#### Scenario: 递减组改回普通组
- **WHEN** 用户在递减组右侧更多操作里选择「改回普通组」并确认
- **THEN** 系统使用第一个有效内部组回填父级 `weightKg/reps`
- **AND** 其它内部组被移除
- **AND** 该组恢复为普通正式组

#### Scenario: 不校验递减方向
- **WHEN** 用户在递减组内录入 `50kg×10、60kg×8、55kg×6`
- **THEN** 系统保存这些有序内部组
- **AND** 不提示方向错误、不自动改名为递增组或混合组

#### Scenario: 递减组与热身组互斥
- **WHEN** 某组已被标为热身组
- **THEN** 该组更多操作不直接提供「改为递减组」
- **AND** 用户需要先改回普通组后才能改为递减组

### Requirement: 递减组统计、PR 与历史曲线

系统 SHALL 将递减组作为 1 个逻辑正式组计数。训练量、总次数、PR、历史曲线、训练详情聚合、分享海报和 Team 打卡容量 MUST 按递减组有效内部组展开计算。未完成递减组、空白内部组、热身组 MUST NOT 计入统计。

系统 MUST 提供统一的统计派生口径，使普通组、热身组与递减组在 PR、周统计、历史快照、计划回写和 Team 摘要中得到一致结果。统计数据 MUST 可由原始 `WorkoutSet` 与内部组重算，MUST NOT 持久化冗余统计。

#### Scenario: 递减组计为一个逻辑组
- **WHEN** 用户完成一个递减组，内部组为 `80kg×8、60kg×6、45kg×8`
- **THEN** 已完成组数增加 1
- **AND** 训练量增加 `80*8 + 60*6 + 45*8`
- **AND** 总次数增加 `8 + 6 + 8`

#### Scenario: 递减组刷新 PR
- **WHEN** 用户完成一个递减组，内部组中最大重量超过该动作历史最大重量
- **THEN** 系统按该最大重量识别 PR
- **AND** PR 庆祝、动作库 PR 副标和动作历史摘要使用同一最大重量

#### Scenario: 未完成递减组不计统计
- **WHEN** 用户录入递减组内部组但未勾选完成
- **THEN** 该递减组及其所有内部组不计入训练量、总次数、PR 或历史曲线

#### Scenario: 空白内部组不计统计
- **WHEN** 递减组包含一个完全空白内部组
- **THEN** 系统保存或清理该空白内部组时不让它影响训练量、总次数或 PR

### Requirement: 递减组详情、海报与 Team 打卡展示

训练详情、训练分享海报、Team 打卡摘要和 Team 打卡详情 SHALL 展示递减组内部组信息。紧凑位置 MAY 展示递减组摘要（如 `80×8 +2组`），详情位置 MUST 能展示每个有效内部组的重量与次数。

Team 打卡摘要 MUST 在结构化 payload 中保留递减组 set type 与 segments。旧摘要缺少 set type 或 segments 时，客户端 MUST 按普通组兼容展示。

#### Scenario: 训练详情展示递减组流水
- **WHEN** 用户打开包含递减组的已完成训练详情
- **THEN** 对应组显示「递减组」标识
- **AND** 展示该组的所有有效内部组

#### Scenario: 海报展示递减组摘要
- **WHEN** 用户为包含递减组的训练生成分享海报
- **THEN** 动作高光行使用递减组最大重量内部组作为顶组
- **AND** 文案能表达该组含额外内部组

#### Scenario: Team 打卡保留内部组
- **WHEN** 用户自动或手动分享一条包含递减组的训练到 Team
- **THEN** checkin summary 中该组包含 set type 与内部组列表
- **AND** Team 成员查看时能看到递减组内部组

### Requirement: 递减组同步与兼容

Workout 同步 SHALL 保留递减组内部组。后端 SHALL 持久化 `workout_set.segments`，并在 Workout 聚合 push/pull 中原样收发。旧训练记录缺少 segments 时 MUST 按空数组处理；旧计划缺少 set prescriptions 时 MUST 按现有 `suggested*` 字段处理。

递减组不 SHALL 拥有独立同步信封。Workout 聚合冲突仍 SHALL 以聚合根 `updatedAt` last-write-wins 处理；系统 MUST NOT 做逐内部组 merge。

#### Scenario: 跨设备同步递减组
- **WHEN** 设备 A 记录一个递减组并完成同步
- **THEN** 设备 B 下拉该 workout 后能看到同一递减组及其所有内部组

#### Scenario: 旧数据无 segments
- **WHEN** 客户端读取缺少 segments 字段的旧 workout
- **THEN** 系统按空 segments 处理
- **AND** 普通组 `weightKg/reps` 仍照常展示与统计

#### Scenario: 聚合冲突仍按 Workout LWW
- **WHEN** 两台设备同时编辑同一 workout 且产生冲突
- **THEN** 系统沿用 Workout 聚合根 last-write-wins
- **AND** 不尝试逐 segment 合并

### Requirement: 递减组计划处方

训练计划项 SHALL 支持可选的有序组处方 `setPrescriptions`。每个处方 MUST 拥有稳定 `prescriptionId`，并能表达普通组或递减组。递减组处方 MUST 包含有序 segments。计划项缺少 `setPrescriptions` 时，系统 MUST 继续按现有 `suggestedSets/suggestedReps/suggestedWeightKg` 生成普通组，以兼容旧计划。

保存为计划、自适应回写、严格模式预填、自适应模式历史预填、训练模板新建、计划详情编辑、计划详情下次有效处方、Team 计划分享和 Team 计划 Fork 均 SHALL 保留递减组结构。计划列表与旧字段摘要 MAY 继续使用 `suggestedSets/suggestedReps/suggestedWeightKg` 展示简要强度。

训练模板新建与计划详情编辑 SHALL 允许用户为某个计划动作手动创建和编辑递减组处方。该编辑能力 SHALL 支持添加递减组、编辑递减组内部有序 segments 的重量/次数、删除 segment，以及在保存后写入 `setPrescriptions`。计划处方编辑中的递减组 SHALL NOT 展示完成勾选、休息、备注或训练中完成状态。

#### Scenario: 保存训练为计划保留递减组
- **WHEN** 用户将包含递减组的已完成无计划训练保存为计划
- **THEN** 新计划对应动作的 `setPrescriptions` 包含递减组处方
- **AND** 递减组处方包含已完成递减组的有效 segments

#### Scenario: 新建训练模板时手动添加递减组
- **WHEN** 用户新建训练模板并为某个动作添加递减组处方
- **THEN** 保存后的计划项 `setPrescriptions` 包含 `setType=drop` 的处方
- **AND** 该递减组处方包含用户录入的有序 segments
- **AND** 下次从该计划开始训练时生成对应递减组父级 set

#### Scenario: 编辑计划详情中的递减组处方
- **WHEN** 用户在计划详情里编辑某动作并新增、删除或调整递减组内部组
- **THEN** 系统保存更新后的 `setPrescriptions`
- **AND** 计划详情下次有效处方预览展示递减组结构
- **AND** `suggestedSets/suggestedReps/suggestedWeightKg` 摘要同步更新以兼容列表和旧端

#### Scenario: 严格计划预填递减组
- **WHEN** 用户从包含递减组处方的严格计划开始训练
- **THEN** 系统生成对应递减组父级 set
- **AND** 该组包含处方中的 segments
- **AND** 所有新建组 `completed=false`

#### Scenario: 自适应计划优先历史递减组
- **WHEN** 自适应计划某动作上次完成记录包含递减组
- **THEN** 下次从该计划开始训练时优先用上次完成的递减组结构预填
- **AND** 无历史时才回退计划处方或 `suggested*`

#### Scenario: 旧计划继续生成普通组
- **WHEN** 某计划项没有 `setPrescriptions`
- **THEN** 系统继续按 `suggestedSets/suggestedReps/suggestedWeightKg` 生成普通组

### Requirement: 递减组计划分享隐私

Team 分享计划与 Fork MUST 保留递减组结构、组数和次数，但 MUST 清空所有重量字段。清空范围 MUST 包括计划项顶层 `suggestedWeightKg`、普通组处方重量、递减组 segment 重量，以及任何旧 payload 中的 `weightKg` / `weight` 字段。

#### Scenario: Team 分享计划清空递减组重量
- **WHEN** 用户分享一个含递减组处方的计划到 Team
- **THEN** 服务端保存的分享版本保留递减组和 segments
- **AND** 所有 segment 的重量字段被移除或置空
- **AND** 次数与结构保留

#### Scenario: Fork 递减组计划不带重量
- **WHEN** 成员 Fork 一个含递减组处方的 Team 计划
- **THEN** 新计划保留递减组处方结构与次数
- **AND** 所有重量为空
- **AND** 新计划模式仍默认 `adaptive`

## MODIFIED Requirements

### Requirement: 开始训练预填落值与未打勾组清理

从计划开始训练时，预填值 MUST **真正写入** `WorkoutSet.weightKg/reps` 或递减组 segments（落值），且新建组 `completed` MUST 为 `false`；MUST NOT 仅以占位/灰字展示。「是否计入统计」与「是否真实完成」一律由 `completed` 区分。

- **严格模式**：若计划项包含 `setPrescriptions`，`buildFromPlan` MUST 按处方生成普通组或递减组，并把普通组重量/次数或递减组 segments 落值到新训练；若无 `setPrescriptions`，MUST 按 `suggestedSets`（缺省按业务默认）建普通组，并把 `suggestedReps` 与 `suggestedWeightKg`（若有）整组落值到每一组。
- **自适应模式**：MUST 优先用「上次同动作 completed 实绩」落值，且 MUST 保留上次完成的递减组结构；无历史时回退用计划 `setPrescriptions`；再无处方时回退 `suggested*`；若缺少计划组数且无历史，默认生成 4 组普通组。

每个由计划项生成的 `WorkoutExercise` MUST 携带其来源 `PlanItem.itemId`（`planItemId`）；训练中临时新增、非来自计划的动作 `planItemId` MUST 为 `nil`。

结束训练时，未 `completed` 的预填残留组 MUST 被丢弃；未完成递减组及其 segments MUST 一并被丢弃，使训练记录与后续回写只含真实发生的数据。

#### Scenario: 严格模式整组落值
- **WHEN** 用户从一个严格计划（卧推 4 组 × 8 次 × 60kg）开始训练
- **THEN** 生成 4 个 `WorkoutSet`，每组 `weightKg=60、reps=8、completed=false`；用户对实际完成的组打勾即可，无需重输数字

#### Scenario: 严格模式递减组处方落值
- **WHEN** 用户从一个严格计划开始训练，且某动作有递减组处方 `80kg×8 / 60kg×6`
- **THEN** 系统生成一个递减组父级 set
- **AND** 该组包含两个 segments，分别为 `80kg×8` 与 `60kg×6`
- **AND** 父级 set `completed=false`

#### Scenario: 自适应模式历史优先落值
- **WHEN** 用户从自适应计划开始训练，且该动作上次 completed 实绩为逐组 62.5kg×8
- **THEN** 各组按上次同序号 completed 值落值（如 62.5kg×8），计划处方或 `suggested*` 仅在无历史时作为回退

#### Scenario: 自适应模式历史递减组优先
- **WHEN** 用户从自适应计划开始训练，且该动作上次 completed 实绩包含递减组 `80kg×8 / 60kg×6`
- **THEN** 下次训练生成同结构递减组并落值对应 segments

#### Scenario: 新增计划动作默认生成 4×10
- **WHEN** 用户在计划详情里添加一个新动作
- **THEN** 计划项默认保存 `suggestedSets=4` 与 `suggestedReps=10`
- **AND** 下次从该计划开始训练时，此动作直接生成 4 个 `reps=10、completed=false` 的普通组
- **AND** 用户仍可在计划动作处方编辑区把其中任意普通组改为递减组或追加递减组处方

#### Scenario: 未打勾组在结束训练时清理
- **WHEN** 某动作预填 4 组，用户只对 2 组打勾后结束训练
- **THEN** 仅保留 2 个 completed 组，另 2 个未打勾的预填组被丢弃，不进训练记录、不参与统计与回写

### Requirement: 自适应模式实绩回写计划

自适应模式计划在训练**完成**后，MUST 对其来源计划（`Workout.planId` 命中的 `WorkoutPlan`）执行一次 upsert 合并回写。回写 MUST 仅依据本次 `completed` 的正式组（`countsForStats` 为真，即 `setType != .warmup && completed`），并 MUST 保留递减组结构。严格模式 MUST NOT 回写。

合并规则：

- **动作（只增不减）**：训练含、计划无（`planItemId == nil`）的动作 MUST 以新 `PlanItem` append 到计划末尾，并按 `historyKey`（`builtinExerciseCode ?? customExerciseId ?? exerciseName`）去重（命中已有项则视为更新而非新增）；计划含、本次训练未涉及的动作 MUST 保留不动，系统 MUST NOT 自动删除。
- **组数（只增不减）**：`suggestedSets = max(计划现值, 本次该动作 completed 正式逻辑组数)`。递减组按 1 个逻辑组计数。
- **重量 / 次数摘要（如实写回，可升可降）**：取本次该动作 completed 正式记录中最大重量的统计 entry，写入 `suggestedWeightKg / suggestedReps`；若最大重量来自递减组 segment，则使用该 segment 的重量与次数。
- **组处方**：`setPrescriptions` MUST 写入本次该动作 completed 正式组结构；普通组写普通处方，递减组写包含 segments 的递减组处方。

回写 MUST 经由对 `WorkoutPlan` 的本地编辑（`markDirty`）走既有同步域 LWW，MUST NOT 新增独立同步路径。

完成训练页 MUST 展示本次回写的逐项 diff 回执（改值 / 新增 / 已保留），并 MUST 提供「撤销此次更新」入口；撤销 MUST 将计划还原至回写前快照。

#### Scenario: 组数只增不减
- **WHEN** 计划某动作 `suggestedSets=5`，本次只完成 3 个正式逻辑组
- **THEN** 回写后 `suggestedSets` 仍为 5（取 max，不因 deload 缩减）

#### Scenario: 重量次数如实写回顶组
- **WHEN** 本次某动作完成 `60kg×8、60kg×8、65kg×5`（均正式组）
- **THEN** 回写 `suggestedWeightKg=65、suggestedReps=5`（最大重量顶组），`suggestedSets=max(现值,3)`

#### Scenario: 递减组回写处方
- **WHEN** 本次某动作完成一个递减组 `80kg×8 / 60kg×6`
- **THEN** 回写后的计划项包含递减组 `setPrescriptions`
- **AND** `suggestedSets` 至少为 1
- **AND** `suggestedWeightKg=80、suggestedReps=8`

#### Scenario: 训练中新增动作并入计划
- **WHEN** 用户在自适应计划的训练里临时加了一个不在计划中的动作并完成
- **THEN** 该动作以新 `PlanItem` append 到计划末尾（携带本次实绩和组处方），下次开始训练即包含它

#### Scenario: 跳过的动作保留不删
- **WHEN** 计划含「过顶推举」，本次训练跳过未做
- **THEN** 计划仍保留「过顶推举」，仅能由用户在计划模板内手动删除

#### Scenario: 回写可撤销
- **WHEN** 用户在完成训练页点「撤销此次更新」
- **THEN** 来源计划还原到本次回写前的状态，并重新标脏以同步该还原

#### Scenario: 严格模式不回写
- **WHEN** 用户完成一次由严格计划发起的训练
- **THEN** 计划数据保持不变，完成页不展示回写回执

### Requirement: 计划 Fork 字段规则

Fork（复制为新计划 / Team 计划模板分发）一个计划时，新计划 MUST 复制 **动作 + 组数（`suggestedSets`） + 次数（`suggestedReps`）+ 组处方结构（`setPrescriptions`）**，并 MUST 清空重量（`suggestedWeightKg` 以及处方内所有 `weightKg` / `weight` 字段）；新计划模式默认 `adaptive`。系统 MUST NOT 在 Fork 时携带原计划的任何训练实绩重量。

Fork 得到的新计划 MUST 默认归入接收者的「未分组」（`groupId == nil`），并按接收者未分组列表的末尾生成 `sortOrder`。系统 MUST NOT 把发布者或源计划的分组结构复制给接收者。

#### Scenario: Fork 不带重量
- **WHEN** 用户 Fork 一个已被实绩回写到「深蹲 5 组 × 5 次 × 100kg」的自适应计划
- **THEN** 新计划得到「深蹲 5 组 × 5 次」、重量为空，模式为 `adaptive`

#### Scenario: Fork 递减组保留结构不带重量
- **WHEN** 用户 Fork 一个含「递减组 80kg×8 / 60kg×6」处方的计划
- **THEN** 新计划保留一个递减组处方
- **AND** 两个 segment 的次数分别为 8 与 6
- **AND** 两个 segment 的重量均为空

#### Scenario: Fork 默认未分组
- **WHEN** 用户 Fork 一个属于发布者「胸背」分组的 Team 计划
- **THEN** 接收者的新计划 `groupId` SHALL 为 nil
- **AND** 新计划 SHALL 显示在接收者的「未分组」
