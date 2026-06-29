## MODIFIED Requirements

### Requirement: 私密小空间与成员管理

系统 SHALL 支持创建邀请码加入的私密小空间（Team）。每个 Team MUST 限制至多 10 名成员，每个用户 MUST 至多加入 3 个 Team。Team MUST 包含 Owner（创建者，即业余教练）与 Member 两种角色：Owner 可邀请/移除成员、解散 Team；Member 可分享自己的计划、Fork 他人分享计划、退出 Team。

#### Scenario: 凭邀请码加入
- **WHEN** 用户输入有效邀请码且该 Team 未满 10 人、且本人加入的 Team 未达 3 个
- **THEN** 用户作为 Member 加入该 Team

#### Scenario: 空间已满拒绝加入
- **WHEN** 用户输入的邀请码对应 Team 已有 10 名成员
- **THEN** 系统拒绝加入并提示空间已满

#### Scenario: 超出个人 Team 上限
- **WHEN** 已加入 3 个 Team 的用户尝试加入第 4 个
- **THEN** 系统拒绝并提示已达个人空间数量上限

## REMOVED Requirements

### Requirement: 计划模板发布与 Fork

**Reason**: 旧要求把 Team 计划表达为“发布模板并被 Fork”，容易被理解为作者计划持续暴露和持续联动；新产品语义改为“分享到 Team 的无重量不可变快照版本”，并增加直接开始训练与聚合反馈。

**Migration**: 既有已发布到 Team 的计划 SHALL 迁移为 Team 分享计划的 v1 快照版本，快照中 MUST 去除重量字段。旧的 Fork 行为迁移为“从分享版本 Fork 到我的计划”。

## ADDED Requirements

### Requirement: 计划分享到 Team 与版本快照

系统 SHALL 允许 Team 成员将自己的个人训练计划分享到所在 Team。每次分享到 Team MUST 生成一个不可变的分享计划版本快照；该快照对 Team 当前成员可见，并且 MUST 不包含作者的重量数据。作者后续修改、删除原个人计划，或再次分享新版本，MUST NOT 修改已存在的分享版本、Fork 副本、直接开始产生的训练。

分享版本快照 SHALL 至少包含计划名快照、作者、版本号、动作顺序、动作引用与名称快照、组数和次数。分享版本中的每个动作项 MUST 保留稳定 `itemId` 或等价稳定项标识，供 Fork、直接开始和训练来源软关联使用。计划模式 MUST NOT 作为分享计划的用户可见属性或采用后的强制规则；使用者 Fork 后可自行决定个人计划模式，直接开始训练按使用者侧预填逻辑生成本次训练。

新版客户端 MAY 在分享请求中携带当前本地计划名与 items 快照；服务端仍 MUST 校验 `sourcePlanId` 归属，并在创建分享版本前剥离重量字段。若快照格式异常，系统 MUST 拒绝分享，MUST NOT 原样保存可能包含重量的内容。

#### Scenario: 分享计划生成无重量版本
- **WHEN** Team 成员将个人计划「推日 A」分享到 Team A
- **THEN** 系统为 Team A 创建或追加一个分享计划版本
- **AND** 版本快照包含动作、组数、次数和名称快照
- **AND** 版本快照 MUST NOT 包含作者原计划中的重量

#### Scenario: 再次分享生成新版本
- **WHEN** 作者修改个人计划「推日 A」后再次分享到同一 Team
- **THEN** 系统为该 Team 分享计划追加新版本
- **AND** 旧版本保持不可变
- **AND** 已基于旧版本 Fork 或直接开始的训练不接收新版本更新

#### Scenario: 作者删除原计划不影响分享版本
- **WHEN** 作者删除已分享到 Team 的原个人计划
- **THEN** 既有 Team 分享计划版本仍可按快照展示
- **AND** 既有 Fork 副本仍然保留可用

#### Scenario: 作者删除自己的 Team 分享计划
- **WHEN** Team 成员查看自己分享到 Team A 的分享计划
- **THEN** 系统允许该成员删除自己的分享计划
- **AND** 删除后该分享计划不再出现在 Team A 的分享计划列表
- **AND** 已经 Fork 出去的个人计划不受影响

#### Scenario: 不能删除他人分享计划
- **WHEN** Team 成员尝试删除其他成员分享到 Team A 的分享计划
- **THEN** 系统拒绝请求
- **AND** 他人的分享计划仍保留在 Team A 的分享计划列表

#### Scenario: 非成员不能分享计划到 Team
- **WHEN** 非 Team A 成员尝试将计划分享到 Team A
- **THEN** 系统拒绝请求
- **AND** 不创建分享计划或分享版本

### Requirement: 分享计划版本采用

系统 SHALL 允许 Team 成员对某个分享计划版本执行两种采用方式：Fork 到我的计划，或直接开始一次训练。Fork 后创建归属当前用户的独立 `WorkoutPlan`；直接开始训练则不创建个人计划。两种采用方式都 MUST 只保留与分享版本的软关联，MUST NOT 建立后续自动同步或增量更新关系。

#### Scenario: 从分享版本 Fork
- **WHEN** Team 成员 Fork Team A 中的「推日 A」v2
- **THEN** 系统创建一个归属该成员的独立个人计划
- **AND** 该计划默认私有，不自动分享到任何 Team
- **AND** 该计划不包含作者重量
- **AND** 作者后续分享 v3 不会更新该 Fork 副本

#### Scenario: 再次 Fork 新版本创建新计划
- **WHEN** 成员已经 Fork 过「推日 A」v1，之后又 Fork 「推日 A」v2
- **THEN** 系统创建另一份新的个人计划
- **AND** 不把 v2 增量合并进 v1 的 Fork 副本

#### Scenario: 直接开始训练
- **WHEN** Team 成员选择从「推日 A」v2 直接开始训练
- **THEN** 系统基于 v2 快照生成一次训练
- **AND** 不创建新的个人计划
- **AND** 该训练只保留来源分享版本软关联

#### Scenario: 非成员不能采用分享版本
- **WHEN** 非 Team A 成员尝试 Fork 或直接开始 Team A 的分享计划版本
- **THEN** 系统拒绝请求

### Requirement: 分享计划反馈统计

系统 SHALL 为 Team 分享计划记录最小化反馈事件，用于展示聚合统计。反馈事件 SHALL 支持至少三类：`fork`、`direct_start`、`complete`。反馈事件 MUST NOT 包含训练 summary、重量、次数、动作组详情或备注；MUST NOT 因自身存在而创建 Team checkin。

Team 计划页 SHALL 能展示“复制人数”和“总完成次数”等聚合数据。复制人数 SHALL 按用户去重统计执行过 `fork` 的成员；直接开始训练 MUST NOT 计入复制人数。总完成次数 SHALL 统计该分享计划全部 `complete` 事件数量。带 `workoutId` 的反馈事件 SHOULD 按分享版本、事件类型、用户与 `workoutId` 去重，避免弱网重试重复增加完成次数。

#### Scenario: Fork 计入复制人数
- **WHEN** Team 成员 Fork 某分享计划版本
- **THEN** 系统记录 `fork` 反馈事件
- **AND** 该成员计入该分享计划的复制人数

#### Scenario: 直接开始不计入复制人数
- **WHEN** Team 成员从某分享计划版本直接开始训练
- **THEN** 系统记录 `direct_start` 反馈事件
- **AND** 该成员不计入该分享计划的复制人数

#### Scenario: 完成训练计入完成次数但不公开详情
- **WHEN** Team 成员完成一场来源于 Team 分享计划版本的训练，且未开启自动分享也未按次分享到 Team
- **THEN** 系统可以记录 `complete` 反馈事件
- **AND** Team 计划页的总完成次数可增加
- **AND** 该反馈不应因为本地训练尚未完成同步而长期丢失
- **AND** 弱网重试同一训练的完成反馈不应重复增加完成次数
- **AND** Team feed、Team 历史和 checkin 详情 MUST NOT 展示该训练

#### Scenario: 分享训练时同时保留 checkin 边界
- **WHEN** Team 成员完成来源于分享计划版本的训练，并按既有规则分享到 Team A
- **THEN** 系统创建或更新 Team checkin
- **AND** 系统仍可记录 `complete` 反馈事件
- **AND** checkin 可见性继续遵守训练打卡与可见性要求

#### Scenario: 聚合统计不展示成员明细
- **WHEN** Team 成员查看 Team 分享计划卡片
- **THEN** 系统展示复制人数和总完成次数等聚合数字
- **AND** 不展示未分享训练的成员名单、训练详情、重量或组数据
