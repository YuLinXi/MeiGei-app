## ADDED Requirements

### Requirement: Team 训练自动分享偏好

系统 SHALL 将训练完成后的 Team 分享绑定到用户在每个 Team 的自动分享偏好，而非训练归档的无条件副作用。每个用户加入每个 Team 后，`autoShareWorkouts` 默认 SHALL 为关闭。只有当用户在该 Team 中首次明确确认开启自动分享后，系统才 SHALL 在后续训练完成时为该 Team 创建或更新 checkin。系统 MUST NOT 将训练自动分享到用户未开启自动分享的 Team。

#### Scenario: 默认仅自己可见
- **WHEN** 用户完成并保存一次训练，且未对任何 Team 开启自动分享
- **THEN** 系统仅保存个人训练记录，不创建任何 Team checkin

#### Scenario: 首次开启自动分享需确认
- **WHEN** 用户在 Team A 设置中打开「训练完成后自动分享到此 Team」
- **THEN** 客户端展示一次确认，说明训练摘要和每组记录将对 Team A 成员可见、可随时关闭且可按次撤回
- **AND** 仅当用户确认后，系统才保存 Team A 的自动分享偏好

#### Scenario: 自动分享到单个已授权 Team
- **WHEN** 用户已对 Team A 开启自动分享，未对 Team B 开启自动分享，并完成训练
- **THEN** 系统仅在 Team A 中创建或更新该训练的 checkin
- **AND** 用户所属的其他 Team 不出现该训练

#### Scenario: 自动分享到多个已授权 Team
- **WHEN** 用户已对 Team A 与 Team B 开启自动分享，并完成训练
- **THEN** 系统在 Team A 与 Team B 中分别创建或更新该训练的 checkin
- **AND** 每个 checkin 使用同一份训练摘要快照

#### Scenario: 关闭自动分享
- **WHEN** 用户关闭 Team A 的自动分享偏好后再次完成训练
- **THEN** 系统不再为 Team A 创建新的 checkin
- **AND** 关闭偏好不自动删除历史已分享 checkin

#### Scenario: 分享目标校验
- **WHEN** 客户端请求把训练分享到用户并未加入的 Team
- **THEN** 服务端拒绝请求并返回 403，不创建 checkin

### Requirement: Team 分享离线意图与幂等

系统 SHALL 支持用户在离线或弱网时完成训练而不阻塞本地归档。若用户未对任何 Team 开启自动分享，系统 MUST NOT 创建待分享意图。若用户已对一个或多个 Team 开启自动分享但分享请求失败，客户端 SHALL 保存 pending share intent，并在网络恢复且训练同步成功后重试。每个 Team 分享写入 MUST 使用幂等键，重复重试不得产生重复 checkin。

#### Scenario: 离线完成但未开启分享
- **WHEN** 用户离线完成训练且未对任何 Team 开启自动分享
- **THEN** 本地训练正常归档
- **AND** 系统不保存任何 Team 分享重试任务

#### Scenario: 离线自动分享排队
- **WHEN** 用户已对 Team A 开启自动分享，并在离线时完成训练
- **THEN** 本地训练正常归档
- **AND** 客户端保存 Team A 的 pending share intent，待网络恢复后重试

#### Scenario: 重试幂等
- **WHEN** 同一 pending share intent 因弱网重试多次
- **THEN** 服务端至多保留一条 `(teamId, userId, workoutId)` 对应的 checkin

### Requirement: 已分享训练可按 Team 撤回

系统 SHALL 允许用户撤回某次训练在某个 Team 的可见性。撤回后，该 Team 的 checkin 列表 MUST 移除该训练，且该 checkin 下的表情回应 MUST 一并删除或不可见。撤回一个 Team 的可见性 MUST NOT 影响该训练在其他 Team 的可见性，也 MUST NOT 删除用户本人的训练记录。

#### Scenario: 撤回单个 Team
- **WHEN** 用户将已分享到 Team A 与 Team B 的训练从 Team A 撤回
- **THEN** Team A 不再显示该训练 checkin
- **AND** Team B 仍显示该训练 checkin
- **AND** 用户个人训练记录仍保留

#### Scenario: 撤回删除反应
- **WHEN** 用户撤回某条 Team checkin
- **THEN** 该 checkin 的所有 emoji 反应不再出现在 Team feed 中

### Requirement: 共享计划项动作快照

系统 SHALL 在训练计划 `PlanItem` 中保存动作引用之外的展示快照。每个新写入或重新发布到 Team 的计划项 MUST 包含稳定 `itemId`、`exerciseRef`、`exerciseName`，并在可获得时包含 `primaryMuscle` 与 `equipmentType`。客户端展示 Team 计划、Fork 计划或由计划开始训练时，若本地动作库无法解析 `exerciseRef`，MUST 使用快照字段作为 fallback。

#### Scenario: 新发布计划写入快照
- **WHEN** 用户发布包含「哑铃卧推」的计划到 Team
- **THEN** 该计划项 JSON 同时包含 `exerciseRef` 与 `exerciseName="哑铃卧推"`

#### Scenario: 旧客户端遇到未知 builtin code
- **WHEN** 客户端动作库不认识某 Team 计划项的 `builtin` code，但该计划项包含 `exerciseName`
- **THEN** 客户端使用快照名称展示该动作，不显示空白或崩溃

#### Scenario: Fork 保留快照
- **WHEN** 用户 Fork 一个包含动作快照的 Team 计划
- **THEN** 新计划副本保留每个计划项的 `exerciseName`、`primaryMuscle` 与 `equipmentType` fallback 字段

#### Scenario: 缺失快照且无法解析
- **WHEN** 客户端既无法解析 `exerciseRef`，又无法读取动作快照
- **THEN** 客户端显示明确的计划数据损坏提示，并阻止直接开始训练

### Requirement: Team owner 删除账号不删除成员历史

当 Team owner 删除账号时，系统 SHALL 仅删除该 owner 自身的数据和成员关系，不得默认删除其他成员的 Team checkin、reaction 或 Fork 副本。若该 Team 仍有其他成员，系统 SHALL 将 owner 角色转移给剩余成员之一并保留 Team。若该 Team 没有其他成员，系统 SHALL 删除该空 Team。

#### Scenario: 团主删号且仍有成员
- **WHEN** Team owner 删除账号，且该 Team 中还有其他成员
- **THEN** 系统删除 owner 自身数据
- **AND** Team 保留，其他成员的 checkin 与 reaction 保留
- **AND** 其中一名剩余成员成为新的 owner

#### Scenario: 团主删号且无其他成员
- **WHEN** Team owner 删除账号，且该 Team 没有其他成员
- **THEN** 系统删除该空 Team

#### Scenario: Fork 副本不受影响
- **WHEN** 被删除 owner 曾发布计划且其他成员已 Fork
- **THEN** 其他成员自己的 Fork 副本继续保留可用

### Requirement: 解散 Team 独立强确认

系统 SHALL 将“解散 Team”作为独立 Team 管理操作，而非账号删除流程的隐式副作用。解散 Team MUST 仅允许当前 owner 执行，并 MUST 展示强确认文案，说明 Team、成员关系、Team checkin 与 reaction 将被删除。用户删除账号的确认框 MUST NOT 兼作解散 Team 的确认。

#### Scenario: owner 主动解散 Team
- **WHEN** Team owner 在 Team 管理页选择解散并通过强确认
- **THEN** 系统删除该 Team 及其 Team 级成员关系、checkin 与 reaction

#### Scenario: 删号不等于解散
- **WHEN** Team owner 在账号页执行删除账号
- **THEN** 系统执行账号删除流程，不把该确认视为解散 Team 的授权
