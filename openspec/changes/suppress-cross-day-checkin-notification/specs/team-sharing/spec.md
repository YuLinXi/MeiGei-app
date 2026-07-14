## MODIFIED Requirements

### Requirement: 训练打卡与可见性

系统 SHALL 仅在用户明确授权的 Team 中创建训练 checkin：用户可为某个 Team 开启自动分享，或按次将已完成训练分享到一个或多个 Team。未开启自动分享且未按次分享时，训练完成后 MUST 默认仅自己可见，不得自动 fan-out 到所有 Team。Team 内成员可查看已分享训练的摘要与每组重量/次数详情。

系统 MUST 始终将获授权分享的训练创建或更新到其权威 `checkinDate`。仅在 checkin 首次创建且客户端未要求静默时，系统 SHALL 向同 Team 的其他成员发送训练完成 APNs；摘要更新 MUST NOT 重复通知。客户端 MUST 在每次实际发送请求时比较 `checkinDate` 与发送时的客户端本地日期，非同一自然日的自动分享或按次分享 MUST 要求静默，不得在 pending intent 入队时固化该判断。缺少静默字段的旧版客户端请求 MUST 按未要求静默处理。

#### Scenario: 默认仅自己可见
- **WHEN** 成员完成并保存一次训练，且没有对任何 Team 开启自动分享或执行按次分享
- **THEN** 系统只保存个人训练，不在任何 Team 当日打卡列表中显示

#### Scenario: 分享到已授权 Team
- **WHEN** 成员已对 Team A 开启自动分享并完成训练
- **THEN** 该成员在 Team A 当日打卡列表中显示为已打卡，并附训练摘要

#### Scenario: 查看队友训练详情
- **WHEN** 某成员点击队友已分享到本 Team 的当日打卡条目
- **THEN** 系统展示该次训练每个动作每一组的重量与次数

#### Scenario: 当日首次分享通知其他成员
- **WHEN** 客户端在训练 `checkinDate` 对应的本地自然日首次将训练分享到 Team A
- **THEN** 系统创建该日期的 checkin
- **AND** 仅向 Team A 中除训练者以外的成员发送一次训练完成 APNs

#### Scenario: 跨日补录静默写入历史
- **WHEN** 客户端在 `checkinDate` 之后的本地自然日自动重放或按次分享该训练
- **THEN** 系统仍在原 `checkinDate` 创建或更新 checkin
- **AND** 系统不查询通知接收者或发送训练完成 APNs

#### Scenario: 当日弱网重试仍可通知
- **WHEN** 当日分享因弱网进入 pending 队列并在同一客户端本地自然日实际发送
- **THEN** 客户端按未静默提交请求
- **AND** 系统在首次创建 checkin 时正常通知其他成员

#### Scenario: 已存在 checkin 的摘要更新不重复通知
- **WHEN** 客户端再次提交已存在 checkin 的更新摘要
- **THEN** 系统更新 checkin 摘要和日期
- **AND** 系统不重复发送训练完成 APNs

#### Scenario: 旧版客户端请求保持通知行为
- **WHEN** 旧版客户端首次提交不含 `suppressNotification` 字段的 checkin 请求
- **THEN** 系统按未要求静默处理
- **AND** 系统正常创建 checkin 并通知其他成员
