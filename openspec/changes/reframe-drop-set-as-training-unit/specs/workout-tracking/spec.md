## ADDED Requirements

### Requirement: 一级训练单元三选一与底部添加入口

iOS SHALL 将训练内容建模为一级训练单元列表。每个训练单元 MUST 且只能属于以下三种之一：普通组训练单元、超级组训练单元、递减组训练单元。递减组 MUST 与普通组、超级组平级，MUST NOT 作为普通动作内部某个普通 set 的可切换类型暴露给用户。

训练单元创建后，其类型 MUST 保持不可变。系统 MUST NOT 提供普通组、递减组、超级组之间的互相转换入口，包括但不限于普通组改递减组、递减组改普通组、普通组组成超级组、超级组解除为普通组。

训练页与计划详情页的底部添加入口 SHALL 保留一个主按钮「添加动作」用于创建普通组训练单元，并保留一个结构菜单图标。结构菜单 SHALL 以二级菜单提供「递减组」和「超级组」入口。外层底部栏 MUST NOT 同时并列展示多个结构类文字按钮。

#### Scenario: 三类训练单元平级展示
- **WHEN** 一次训练包含普通组「杠铃卧推」、递减组「哑铃卧推」和超级组「飞鸟 + 俯卧撑」
- **THEN** 训练列表 SHALL 将三者作为同一层级的三个训练单元展示
- **AND** 递减组 SHALL 不展示为「哑铃卧推」普通组内部的一行特殊 set

#### Scenario: 底部主入口添加普通组
- **WHEN** 用户点击底部「添加动作」
- **THEN** 系统 SHALL 进入动作选择并创建普通组训练单元
- **AND** 不弹出普通组、递减组、超级组的类型选择

#### Scenario: 结构菜单添加递减组或超级组
- **WHEN** 用户点击底部结构菜单图标
- **THEN** 系统 SHALL 展示二级菜单「递减组 / 超级组」
- **AND** 用户选择「递减组」时创建递减组训练单元
- **AND** 用户选择「超级组」时创建超级组训练单元

#### Scenario: 不提供跨类型转换
- **WHEN** 用户打开普通组、递减组或超级组的更多操作菜单
- **THEN** 菜单 MUST NOT 包含改为其它训练单元类型的操作
- **AND** 超级组菜单 MUST NOT 包含「解除超级组」

### Requirement: 训练单元热身标记

iOS SHALL 支持普通组、超级组和递减组都可标记为热身。热身 MUST 是独立于训练单元类型的标记，MUST NOT 通过把训练单元转换为其它类型来表达。

普通组训练单元中，每个普通 set SHALL 可独立标记为热身。超级组训练单元中，热身 SHALL 按整轮生效：同一轮中的两个成员 set MUST 同步为热身或同步为正式，不支持只将其中一个成员 set 标记为热身。递减组训练单元中，热身 SHALL 按整个递减组生效：递减组被标为热身后，其全部有效内部 segments 都按热身组处理。

#### Scenario: 普通组内单组标记热身
- **WHEN** 用户在普通组训练单元中将第 1 组标记为热身
- **THEN** 只有第 1 组按热身处理
- **AND** 同动作其它组的热身状态不受影响

#### Scenario: 超级组整轮标记热身
- **WHEN** 用户将超级组第 1 组标记为热身
- **THEN** 第 1 组内两个成员动作对应 set 都 SHALL 标记为热身
- **AND** 系统 MUST NOT 允许只把其中一个成员动作标记为热身

#### Scenario: 递减组整体标记热身
- **WHEN** 用户将一个递减组训练单元标记为热身
- **THEN** 该递减组内全部有效 segments 都按热身组处理
- **AND** 该递减组仍保持递减组训练单元类型

## MODIFIED Requirements

### Requirement: 开始训练预填落值与未打勾组清理

从计划开始训练时，预填值 MUST **真正写入**普通组 set、递减组 segments 或超级组成员 set，且新建组 `completed` MUST 为 `false`；MUST NOT 仅以占位/灰字展示。「是否计入统计」与「是否真实完成」一律由 `completed` 与热身标记共同决定。

- **严格模式**：若计划项包含普通组训练单元，`buildFromPlan` MUST 按普通组处方生成 set，并把重量/次数落值到新训练；若计划项包含递减组训练单元，MUST 生成递减组训练单元并把 segments 落值到新训练；若计划项包含超级组训练单元，MUST 生成对应超级组训练单元并把两个成员的重量/次数落值到各自 set。缺少逐组处方时，普通组继续按 `suggestedSets/suggestedReps/suggestedWeightKg` 生成普通 set。
- **自适应模式**：MUST 优先用「上次同训练单元类型、同动作的 completed 实绩」落值。普通组回填普通组结构，递减组回填递减组 segments，超级组回填超级组成员 set；无同类型历史时回退计划结构；再无处方时普通组回退 `suggested*`，缺少计划组数且无历史时默认生成 4 组普通组。

每个由计划项生成的 `WorkoutExercise` MUST 携带其来源 `PlanItem.itemId`（`planItemId`）；训练中临时新增、非来自计划的动作 `planItemId` MUST 为 `nil`。

结束训练时，未 `completed` 的预填残留组 MUST 被丢弃；未完成递减组及其 segments MUST 一并被丢弃；未完成超级组轮内两个成员 set MUST 一并按既有未完成组清理规则处理，使训练记录与后续回写只含真实发生的数据。

#### Scenario: 严格模式整组落值
- **WHEN** 用户从一个严格计划（卧推 4 组 × 8 次 × 60kg）开始训练
- **THEN** 生成 4 个普通 set，每组 `weightKg=60、reps=8、completed=false`
- **AND** 用户对实际完成的组打勾即可，无需重输数字

#### Scenario: 严格模式递减组训练单元落值
- **WHEN** 用户从一个严格计划开始训练，且某计划单元为递减组 `80kg×8 / 60kg×6`
- **THEN** 系统生成一个递减组训练单元
- **AND** 该递减组包含两个 segments，分别为 `80kg×8` 与 `60kg×6`
- **AND** 该递减组 `completed=false`

#### Scenario: 自适应模式历史优先落值
- **WHEN** 用户从自适应计划开始训练，且该动作上次 completed 实绩为普通组逐组 `62.5kg×8`
- **THEN** 各普通组按上次同序号 completed 值落值，计划处方或 `suggested*` 仅在无历史时作为回退

#### Scenario: 自适应模式历史递减组优先
- **WHEN** 用户从自适应计划开始训练，且该动作上次同类型 completed 实绩为递减组 `80kg×8 / 60kg×6`
- **THEN** 下次训练生成递减组训练单元并落值对应 segments

#### Scenario: 新增计划动作默认生成 4×10
- **WHEN** 用户在计划详情里通过「添加动作」添加一个新动作
- **THEN** 计划项默认保存为普通组训练单元，且 `suggestedSets=4` 与 `suggestedReps=10`
- **AND** 下次从该计划开始训练时，此动作直接生成 4 个 `reps=10、completed=false` 的普通 set
- **AND** 用户需要递减组或超级组时必须通过底部结构菜单新增对应训练单元

#### Scenario: 未打勾组在结束训练时清理
- **WHEN** 某普通动作预填 4 组，用户只对 2 组打勾后结束训练
- **THEN** 仅保留 2 个 completed 组，另 2 个未打勾的预填组被丢弃，不进训练记录、不参与统计与回写

### Requirement: 自适应模式实绩回写计划

自适应模式计划在训练**完成**后，MUST 对其来源计划（`Workout.planId` 命中的 `WorkoutPlan`）执行一次 upsert 合并回写。回写 MUST 仅依据本次 completed 且非热身的正式统计 entry，并 MUST 保留训练单元类型。严格模式 MUST NOT 回写。

合并规则：

- **动作（只增不减）**：训练含、计划无（`planItemId == nil`）的普通组或递减组训练单元 MUST 以新 `PlanItem` append 到计划末尾，并按 `historyKey`（`builtinExerciseCode ?? customExerciseId ?? exerciseName`）与训练单元类型去重；计划含、本次训练未涉及的动作 MUST 保留不动，系统 MUST NOT 自动删除。
- **训练单元类型不可变**：已有普通组、递减组、超级组计划单元只允许回写同类型实绩；系统 MUST NOT 因本次训练实绩把计划单元改成其它类型。
- **组数（只增不减）**：`suggestedSets = max(计划现值, 本次该训练单元 completed 且非热身的正式统计 entry 数量)`。递减组按有效 segments 数量计数。
- **重量 / 次数摘要（如实写回，可升可降）**：取本次该动作 completed 且非热身的正式统计 entry 中最大重量 entry，写入 `suggestedWeightKg / suggestedReps`；若最大重量来自递减组 segment，则使用该 segment 的重量与次数。
- **组处方**：普通组计划单元写普通组处方，递减组计划单元写包含 segments 的递减组结构，超级组计划单元只更新成员默认重量/次数，不自动改变成员动作、执行顺序或组数。

回写 MUST 经由对 `WorkoutPlan` 的本地编辑（`markDirty`）走既有同步域 LWW，MUST NOT 新增独立同步路径。

完成训练页 MUST 展示本次回写的逐项 diff 回执（改值 / 新增 / 已保留），并 MUST 提供「撤销此次更新」入口；撤销 MUST 将计划还原至回写前快照。

#### Scenario: 组数只增不减
- **WHEN** 计划某普通组动作 `suggestedSets=5`，本次只完成 3 个正式统计 entry
- **THEN** 回写后 `suggestedSets` 仍为 5（取 max，不因 deload 缩减）

#### Scenario: 重量次数如实写回顶组
- **WHEN** 本次某动作完成 `60kg×8、60kg×8、65kg×5`（均 completed 且非热身）
- **THEN** 回写 `suggestedWeightKg=65、suggestedReps=5`（最大重量顶组），`suggestedSets=max(现值,3)`

#### Scenario: 递减组按内部 N 组回写
- **WHEN** 本次某递减组训练单元完成 `80kg×8 / 60kg×6 / 45kg×8`
- **THEN** 回写后的计划项为递减组计划单元
- **AND** `suggestedSets` 至少为 3
- **AND** `suggestedWeightKg=80、suggestedReps=8`

#### Scenario: 训练中新增动作并入计划
- **WHEN** 用户在自适应计划的训练里临时加了一个不在计划中的普通组动作并完成
- **THEN** 该动作以新普通组 `PlanItem` append 到计划末尾，携带本次实绩和组处方，下次开始训练即包含它

#### Scenario: 跳过的动作保留不删
- **WHEN** 计划含「过顶推举」，本次训练跳过未做
- **THEN** 计划仍保留「过顶推举」，仅能由用户在计划模板内手动删除

#### Scenario: 回写可撤销
- **WHEN** 用户在完成训练页点「撤销此次更新」
- **THEN** 来源计划还原到本次回写前的状态，并重新标脏以同步该还原

#### Scenario: 严格模式不回写
- **WHEN** 用户完成一次由严格计划发起的训练
- **THEN** 计划数据保持不变，完成页不展示回写回执

### Requirement: 热身组排除于统计与 PR

所有训练统计 SHALL 以「计入统计的 entry = 已完成且非热身」为判据，即 `countsForStats` MUST 定义为 `completed && !isWarmup`。热身组与**未完成（`completed == false`，含自适应/严格落值后未打勾的预填残组）**的组 MUST NOT 计入。受此约束的口径包括：PR 最大重量（动作库行与动作详情）、周训练量（volume）、周总组数、周总次数、历史强度曲线、训练详情聚合、Team summary 和分享海报。

热身 MUST 是独立于训练单元类型的标记。普通组、超级组、递减组均可被标记为热身；递减组或超级组被标记为热身时，其内部所有有效统计 entry 都 MUST 被排除。被排除的记录本身 MUST 完整保留（重量/次数照常录入与展示，未打勾组在结束训练时按「未打勾组清理」处理），仅在统计聚合时被排除。

#### Scenario: 未完成组不计统计
- **WHEN** 某动作预填 4 个普通组，用户只打勾完成 2 组
- **THEN** 周训练量、周总组数、PR 仅累计已完成且非热身的 2 个组，未打勾的 2 组不计入

#### Scenario: 普通热身组不计训练量与组数
- **WHEN** 某普通组训练单元有 2 个热身组（各 40kg×10、60kg×5）与 3 个已完成正式组（各 80kg×8）
- **THEN** 周训练量只累加 3 个正式组、周总组数只计 3、热身组的 reps 不计入总次数

#### Scenario: 递减组热身整体排除
- **WHEN** 某递减组训练单元被标记为热身，内部有效 segments 为 `80kg×8、60kg×6、45kg×8`
- **THEN** 这 3 个内部组都不计入训练量、总组数、总次数、PR 或历史曲线

#### Scenario: 超级组热身整轮排除
- **WHEN** 某超级组第 1 组被标记为热身
- **THEN** 第 1 组内两个成员 set 都不计入训练量、总组数、总次数、PR 或历史曲线
- **AND** 同一超级组其它非热身 completed 组仍按正式组计入

#### Scenario: 热身组不破 PR
- **WHEN** 某动作的最大重量出现在一个被标为热身的 entry 里
- **THEN** PR 与历史曲线忽略该热身 entry，仅按已完成且非热身 entry 计算

### Requirement: 递减组录入与内部组记录

系统 SHALL 支持「递减组」作为与普通组、超级组平级的一级训练单元。递减组在 UI 中 MUST 始终显示为「递减组」，但系统 MUST NOT 校验、推断或持久化其真实重量方向；递增、递减或混合输入均 SHALL 只作为用户录入的有序内部组保存。

递减组训练单元 MUST 绑定一个动作，并包含一个有序内部组列表。每个内部组至少包含稳定 `segmentId`、`segmentIndex`、`weightKg` 与 `reps`。递减组训练单元的完成勾选、组间休息、备注、删除、排序和同步 SHALL 作用于该训练单元整体。递减组 SHALL 可标记为热身；热身递减组不计入统计，但仍保持递减组结构。

递减组只能通过底部结构菜单新增。普通动作卡底部 MUST NOT 展示「递减组」快速添加入口。每组右侧更多操作菜单 MUST NOT 支持普通组改为递减组，也 MUST NOT 支持递减组改回普通组。

#### Scenario: 从结构菜单新增递减组
- **WHEN** 用户在底部结构菜单点击「递减组」
- **THEN** 系统创建一个递减组训练单元
- **AND** 用户选择或确认该递减组绑定的唯一动作
- **AND** 该递减组默认包含至少 2 个内部组
- **AND** 若存在同动作上一正式记录，首个内部组 MAY 预填上一正式记录的重量与次数

#### Scenario: 普通组不能改为递减组
- **WHEN** 用户在普通组右侧更多操作菜单中查看可选操作
- **THEN** 菜单 MUST NOT 提供「改为递减组」
- **AND** 用户需要递减组时必须通过底部结构菜单新增递减组训练单元

#### Scenario: 递减组不能改回普通组
- **WHEN** 用户在递减组训练单元的更多操作菜单中查看可选操作
- **THEN** 菜单 MUST NOT 提供「改回普通组」
- **AND** 用户需要普通组时必须删除该递减组后重新添加普通动作

#### Scenario: 不校验递减方向
- **WHEN** 用户在递减组内录入 `50kg×10、60kg×8、55kg×6`
- **THEN** 系统保存这些有序内部组
- **AND** 不提示方向错误、不自动改名为递增组或混合组

#### Scenario: 递减组可标记热身
- **WHEN** 用户将递减组训练单元标记为热身
- **THEN** 该训练单元仍显示为「递减组」
- **AND** 该递减组内部所有有效 segments 都按热身处理

### Requirement: 递减组统计、PR 与历史曲线

系统 SHALL 将递减组按内部有效 segments 计为 N 个组。训练量、总次数、PR、历史曲线、训练详情聚合、分享海报和 Team 打卡容量 MUST 按递减组有效内部组展开计算。未完成递减组、空白内部组、热身递减组 MUST NOT 计入统计。

系统 MUST 提供统一的统计派生口径，使普通组、热身标记、递减组与超级组在 PR、周统计、历史快照、计划回写和 Team 摘要中得到一致结果。统计数据 MUST 可由原始训练记录与内部组重算，MUST NOT 持久化冗余统计。

#### Scenario: 递减组按内部 N 组计数
- **WHEN** 用户完成一个递减组，内部组为 `80kg×8、60kg×6、45kg×8`
- **THEN** 已完成组数增加 3
- **AND** 训练量增加 `80*8 + 60*6 + 45*8`
- **AND** 总次数增加 `8 + 6 + 8`

#### Scenario: 递减组刷新 PR
- **WHEN** 用户完成一个非热身递减组，内部组中最大重量超过该动作历史最大重量
- **THEN** 系统按该最大重量识别 PR
- **AND** PR 庆祝、动作库 PR 副标和动作历史摘要使用同一最大重量

#### Scenario: 未完成递减组不计统计
- **WHEN** 用户录入递减组内部组但未勾选完成
- **THEN** 该递减组及其所有内部组不计入训练量、总次数、总组数、PR 或历史曲线

#### Scenario: 空白内部组不计统计
- **WHEN** 递减组包含一个完全空白内部组
- **THEN** 系统保存或清理该空白内部组时不让它影响训练量、总次数、总组数或 PR

#### Scenario: 热身递减组不计统计
- **WHEN** 用户完成一个被标为热身的递减组，内部组为 `80kg×8、60kg×6`
- **THEN** 该递减组贡献 0 个正式统计组
- **AND** 不影响训练量、总次数、PR 或历史曲线

### Requirement: 递减组详情、海报与 Team 打卡展示

训练详情、训练分享海报、Team 打卡摘要和 Team 打卡详情 SHALL 展示递减组训练单元及其内部组信息。紧凑位置 MAY 展示递减组摘要（如 `80×8 +2组`），详情位置 MUST 能展示每个有效内部组的重量与次数。

Team 打卡摘要 MUST 在结构化 payload 中保留递减组训练单元类型与 segments。训练详情、海报和 Team 摘要中的组数 MUST 按递减组有效 segments 数量计算；热身递减组不计入正式组数和训练量。

#### Scenario: 训练详情展示递减组流水
- **WHEN** 用户打开包含递减组的已完成训练详情
- **THEN** 对应训练单元显示「递减组」标识
- **AND** 展示该递减组的所有有效内部组

#### Scenario: 海报展示递减组摘要
- **WHEN** 用户为包含递减组的训练生成分享海报
- **THEN** 动作高光行使用递减组最大重量内部组作为顶组
- **AND** 文案能表达该递减组含额外内部组
- **AND** 海报组数按有效内部组数量计算

#### Scenario: Team 打卡保留内部组
- **WHEN** 用户自动或手动分享一条包含递减组的训练到 Team
- **THEN** checkin summary 中该训练单元包含递减组类型与内部组列表
- **AND** Team 成员查看时能看到递减组内部组
- **AND** Team 摘要组数按递减组有效内部组数量计算

### Requirement: 递减组同步与兼容

Workout 同步 SHALL 保留递减组训练单元结构与内部组。后端 SHALL 在 Workout 聚合 push/pull 中原样收发训练单元类型、动作引用、热身标记与 segments。递减组不 SHALL 拥有独立同步信封。Workout 聚合冲突仍 SHALL 以聚合根 `updatedAt` last-write-wins 处理；系统 MUST NOT 做逐内部组 merge。

本变更不要求兼容旧递减组产品语义。普通旧训练记录仍可按普通组读取；旧计划缺少递减组训练单元时按现有普通组字段处理。实现 MAY 对开发期旧 `setType=drop` 数据做一次性清理或直接按新 fixtures 重建。

#### Scenario: 跨设备同步递减组
- **WHEN** 设备 A 记录一个递减组训练单元并完成同步
- **THEN** 设备 B 下拉该 workout 后能看到同一递减组训练单元及其所有内部组
- **AND** 设备 B 能读取该递减组的热身标记

#### Scenario: 普通旧训练继续可读
- **WHEN** 客户端读取没有递减组训练单元结构的旧普通训练记录
- **THEN** 系统按普通组训练单元处理
- **AND** 普通组重量、次数、完成状态和热身标记照常展示与统计

#### Scenario: 聚合冲突仍按 Workout LWW
- **WHEN** 两台设备同时编辑同一 workout 且产生冲突
- **THEN** 系统沿用 Workout 聚合根 last-write-wins
- **AND** 不尝试逐 segment 合并

### Requirement: 递减组计划处方

训练计划 SHALL 支持与普通组、超级组平级的递减组计划单元。递减组计划单元 MUST 拥有稳定 `itemId`，并包含一个动作引用、有序 segments、可选热身标记和必要摘要字段。普通组计划单元继续可使用有序普通组处方；递减组 MUST NOT 作为普通组计划单元内部某个处方的可切换类型暴露给用户。

保存为计划、自适应回写、严格模式预填、自适应模式历史预填、训练模板新建、计划详情编辑、计划详情下次有效处方、Team 计划分享和 Team 计划 Fork 均 SHALL 保留递减组训练单元结构。计划列表与旧字段摘要 MAY 继续使用 `suggestedSets/suggestedReps/suggestedWeightKg` 展示简要强度，但 `suggestedSets` 对递减组 MUST 反映有效 segments 数量。

训练模板新建与计划详情编辑 SHALL 允许用户从底部结构菜单添加递减组计划单元，编辑该递减组内部有序 segments 的重量/次数、删除 segment，以及保存热身标记。计划处方编辑中的递减组 SHALL NOT 展示训练中完成勾选、休息或训练中完成状态。

#### Scenario: 保存训练为计划保留递减组
- **WHEN** 用户将包含递减组训练单元的已完成无计划训练保存为计划
- **THEN** 新计划对应项为递减组计划单元
- **AND** 递减组计划单元包含已完成递减组的有效 segments
- **AND** `suggestedSets` 等于有效 segments 数量

#### Scenario: 新建训练模板时手动添加递减组
- **WHEN** 用户新建训练模板并通过结构菜单添加递减组
- **THEN** 保存后的计划项为 `unitKind=dropSet`
- **AND** 该递减组计划单元包含用户录入的有序 segments
- **AND** 下次从该计划开始训练时生成对应递减组训练单元

#### Scenario: 编辑计划详情中的递减组
- **WHEN** 用户在计划详情里编辑某递减组并新增、删除或调整内部组
- **THEN** 系统保存更新后的递减组计划单元
- **AND** 计划详情下次有效处方预览展示递减组结构
- **AND** `suggestedSets/suggestedReps/suggestedWeightKg` 摘要同步更新以兼容列表和旧端

#### Scenario: 严格计划预填递减组
- **WHEN** 用户从包含递减组计划单元的严格计划开始训练
- **THEN** 系统生成对应递减组训练单元
- **AND** 该递减组包含处方中的 segments
- **AND** 新建递减组 `completed=false`

#### Scenario: 自适应计划优先历史递减组
- **WHEN** 自适应计划某动作上次同类型完成记录为递减组
- **THEN** 下次从该计划开始训练时优先用上次完成的递减组结构预填
- **AND** 无同类型历史时才回退计划递减组或普通默认值

#### Scenario: 旧计划继续生成普通组
- **WHEN** 某计划项没有递减组或超级组训练单元结构
- **THEN** 系统继续按 `suggestedSets/suggestedReps/suggestedWeightKg` 生成普通组训练单元

### Requirement: 递减组计划分享隐私

Team 分享计划与 Fork MUST 保留递减组训练单元结构、内部组数和次数，但 MUST 清空所有重量字段。清空范围 MUST 包括计划项顶层 `suggestedWeightKg`、普通组处方重量、递减组 segment 重量，以及任何旧 payload 中的 `weightKg` / `weight` 字段。

#### Scenario: Team 分享计划清空递减组重量
- **WHEN** 用户分享一个含递减组计划单元的计划到 Team
- **THEN** 服务端保存的分享版本保留递减组训练单元和 segments
- **AND** 所有 segment 的重量字段被移除或置空
- **AND** 次数与结构保留

#### Scenario: Fork 递减组计划不带重量
- **WHEN** 成员 Fork 一个含递减组计划单元的 Team 计划
- **THEN** 新计划保留递减组训练单元结构与次数
- **AND** 所有重量为空
- **AND** 新计划模式仍默认 `adaptive`
