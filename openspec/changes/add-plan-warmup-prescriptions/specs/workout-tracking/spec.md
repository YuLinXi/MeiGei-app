## ADDED Requirements

### Requirement: 普通动作计划热身处方

iOS SHALL 允许用户在普通动作计划项中定义热身组处方。热身组处方 MUST 仅适用于 `PlanItem.unitKind == singleExercise` 的普通动作计划项；每个热身组 MAY 独立定义重量与次数，并 MUST 在从计划开始训练时生成对应的热身 `WorkoutSet`。

计划详情和计划编辑 SHALL 弱化热身组默认展示：动作行主摘要 MUST 仍以正式组为主，热身组只作为次级摘要展示；普通动作编辑页中的热身组明细 MUST 默认折叠，用户展开或添加热身组后才展示逐组重量/次数。

递减组计划项和超级组计划项 MUST NOT 支持计划热身组。系统 MUST NOT 在递减组或超级组编辑 UI 中展示热身入口，也 MUST NOT 在这些计划项中保存或回写热身处方。

#### Scenario: 普通动作展示弱化热身摘要
- **WHEN** 普通动作计划项「卧推」包含 2 个热身组和 4 个正式组
- **THEN** 动作行主摘要展示正式处方，例如「下次 4 正式组 · 80 kg × 8」
- **AND** 热身仅以次级摘要展示，例如「热身 2 组 · 20×10 / 40×5」
- **AND** 热身明细默认不在动作行展开

#### Scenario: 编辑普通动作热身组
- **WHEN** 用户进入普通动作计划项编辑页并展开「热身组」
- **THEN** 系统允许用户添加、删除和编辑热身组
- **AND** 每个热身组可单独填写重量和次数
- **AND** 保存后热身组在该普通动作计划项内排在正式组之前

#### Scenario: 新增普通动作默认无热身
- **WHEN** 用户向计划添加一个普通动作
- **THEN** 该计划项默认只有正式组处方
- **AND** 热身组数量为 0
- **AND** 用户必须显式添加热身组后才产生热身处方

#### Scenario: 递减组不展示热身入口
- **WHEN** 用户编辑一个递减组计划项
- **THEN** 页面不展示「热身组」折叠区或标记热身入口
- **AND** 保存后的递减组计划项不包含热身处方

#### Scenario: 超级组不展示热身入口
- **WHEN** 用户创建或编辑一个超级组计划项
- **THEN** 页面不展示热身轮或成员热身组入口
- **AND** 保存后的超级组计划项不包含热身处方

## MODIFIED Requirements

### Requirement: 开始训练预填落值与未打勾组清理

从计划开始训练时，预填值 MUST **真正写入** `WorkoutSet.weightKg/reps` 或递减组 segments（落值），且新建组 `completed` MUST 为 `false`；MUST NOT 仅以占位/灰字展示。「是否计入统计」与「是否真实完成」一律由 `completed` 与热身标记共同决定。

- **普通动作严格模式**：若普通动作计划项包含 `setPrescriptions`，`buildFromPlan` MUST 按处方生成热身组和正式组，并把重量/次数落值到新训练；若无 `setPrescriptions`，MUST 按 `suggestedSets`（缺省按业务默认）建正式组，并把 `suggestedReps` 与 `suggestedWeightKg`（若有）整组落值到每一组。
- **普通动作自适应模式**：MUST 优先用「上次同普通动作 completed 执行处方」落值，该执行处方包含热身组和正式组；无历史时回退用计划 `setPrescriptions`；再无处方时回退 `suggested*`；若缺少计划组数且无历史，默认生成 4 组正式组。
- **递减组**：从计划开始训练时 MUST 生成递减组结构并落值 segments，但 MUST NOT 生成热身组或热身递减组。
- **超级组**：从计划开始训练时 MUST 生成超级组成员组和轮数，但 MUST NOT 生成热身轮或超级组内热身组。

每个由计划项生成的 `WorkoutExercise` MUST 携带其来源 `PlanItem.itemId`（`planItemId`）；训练中临时新增、非来自计划的动作 `planItemId` MUST 为 `nil`。

结束训练时，未 `completed` 的预填残留组 MUST 被丢弃；未完成递减组及其 segments MUST 一并被丢弃，使训练记录与后续回写只含真实发生的数据。被完成的热身组 MUST 保留在训练记录中，但仍不参与统计。

#### Scenario: 严格模式普通动作包含热身落值
- **WHEN** 用户从一个严格计划开始训练，普通动作「卧推」有 2 个热身组（20kg×10、40kg×5）和 4 个正式组（60kg×8）
- **THEN** 系统生成 6 个 `WorkoutSet`
- **AND** 前 2 组为热身组，后 4 组为正式组
- **AND** 所有组 `completed=false` 且重量/次数已落值

#### Scenario: 严格模式整组落值
- **WHEN** 用户从一个严格计划（卧推 4 组 × 8 次 × 60kg）开始训练
- **THEN** 生成 4 个正式 `WorkoutSet`，每组 `weightKg=60、reps=8、completed=false`；用户对实际完成的组打勾即可，无需重输数字

#### Scenario: 严格模式递减组处方落值
- **WHEN** 用户从一个严格计划开始训练，且某动作有递减组处方 `80kg×8 / 60kg×6`
- **THEN** 系统生成一个递减组父级 set
- **AND** 该组包含两个 segments，分别为 `80kg×8` 与 `60kg×6`
- **AND** 父级 set `completed=false`
- **AND** 该递减组不带热身标记

#### Scenario: 自适应模式历史优先保留普通动作热身
- **WHEN** 用户从自适应计划开始训练，且该普通动作上次 completed 执行处方为 2 个热身组 + 3 个正式组
- **THEN** 下次训练生成同样数量的热身组和正式组
- **AND** 各组按上次同序号 completed 值落值

#### Scenario: 自适应模式历史递减组优先但不保留热身
- **WHEN** 用户从自适应计划开始训练，且该动作上次 completed 实绩包含递减组 `80kg×8 / 60kg×6`
- **THEN** 下次训练生成同结构递减组并落值对应 segments
- **AND** 系统不生成热身递减组

#### Scenario: 新增计划动作默认生成 4×10
- **WHEN** 用户在计划详情里添加一个新普通动作
- **THEN** 计划项默认保存 4 个正式组与 `suggestedReps=10`
- **AND** 下次从该计划开始训练时，此动作直接生成 4 个 `reps=10、completed=false` 的正式组
- **AND** 不自动生成热身组

#### Scenario: 未打勾组在结束训练时清理
- **WHEN** 某普通动作预填 2 个热身组和 4 个正式组，用户只完成 1 个热身组和 3 个正式组后结束训练
- **THEN** 仅保留这 4 个 completed 组
- **AND** 未打勾的热身组和正式组均被丢弃
- **AND** 被保留的热身组不参与统计与 PR

### Requirement: 计划详情展示下次有效处方

计划详情页 SHALL 把动作列表展示为「下次训练处方」而不只是静态计划字段。每个动作行 SHALL 展示下一次从该计划开始训练时会生成的有效处方摘要（组数 / 次数 / 重量）与来源说明；该摘要 MUST 与「开始训练预填落值」使用的 `PlanPrefill` 规则一致。

- **普通动作主摘要**：MUST 以正式组为主，热身组 MUST NOT 计入主摘要的正式组数、代表重量或代表次数。若存在热身组，动作行 SHALL 以弱化次级文本展示热身摘要。
- **自适应模式**：下次有效处方 MUST 优先基于上次同普通动作 completed 执行处方；正式组主摘要基于 completed 且非热身的正式组，热身摘要基于 completed 热身组。无历史时回退计划 `setPrescriptions` 或 `suggested*`；无历史且缺少计划组数时默认 4 个正式组。动作行 SHALL 展示来源标签（至少包括：历史、预设、默认、保留）与来源说明（如「来自上次完成 · 昨天」「计划预设」「默认起步」「上次未练 · 已保留」）。
- **严格模式**：下次有效处方 MUST 直接展示计划预设，并 SHALL 明确「严格执行 · 完成后不更新」。严格模式仍 MUST 在缺少正式组必填组数/次数时阻止开始训练；热身组不是严格模式必填条件。
- **列表页**：计划列表中每个计划卡 SHALL 展示当前模式，并 SHALL 用一行短文案说明行为差异（如「下次依据：上次完成实绩」「完成后自动更新」「严格执行 · 不回写」「默认 4×10 起步」）。用户 MUST NOT 只有进入详情页后才知道计划是否会自动回写。

#### Scenario: 自适应详情显示历史来源处方
- **WHEN** 用户进入一个自适应计划详情页，且「卧推」上次 completed 正式组为 `65kg×5`
- **THEN** 「卧推」动作行显示「下次 ... 65 kg × 5」
- **AND** 来源显示为历史来源（如「历史」「来自上次完成 · 昨天」）
- **AND** 用户点「开始这次训练」后生成的正式 `WorkoutSet` 与该处方一致

#### Scenario: 自适应详情显示热身摘要
- **WHEN** 用户进入一个自适应计划详情页，且「卧推」下次处方包含 2 个热身组和 4 个正式组
- **THEN** 动作行主摘要显示 4 个正式组
- **AND** 动作行次级文本显示热身 2 组
- **AND** 热身组不计入主摘要的正式组数

#### Scenario: 自适应详情显示计划预设来源
- **WHEN** 用户进入一个自适应计划详情页，且某动作无 completed 历史但有 `suggestedSets=4、suggestedReps=10`
- **THEN** 该动作行显示「下次 4 组 × 10」
- **AND** 来源显示「预设」或「计划预设」

#### Scenario: 自适应详情显示默认起步
- **WHEN** 用户进入一个自适应计划详情页，且某动作无 completed 历史、无计划组数
- **THEN** 该动作行显示默认 4 个正式组起步
- **AND** 若该动作有默认次数 10，则显示「下次 4 组 × 10」

#### Scenario: 计划列表展示模式行为摘要
- **WHEN** 用户查看计划列表，列表中同时存在严格计划与自适应计划
- **THEN** 每张计划卡都显示当前模式
- **AND** 严格计划显示不回写语义，自适应计划显示自动更新或下次依据语义

### Requirement: 自适应模式实绩回写计划

自适应模式计划在训练**完成**后，MUST 对其来源计划（`Workout.planId` 命中的 `WorkoutPlan`）执行一次 upsert 合并回写。普通动作回写 MUST 同时维护执行处方和强度摘要：执行处方 MAY 包含 completed 热身组和 completed 正式组；强度摘要 MUST 仅依据本次 `completed` 的正式组（`countsForStats` 为真，即非热身且 completed）。严格模式 MUST NOT 回写。

合并规则：

- **动作（只增不减）**：训练含、计划无（`planItemId == nil`）的普通动作或递减组动作 MUST 以新 `PlanItem` append 到计划末尾，并按 `historyKey`（`builtinExerciseCode ?? customExerciseId ?? exerciseName`）和计划项类型去重（命中已有项则视为更新而非新增）；计划含、本次训练未涉及的动作 MUST 保留不动，系统 MUST NOT 自动删除。
- **普通动作热身处方**：普通动作本次 completed 热身组 MUST 写入该计划项的 `setPrescriptions`，排在正式处方之前；本次跳过热身时，系统 MUST NOT 自动删除计划中已有热身处方。
- **递减组和超级组排除热身**：递减组计划项和超级组计划项 MUST NOT 回写热身处方；若历史训练中相关 set 带热身标记，计划回写仍 MUST 忽略该热身语义。
- **正式组数（只增不减）**：普通动作 `suggestedSets = max(计划现有正式组数, 本次 completed 正式逻辑组数)`；热身组 MUST NOT 计入 `suggestedSets`。递减组按 1 个逻辑组计数。
- **重量 / 次数摘要（如实写回，可升可降）**：取本次该动作 completed 正式记录中最大重量的统计 entry，写入 `suggestedWeightKg / suggestedReps`；若最大重量来自递减组 segment，则使用该 segment 的重量与次数。热身组 MUST NOT 影响该摘要。
- **组处方**：普通动作 `setPrescriptions` MUST 写入热身组和正式组处方；递减组只写包含 segments 的递减组处方；超级组只更新成员默认重量/次数，不保存热身轮。

回写 MUST 经由对 `WorkoutPlan` 的本地编辑（`markDirty`）走既有同步域 LWW，MUST NOT 新增独立同步路径。

完成训练页 MUST 展示本次回写的逐项 diff 回执（改值 / 新增 / 已保留），并 MUST 提供「撤销此次更新」入口；撤销 MUST 将计划还原至回写前快照。

#### Scenario: 普通动作回写热身和正式处方
- **WHEN** 用户完成自适应计划中的普通动作「卧推」，本次包含 2 个 completed 热身组和 3 个 completed 正式组
- **THEN** 来源计划项的 `setPrescriptions` 包含 5 个处方
- **AND** 前 2 个处方标记为热身
- **AND** `suggestedSets` 仅按 3 个正式组更新

#### Scenario: 跳过热身不删除既有热身处方
- **WHEN** 计划某普通动作已有 2 个热身组处方，但本次训练只完成正式组
- **THEN** 回写后该计划项仍保留原有热身组处方
- **AND** 正式组强度摘要按本次 completed 正式组更新

#### Scenario: 组数只增不减
- **WHEN** 计划某普通动作 `suggestedSets=5`，本次只完成 3 个正式逻辑组
- **THEN** 回写后 `suggestedSets` 仍为 5（取 max，不因 deload 缩减）

#### Scenario: 重量次数如实写回顶组
- **WHEN** 本次某普通动作完成 `60kg×8、60kg×8、65kg×5`（均正式组）
- **THEN** 回写 `suggestedWeightKg=65、suggestedReps=5`（最大重量顶组），`suggestedSets=max(现值,3)`

#### Scenario: 热身组不影响强度摘要
- **WHEN** 本次某普通动作完成热身组 `100kg×1` 和正式组 `80kg×8`
- **THEN** 回写的 `suggestedWeightKg=80、suggestedReps=8`
- **AND** 热身组 `100kg×1` 只作为热身处方保留，不刷新正式强度摘要

#### Scenario: 递减组回写处方不带热身
- **WHEN** 本次某动作完成一个递减组 `80kg×8 / 60kg×6`
- **THEN** 回写后的计划项包含递减组 `setPrescriptions`
- **AND** `suggestedSets` 至少为 1
- **AND** `suggestedWeightKg=80、suggestedReps=8`
- **AND** 该递减组处方不带热身标记

#### Scenario: 训练中新增动作并入计划
- **WHEN** 用户在自适应计划的训练里临时加了一个不在计划中的普通动作并完成
- **THEN** 该动作以新 `PlanItem` append 到计划末尾（携带本次正式组实绩和普通动作组处方），下次开始训练即包含它

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

Fork（复制为新计划 / Team 计划模板分发）一个计划时，新计划 MUST 复制 **动作 + 正式组数（`suggestedSets`） + 次数（`suggestedReps`）+ 普通动作热身/正式组处方结构（`setPrescriptions`）**，并 MUST 清空重量（`suggestedWeightKg` 以及处方内所有 `weightKg` / `weight` 字段）；新计划模式默认 `adaptive`。系统 MUST NOT 在 Fork 时携带原计划的任何训练实绩重量。

Fork 得到的新计划 MUST 默认归入接收者的「未分组」（`groupId == nil`），并按接收者未分组列表的末尾生成 `sortOrder`。系统 MUST NOT 把发布者或源计划的分组结构复制给接收者。

普通动作热身处方在 Fork / Team 分享时 MUST 保留组序、热身标记和次数，并 MUST 清空重量。递减组和超级组仍不支持热身处方，Fork / Team 分享不得为它们生成热身组。

#### Scenario: Fork 不带重量
- **WHEN** 用户 Fork 一个已被实绩回写到「深蹲 5 组 × 5 次 × 100kg」的自适应计划
- **THEN** 新计划得到「深蹲 5 组 × 5 次」、重量为空，模式为 `adaptive`

#### Scenario: Fork 普通动作热身处方保留次数不带重量
- **WHEN** 用户 Fork 一个含普通动作热身处方「20kg×10、40kg×5」的计划
- **THEN** 新计划保留 2 个热身组处方
- **AND** 两个热身组次数分别为 10 与 5
- **AND** 两个热身组重量均为空

#### Scenario: Fork 递减组保留结构不带重量
- **WHEN** 用户 Fork 一个含「递减组 80kg×8 / 60kg×6」处方的计划
- **THEN** 新计划保留一个递减组处方
- **AND** 两个 segment 的次数分别为 8 与 6
- **AND** 两个 segment 的重量均为空
- **AND** 该递减组不包含热身标记

#### Scenario: Fork 默认未分组
- **WHEN** 用户 Fork 一个属于发布者「胸背」分组的 Team 计划
- **THEN** 接收者的新计划 `groupId` SHALL 为 nil
- **AND** 新计划 SHALL 显示在接收者的「未分组」
