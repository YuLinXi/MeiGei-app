## ADDED Requirements

### Requirement: 训练计划模式（严格 / 自适应）

每个训练计划（`WorkoutPlan`）SHALL 带一个**模式**，由可扩展枚举承载，当前取值为 `strict`（严格）与 `adaptive`（自适应），默认 `adaptive`。新建计划与任何未识别的模式值 MUST 视为 `adaptive`，以保证旧数据与跨版本兼容。

- **严格模式**：编辑计划项时，动作、组数、次数 MUST 为必填，重量为选填。语义为「照剧本执行」——开始训练时整组复制预设（见「开始训练预填落值」），完成训练时 MUST NOT 回写计划。
- **自适应模式**：编辑计划项时，仅动作 MUST 为必填，组数 / 次数 / 重量均为选填。语义为「记录我的进化」——首次/无历史用计划预设落值，完成训练后 MUST 按「自适应模式实绩回写计划」对来源计划做 upsert 回写。

新建计划页 SHALL 在计划名称下方提供严格 / 自适应模式选择，并 SHALL 展示与编辑页一致的模式说明文案。模式 SHALL 在计划详情页以可见标识呈现，并 SHALL 向用户提供该模式回写规则的说明（自适应模式至少说明：组数/次数/重量按实绩更新、训练中新增动作并入计划、训练中跳过的动作保留需手动删）。「严格」MUST 仅约束「初始预填来源为整组复制」，MUST NOT 锁定训练中的临场改值与打勾。

#### Scenario: 新建计划默认自适应
- **WHEN** 用户新建一个训练计划
- **THEN** 模式选择默认选中 `adaptive`，编辑时仅「动作」为必填项

#### Scenario: 新建计划可直接选择严格模式
- **WHEN** 用户在新建计划页选择严格模式并保存
- **THEN** 新计划模式为 `strict`，并在后续添加动作时按严格模式必填校验

#### Scenario: 切换到严格模式需补齐必填
- **WHEN** 用户把某自适应计划切换为严格模式，而其中某动作缺组数或次数
- **THEN** 系统 SHALL 提示补齐严格模式必填项（动作 + 组数 + 次数）后方可完成切换

#### Scenario: 未识别模式兜底
- **WHEN** 客户端读到本端未识别的计划模式值（如来自更高版本）
- **THEN** 按 `adaptive` 处理，不崩溃

### Requirement: 开始训练预填落值与未打勾组清理

从计划开始训练时，预填值 MUST **真正写入** `WorkoutSet.weightKg/reps`（落值），且新建组 `completed` MUST 为 `false`；MUST NOT 仅以占位/灰字展示。「是否计入统计」与「是否真实完成」一律由 `completed` 区分。

- **严格模式**：`buildFromPlan` MUST 按 `suggestedSets`（缺省按业务默认）建组，并把 `suggestedReps` 与 `suggestedWeightKg`（若有）整组落值到每一组。
- **自适应模式**：MUST 优先用「上次同动作 completed 实绩」落值（若存在历史，按 `historyKey` 命中）；无历史时回退用计划 `suggested*` 落值；若缺少计划组数且无历史，默认生成 4 组。

每个由计划项生成的 `WorkoutExercise` MUST 携带其来源 `PlanItem.itemId`（`planItemId`）；训练中临时新增、非来自计划的动作 `planItemId` MUST 为 `nil`。

结束训练时，未 `completed` 的预填残留组 MUST 被丢弃，使训练记录与后续回写只含真实发生的数据。

#### Scenario: 严格模式整组落值
- **WHEN** 用户从一个严格计划（卧推 4 组 × 8 次 × 60kg）开始训练
- **THEN** 生成 4 个 `WorkoutSet`，每组 `weightKg=60、reps=8、completed=false`；用户对实际完成的组打勾即可，无需重输数字

#### Scenario: 自适应模式历史优先落值
- **WHEN** 用户从自适应计划开始训练，且该动作上次 completed 实绩为逐组 62.5kg×8
- **THEN** 各组按上次同序号 completed 值落值（如 62.5kg×8），计划 `suggested*` 仅在无历史时作为回退

#### Scenario: 新增计划动作默认生成 4×10
- **WHEN** 用户在计划详情里添加一个新动作
- **THEN** 计划项默认保存 `suggestedSets=4` 与 `suggestedReps=10`
- **AND** 下次从该计划开始训练时，此动作直接生成 4 个 `reps=10、completed=false` 的组

#### Scenario: 未打勾组在结束训练时清理
- **WHEN** 某动作预填 4 组，用户只对 2 组打勾后结束训练
- **THEN** 仅保留 2 个 completed 组，另 2 个未打勾的预填组被丢弃，不进训练记录、不参与统计与回写

### Requirement: 自适应模式实绩回写计划

自适应模式计划在训练**完成**后，MUST 对其来源计划（`Workout.planId` 命中的 `WorkoutPlan`）执行一次 upsert 合并回写。回写 MUST 仅依据本次 `completed` 的正式组（`countsForStats` 为真，即 `setType != .warmup && completed`）。严格模式 MUST NOT 回写。

合并规则：

- **动作（只增不减）**：训练含、计划无（`planItemId == nil`）的动作 MUST 以新 `PlanItem` append 到计划末尾，并按 `historyKey`（`builtinExerciseCode ?? customExerciseId ?? exerciseName`）去重（命中已有项则视为更新而非新增）；计划含、本次训练未涉及的动作 MUST 保留不动，系统 MUST NOT 自动删除。
- **组数（只增不减）**：`suggestedSets = max(计划现值, 本次该动作 completed 正式组数)`。
- **重量 / 次数（如实写回，可升可降）**：取本次该动作 completed 正式组中**最大重量那一组**的 `(weightKg, reps)`，写入 `suggestedWeightKg / suggestedReps`；系统 MUST NOT 对重量/次数取历史最大值（不合成虚构最佳组合，允许 deload 下降）。

回写 MUST 经由对 `WorkoutPlan` 的本地编辑（`markDirty`）走既有同步域 LWW，MUST NOT 新增独立同步路径。

完成训练页 MUST 展示本次回写的逐项 diff 回执（改值 / 新增 / 已保留），并 MUST 提供「撤销此次更新」入口；撤销 MUST 将计划还原至回写前快照。

#### Scenario: 组数只增不减
- **WHEN** 计划某动作 `suggestedSets=5`，本次只完成 3 个正式组
- **THEN** 回写后 `suggestedSets` 仍为 5（取 max，不因 deload 缩减）

#### Scenario: 重量次数如实写回顶组
- **WHEN** 本次某动作完成 `60kg×8、60kg×8、65kg×5`（均正式组）
- **THEN** 回写 `suggestedWeightKg=65、suggestedReps=5`（最大重量顶组），`suggestedSets=max(现值,3)`

#### Scenario: 训练中新增动作并入计划
- **WHEN** 用户在自适应计划的训练里临时加了一个不在计划中的动作并完成
- **THEN** 该动作以新 `PlanItem` append 到计划末尾（携带本次实绩），下次开始训练即包含它

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

Fork（复制为新计划 / Team 计划模板分发）一个计划时，新计划 MUST 复制 **动作 + 组数（`suggestedSets`） + 次数（`suggestedReps`）**，并 MUST 清空重量（`suggestedWeightKg`）；新计划模式默认 `adaptive`。系统 MUST NOT 在 Fork 时携带原计划的 `suggestedWeightKg` 或任何训练实绩。

#### Scenario: Fork 不带重量
- **WHEN** 用户 Fork 一个已被实绩回写到「深蹲 5 组 × 5 次 × 100kg」的自适应计划
- **THEN** 新计划得到「深蹲 5 组 × 5 次」、重量为空，模式为 `adaptive`

## MODIFIED Requirements

### Requirement: 计划详情（PlanDetail）版式

`PlanDetailView` SHALL 顶部 navbar 显示返回按钮 + 三点菜单；下方 eyebrow（如「PPL · 增肌期 · 第 3 周」）+ 大标题（计划名，多行 `Theme.Font.display(30, .bold)`）+ 3 列 meta（动作数 / 组数 / 当前模式）。动作列表 SHALL 用 `ScrollView` + 自绘 row card，每行：左侧 24pt mono 序号（`Theme.Color.accentCyan` 着色）+ 中间动作名+组×次方案 mono 副标 + 右侧拖拽 handle 图标。

计划详情 SHALL 展示该计划的模式标识（严格 / 自适应），并 SHALL 提供查看该模式回写规则说明的入口（自适应模式说明至少含：组数/次数/重量按实绩更新、训练中新增动作并入计划、跳过的动作保留需手动删）。计划列表与计划详情 MUST NOT 展示按公式估算的预计时长；原预计时长位置 MUST 替换为当前模式。

#### Scenario: 展示模式标识
- **WHEN** 用户进入一个自适应计划的详情页
- **THEN** 页面显示「自适应」模式标识，且可查看其回写规则说明

#### Scenario: 预计时长位置展示模式
- **WHEN** 用户查看计划列表或计划详情
- **THEN** 页面不显示「预计」或「≈N 分钟」这类估算时长
- **AND** 原预计时长位置显示当前模式「严格」或「自适应」

#### Scenario: 计划 JSON 解码失败
- **WHEN** 计划 items 字段解码失败
- **THEN** 列表区显示单张红色占位卡「计划数据损坏，请重建」`Theme.Color.danger`，DEBUG 构建 OSLog 打印原始 payload 前 200 字符

### Requirement: 热身组排除于统计与 PR

所有训练统计 SHALL 以「计入统计的组 = 正式组且已完成」为判据，即 `countsForStats` MUST 定义为 `setType != .warmup && completed`。热身组与**未完成（`completed == false`，含自适应/严格落值后未打勾的预填残组）**的组 MUST NOT 计入。受此约束的口径包括：PR 最大重量（动作库行与动作详情）、周训练量（volume）、周总组数、周总次数、历史强度曲线。被排除的组其记录本身 MUST 完整保留（重量/次数照常录入与展示，未打勾组在结束训练时按「未打勾组清理」处理），仅在统计聚合时被排除。

判据中「排除 `warmup`」部分 SHALL 表达为「非 warmup」而非「仅取 working」，使将来新增的正式类组类型自动计入，无需改动统计逻辑。

#### Scenario: 未完成的预填组不计统计
- **WHEN** 某动作落值了 4 组、用户只完成 2 组（另 2 组未打勾）
- **THEN** 周训练量、周总组数、PR 仅累计已完成的 2 个正式组，未打勾的 2 组不计入

#### Scenario: 热身组不计训练量与组数
- **WHEN** 某动作有 2 个热身组（各 40kg×10、60kg×5）与 3 个已完成正式组（各 80kg×8）
- **THEN** 周训练量只累加 3 个正式组、周总组数只计 3、热身组的 reps 不计入总次数

#### Scenario: 热身组不破 PR
- **WHEN** 某动作的最大重量出现在一个被标为热身组的组里
- **THEN** PR 与历史曲线忽略该热身组，仅按已完成正式组计算
