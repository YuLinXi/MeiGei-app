## ADDED Requirements

### Requirement: 训练计划分组模型

系统 SHALL 提供独立的 `WorkoutPlanGroup` 同步实体，用于管理训练计划分组。分组 MUST 属于单个用户，并携带与其它同步实体一致的同步信封：`localId/serverId/updatedAt/deletedAt/version/syncStatus`。分组 MUST 至少包含 `name` 与 `sortOrder` 字段。

`WorkoutPlan` SHALL 增加 `groupId` 与 `sortOrder` 字段。`groupId == nil` 表示未分组；当 `groupId` 引用的分组不存在或已删除时，客户端 MUST 将该计划按「未分组」展示，而不是隐藏或崩溃。

#### Scenario: 旧计划进入未分组
- **GIVEN** 用户已有旧版本创建的计划
- **WHEN** App 升级到支持计划分组的版本
- **THEN** 旧计划 SHALL 保留
- **AND** 旧计划 SHALL 以「未分组」展示

#### Scenario: 分组可独立排序
- **WHEN** 用户调整分组顺序
- **THEN** 系统 SHALL 更新各 `WorkoutPlanGroup.sortOrder`
- **AND** 计划自身的 `sortOrder` 与 `groupId` 不应因分组排序被修改

#### Scenario: 计划可在组内排序
- **WHEN** 用户调整同一分组内的计划顺序
- **THEN** 系统 SHALL 更新该组内计划的 `WorkoutPlan.sortOrder`
- **AND** 不应修改其它分组内计划的顺序

#### Scenario: 引用缺失分组时容错
- **GIVEN** 某计划的 `groupId` 指向一个本地尚未同步到或已经软删的分组
- **WHEN** 用户打开计划列表
- **THEN** 该计划 SHALL 显示在「未分组」
- **AND** 计划数据不得丢失

### Requirement: 计划分组管理

用户 SHALL 能在计划模块中新建、重命名、排序和删除计划分组。删除分组 MUST 经过二次确认。删除分组 MUST NOT 删除组内计划；系统 SHALL 将组内计划移动到「未分组」，并把这些计划标脏以进入同步队列。

#### Scenario: 新建分组
- **WHEN** 用户在计划页新建分组并输入名称
- **THEN** 系统 SHALL 创建 `WorkoutPlanGroup`
- **AND** 新分组 SHALL 追加到分组列表末尾

#### Scenario: 重命名分组
- **WHEN** 用户重命名某个分组
- **THEN** 系统 SHALL 仅更新该分组的 `name`
- **AND** 组内计划的 `groupId` SHALL 保持不变

#### Scenario: 删除分组但保留计划
- **GIVEN** 分组「胸背」下存在计划 A 与计划 B
- **WHEN** 用户确认删除「胸背」分组
- **THEN** 「胸背」分组 SHALL 被软删
- **AND** 计划 A 与计划 B SHALL 保留
- **AND** 计划 A 与计划 B 的 `groupId` SHALL 变为 nil
- **AND** 计划 A 与计划 B SHALL 出现在「未分组」

#### Scenario: 空分组保留
- **WHEN** 用户创建一个暂时没有计划的分组
- **THEN** 该分组 SHALL 作为实体保留
- **AND** 计划列表或分组管理入口 SHALL 能让用户看到该空分组

## MODIFIED Requirements

### Requirement: 计划列表（PlanList）版式

`PlanListView` SHALL 按计划分组展示用户的训练计划。计划列表 MUST NOT 使用「最近在用」计划置顶 featured 卡；所有计划 MUST 使用同一种标准计划卡片。计划页不再通过视觉强调表达 active/featured/最近使用状态。

计划列表 SHALL 按以下结构渲染：

- 非删除的 `WorkoutPlanGroup` 按 `sortOrder` 升序展示；同值时按 `updatedAt` 倒序兜底。
- 每个分组下展示 `groupId` 指向该分组的非删除计划。
- 组内计划按 `sortOrder` 升序展示；同值时按 `updatedAt` 倒序兜底。
- `groupId == nil`、引用缺失分组或引用已删除分组的计划 SHALL 展示在「未分组」。
- 「未分组」默认排在实体分组之后。
- 当没有任何计划且没有任何分组时，显示全局空状态。

每张标准计划卡 SHALL 至少包含：

- 计划名。
- 当前模式（严格 / 自适应）。
- 动作数与总组数。
- 模式行为摘要。
- 可由本地训练记录重算的使用摘要，例如累计训练次数与上次训练时间。

计划卡 MUST NOT 因最近使用而切换为更大尺寸、左侧强调条、三列 meta featured 卡、渐变或额外强调阴影。「最近在用」判定 MAY 继续用于训练首页 CTA 的默认计划选择，但 MUST NOT 影响计划 Tab 的排序与视觉层级。

「推荐模板」段在内置动作库数据采集完成前 MUST NOT 渲染（连同其段标题 eyebrow）。

#### Scenario: 按分组展示计划
- **GIVEN** 用户有分组「胸背」「腿」与若干计划
- **WHEN** 用户进入计划页
- **THEN** 页面 SHALL 先展示「胸背」分组及其计划
- **AND** 再按分组 `sortOrder` 展示其它分组
- **AND** 未归属任何分组的计划 SHALL 展示在「未分组」

#### Scenario: 所有计划卡片标准化
- **GIVEN** 用户有多个计划，其中某计划最近 14 天内被训练过
- **WHEN** 用户进入计划页
- **THEN** 该计划 MUST NOT 以 featured 卡或置顶富卡展示
- **AND** 所有计划 SHALL 使用同一种标准计划卡片

#### Scenario: 计划页排序不受最近使用影响
- **GIVEN** 计划 A 最近训练过，计划 B 未训练但排序在 A 前
- **WHEN** 用户进入计划页
- **THEN** 计划 B 仍 SHALL 按 `sortOrder` 排在计划 A 前
- **AND** 最近使用状态不应改变计划 Tab 的排序

#### Scenario: 无计划无分组
- **WHEN** 用户没有任何计划且没有任何分组
- **THEN** 计划页 SHALL 显示全局空状态，引导新建计划或新建分组

#### Scenario: 推荐模板段在数据未就绪时隐藏
- **WHEN** 内置动作库数据尚未采集完成，用户进入计划页
- **THEN** 页面 MUST NOT 渲染「推荐模板」段标题或占位卡

### Requirement: 计划 Fork 字段规则

Fork（复制为新计划 / Team 计划模板分发）一个计划时，新计划 MUST 复制 **动作 + 组数（`suggestedSets`） + 次数（`suggestedReps`）**，并 MUST 清空重量（`suggestedWeightKg`）；新计划模式默认 `adaptive`。系统 MUST NOT 在 Fork 时携带原计划的 `suggestedWeightKg` 或任何训练实绩。

Fork 得到的新计划 MUST 默认归入接收者的「未分组」（`groupId == nil`），并按接收者未分组列表的末尾生成 `sortOrder`。系统 MUST NOT 把发布者或源计划的分组结构复制给接收者。

#### Scenario: Fork 不带重量
- **WHEN** 用户 Fork 一个已被实绩回写到「深蹲 5 组 × 5 次 × 100kg」的自适应计划
- **THEN** 新计划得到「深蹲 5 组 × 5 次」、重量为空，模式为 `adaptive`

#### Scenario: Fork 默认未分组
- **WHEN** 用户 Fork 一个属于发布者「胸背」分组的 Team 计划
- **THEN** 接收者的新计划 `groupId` SHALL 为 nil
- **AND** 新计划 SHALL 显示在接收者的「未分组」
