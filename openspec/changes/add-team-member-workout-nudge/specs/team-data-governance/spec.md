## MODIFIED Requirements

### Requirement: Team 训练自动分享偏好

系统 SHALL 将训练完成后的 Team 分享绑定到用户在每个 Team 的自动分享偏好，而非训练归档的无条件副作用。每个用户创建或加入 Team 后，`autoShareWorkouts` 默认 SHALL 为开启；用户手动关闭后，系统 SHALL 保持其关闭选择。系统 MUST NOT 将训练自动分享到用户未开启自动分享的 Team。

#### Scenario: 新成员默认开启自动分享
- **WHEN** 用户创建或加入 Team A
- **THEN** Team A 的 `autoShareWorkouts` 默认为开启
- **AND** 用户后续完成训练时，系统按该偏好为 Team A 创建或更新 checkin

#### Scenario: 全部关闭时仅自己可见
- **WHEN** 用户完成并保存一次训练，且已关闭所有 Team 的自动分享
- **THEN** 系统仅保存个人训练记录，不创建任何 Team checkin

#### Scenario: 重新开启自动分享需确认
- **WHEN** 用户曾关闭 Team A 的自动分享，之后在 Team A 设置中重新打开
- **THEN** 客户端展示一次确认，说明训练摘要和每组记录将对 Team A 成员可见、可随时关闭且可按次撤回
- **AND** 仅当用户确认后，系统才重新保存 Team A 的自动分享偏好

#### Scenario: 自动分享到单个已开启 Team
- **WHEN** 用户对 Team A 开启自动分享、对 Team B 关闭自动分享，并完成训练
- **THEN** 系统仅在 Team A 中创建或更新该训练的 checkin
- **AND** Team B 不出现该训练

#### Scenario: 自动分享到多个已开启 Team
- **WHEN** 用户对 Team A 与 Team B 均开启自动分享，并完成训练
- **THEN** 系统在 Team A 与 Team B 中分别创建或更新该训练的 checkin
- **AND** 每个 checkin 使用同一份训练摘要快照

#### Scenario: 关闭自动分享
- **WHEN** 用户关闭 Team A 的自动分享偏好后再次完成训练
- **THEN** 系统不再为 Team A 创建新的 checkin
- **AND** 关闭偏好不自动删除历史已分享 checkin

#### Scenario: 分享目标校验
- **WHEN** 客户端请求把训练分享到用户并未加入的 Team
- **THEN** 服务端拒绝请求并返回 403，不创建 checkin
