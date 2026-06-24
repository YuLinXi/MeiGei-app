## MODIFIED Requirements

### Requirement: 服务端账号级联硬删

账号删除 SHALL 在单一数据库事务内**物理硬删**(非软删墓碑)该 user 名下的个人数据,使 Apple 审核可验证「数据已真正删除」。删除范围 MUST 覆盖:`user_identity`、`idempotency_key`、`device_token`、`custom_exercise`、`workout_plan`、`workout` 及其子树(`workout_exercise` / `workout_set`,随聚合根 CASCADE)、该用户自己的 `team_member`、该用户自己的 `team_checkin`、该用户自己的 `checkin_reaction`,以及最后的 `app_user` 行。事务内任一步失败 MUST 整体回滚,不留半删状态。

账号删除 MUST NOT 默认物理删除其他用户的 `team_member`、`team_checkin` 或 `checkin_reaction`。若被删用户是 Team owner,系统 SHALL 按「团主删号转移 Team owner」处理 Team 归属,而不是把其他成员数据纳入本次账号级联硬删。

#### Scenario: 级联删除全部本人数据
- **WHEN** 用户删除账号
- **THEN** 上述所有表中归属该 user 的个人行被物理删除,`app_user` 行被删除,数据库中查不到该 user 任何残留(幂等键、设备 token、训练/计划/自定义动作、Team 成员关系与本人打卡、本人表情回应)。

#### Scenario: 不删除其他成员历史
- **WHEN** Team owner 删除账号,且 Team 中存在其他成员
- **THEN** 其他成员的 `team_member`、`team_checkin` 与 `checkin_reaction` 不因本次账号删除而被物理删除

#### Scenario: 事务失败整体回滚
- **WHEN** 级联删除过程中某一步抛错
- **THEN** 整个事务回滚,用户数据保持删除前状态,接口返回错误(非 2xx),不产生半删数据。

### Requirement: 删号影响面预览

后端 SHALL 提供只读接口 `GET /account/deletion-impact`,返回当前用户删号将造成的影响面。返回值 MUST 至少包含:用户拥有且仍有其他成员的 `ownedTeamsToTransfer`、将自动删除的空 Team 数 `emptyOwnedTeamsToDelete`、将被转移 owner 的候选成员摘要或数量、该用户自己的 checkin/reaction 数量。客户端 SHALL 在删号二次确认框中展示:账号与本人数据将永久删除、多人 Team 将保留并转移 owner、空 Team 将删除。该接口 MUST NOT 修改任何数据。

#### Scenario: 返回 owner 转移影响
- **WHEN** 已登录 owner 请求 `GET /account/deletion-impact`,且其拥有 1 个仍有成员的 Team
- **THEN** 返回 `ownedTeamsToTransfer=1`,并说明该 Team 不会因删号解散

#### Scenario: 返回空 Team 删除数
- **WHEN** 用户拥有一个只有自己的 Team
- **THEN** 返回 `emptyOwnedTeamsToDelete=1`

#### Scenario: 无团队时影响为零
- **WHEN** 用户未拥有任何团队
- **THEN** 返回 `ownedTeamsToTransfer=0`、`emptyOwnedTeamsToDelete=0`。

## REMOVED Requirements

### Requirement: 团主删号解散其团队

**Reason**: 团主删除个人账号不应默认删除其他成员贡献的 Team 历史；这会超出删号用户自身数据范围并损害成员信任。

**Migration**: 用新增的「团主删号转移 Team owner」要求替代。独立“解散 Team”仍作为 Team 管理操作存在，但必须由 owner 在 Team 管理页强确认，不能由账号删除隐式触发。

## ADDED Requirements

### Requirement: 团主删号转移 Team owner

当被删账号是某 `team` 的 owner 时,系统 SHALL 在同一事务内处理 Team 归属。若该 Team 仍有其他成员,系统 SHALL 将 owner 转移给剩余成员之一,保留 Team 及其他成员产生的 checkin/reaction。若该 Team 没有其他成员,系统 SHALL 删除该空 Team。当被删账号仅是普通成员时,SHALL 仅移除其 `team_member` 行及该用户产生的打卡/表情,团队本身与其他成员数据保留。

#### Scenario: 团主删号转移 owner
- **WHEN** 一名 team owner 删除账号,且该 Team 还有其他成员
- **THEN** 被删用户的成员关系、本人打卡、本人表情被删除
- **AND** Team 保留,其他成员数据保留
- **AND** 一名剩余成员成为新的 owner

#### Scenario: 团主删号删除空 Team
- **WHEN** 一名 team owner 删除账号,且该 Team 没有其他成员
- **THEN** 该空 Team 被删除

#### Scenario: 成员删号不影响团队
- **WHEN** 一名普通成员删除账号
- **THEN** 其 `team_member` 行与本人打卡/表情被删除,团队及其他成员数据不受影响。

### Requirement: 解散 Team 与删除账号分离

系统 SHALL 将解散 Team 作为独立的 owner 管理操作。解散 Team MUST 有单独强确认,确认文案必须说明会删除该 Team 的成员关系、checkin 与 reaction。删除账号流程中的确认 MUST NOT 授权解散仍有其他成员的 Team。

#### Scenario: 删除账号不解散多人 Team
- **WHEN** owner 在账号页确认删除账号
- **THEN** 系统不得把该确认解释为解散多人 Team 的授权

#### Scenario: 独立解散强确认
- **WHEN** owner 在 Team 管理页选择解散 Team
- **THEN** 系统展示独立强确认,确认后才删除该 Team 的共享数据
