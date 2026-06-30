# team-sharing Specification

## Purpose

定义 DontLift Team 小圈子、共享计划、训练分享与表情回应的服务端权威行为，确保成员权限、计划 Fork、默认私有分享边界和 Team feed 可见性在客户端与后端之间保持一致。
## Requirements
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

### Requirement: 训练打卡与可见性

系统 SHALL 仅在用户明确授权的 Team 中创建训练 checkin：用户可为某个 Team 开启自动分享，或按次将已完成训练分享到一个或多个 Team。未开启自动分享且未按次分享时，训练完成后 MUST 默认仅自己可见，不得自动 fan-out 到所有 Team。Team 内成员可查看已分享训练的摘要与每组重量/次数详情。

#### Scenario: 默认仅自己可见
- **WHEN** 成员完成并保存一次训练，且没有对任何 Team 开启自动分享或执行按次分享
- **THEN** 系统只保存个人训练，不在任何 Team 当日打卡列表中显示

#### Scenario: 分享到已授权 Team
- **WHEN** 成员已对 Team A 开启自动分享并完成训练
- **THEN** 该成员在 Team A 当日打卡列表中显示为已打卡，并附训练摘要

#### Scenario: 查看队友训练详情
- **WHEN** 某成员点击队友已分享到本 Team 的当日打卡条目
- **THEN** 系统展示该次训练每个动作每一组的重量与次数

### Requirement: 表情回应

系统 SHALL 允许成员对 Team 内的训练打卡给予固定 4 个预设 emoji 之一的回应。emoji 集合 MUST 与当前客户端和后端协议保持一致：`fire`/🔥、`muscle`/💪、`heart`/❤️、`clap`/👏。同一成员对同一条训练打卡最多触发一次 APNs 表情提醒；切换 emoji、取消后重新点亮或弱网重复请求 MUST NOT 重复推送。系统 MUST NOT 提供文字评论、群聊或私信功能。

#### Scenario: 给队友打卡点表情
- **WHEN** 成员对某条打卡选择一个 emoji 回应
- **THEN** 该回应记录在此打卡上并对 Team 可见，被回应者收到 APNs 推送

#### Scenario: 切换表情不重复推送
- **WHEN** 成员已经对某条打卡点过表情并触发过 APNs 提醒
- **AND** 该成员切换到另一个 emoji 或取消后重新点亮
- **THEN** 系统更新该成员在该打卡上的回应状态
- **AND** 被回应者不会再次收到该成员对同一打卡的表情提醒

### Requirement: 海报分享

系统 SHALL 在训练完成后允许用户生成一张包含本次训练数据的分享海报，用于分享到外部平台（如微信、小红书）。海报 MUST 由客户端本地生成，服务端仅提供结构化数据。

#### Scenario: 生成训练海报
- **WHEN** 用户在训练完成后选择「生成海报」
- **THEN** 系统在客户端渲染出含训练数据的海报图片，供用户保存或分享到外部

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

### Requirement: Team checkin 历史按月查询

系统 SHALL 提供 Team checkin 历史读取能力，允许当前 Team 成员按自然月查看该 Team 自创建以来仍可见的 checkin。历史范围 MUST 以 `team_checkin` 为准，只包含已经分享到该 Team 且尚未撤回或删除的训练快照；MUST NOT 包含成员未分享到该 Team 的个人训练。

#### Scenario: 按月读取 Team 历史
- **WHEN** 当前成员请求 Team A 在 `2026-06` 的历史 checkin
- **THEN** 系统返回 Team A 在 2026 年 6 月内的所有仍可见 checkin
- **AND** 返回结果按 `checkinDate` 倒序、同日按 `createdAt` 倒序稳定排列
- **AND** 返回结果包含这些 checkin 对应的 reaction 列表

#### Scenario: 当前成员可查看加入前历史
- **WHEN** 当前用户是 Team A 成员，且 Team A 在该用户加入前已有已分享 checkin
- **THEN** 当前用户查看 Team A 历史时可以看到这些仍可见 checkin
- **AND** 系统不按当前用户加入时间截断 Team 历史

#### Scenario: 非成员不可查看历史
- **WHEN** 非 Team A 成员请求 Team A 的历史 checkin
- **THEN** 系统拒绝请求
- **AND** 不返回任何 checkin 摘要或 reaction

#### Scenario: 已撤回或删除的 checkin 不出现在历史
- **WHEN** 某训练曾分享到 Team A，但之后被用户撤回或随个人训练删除同步被移除
- **THEN** Team A 历史查询不再返回该 checkin
- **AND** 该 checkin 下的 reaction 也不再返回

### Requirement: Team checkin 详情使用分享快照

系统 SHALL 使用 `team_checkin.summary` 中的结构化快照作为 Team checkin 详情的数据源。详情 MUST 展示该快照中的动作与每组重量/次数，MUST NOT 要求读取队友原始 `Workout` 聚合树。

#### Scenario: 查看 checkin 快照详情
- **WHEN** Team 成员打开一条仍可见的 checkin 详情
- **THEN** 系统展示该次训练的动作列表
- **AND** 每个动作下展示该快照包含的每组重量与次数

#### Scenario: 原始训练不可读时仍可展示快照
- **WHEN** 某 checkin 的 `workoutId` 软指针对当前用户不可读，或原始训练已不适合作为跨用户读取来源
- **THEN** Team checkin 详情仍使用 `summary` 快照展示
- **AND** 系统不因无法读取原始 `Workout` 而拒绝展示该 checkin 的已授权快照

#### Scenario: 快照损坏降级
- **WHEN** 某 checkin 的 `summary` 无法解析为客户端支持的结构
- **THEN** 系统展示明确的快照不可用状态
- **AND** 不展示 0kg、空动作列表伪装成真实训练详情
