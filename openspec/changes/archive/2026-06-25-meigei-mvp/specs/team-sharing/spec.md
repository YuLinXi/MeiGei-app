## ADDED Requirements

### Requirement: 私密小空间与成员管理

系统 SHALL 支持创建邀请码加入的私密小空间（Team）。每个 Team MUST 限制至多 10 名成员，每个用户 MUST 至多加入 3 个 Team。Team MUST 包含 Owner（创建者，即业余教练）与 Member 两种角色：Owner 可邀请/移除成员、解散 Team；Member 可发布自己的计划、Fork 他人计划、退出 Team。

#### Scenario: 凭邀请码加入
- **WHEN** 用户输入有效邀请码且该 Team 未满 10 人、且本人加入的 Team 未达 3 个
- **THEN** 用户作为 Member 加入该 Team

#### Scenario: 空间已满拒绝加入
- **WHEN** 用户输入的邀请码对应 Team 已有 10 名成员
- **THEN** 系统拒绝加入并提示空间已满

#### Scenario: 超出个人 Team 上限
- **WHEN** 已加入 3 个 Team 的用户尝试加入第 4 个
- **THEN** 系统拒绝并提示已达个人空间数量上限

### Requirement: 计划模板发布与 Fork

系统 SHALL 允许成员将训练计划模板发布到所在 Team，发布的模板对全体成员可见。其他成员 SHALL 可将模板 Fork 为归属自己的独立副本，Fork 后双方互不影响。作者后续修改或删除原模板 MUST NOT 影响已存在的 Fork 副本。

#### Scenario: 发布并被 Fork
- **WHEN** Owner 发布「推日 A」模板，Member 点击 Fork
- **THEN** 系统为该 Member 复制出一份独立可编辑的副本，原模板不受其后续修改影响

#### Scenario: 原模板删除不影响副本
- **WHEN** 作者删除已被他人 Fork 的原模板
- **THEN** 已 Fork 的副本仍然保留可用

### Requirement: 训练打卡与可见性

系统 SHALL 在成员完成一次训练并保存后，自动在其所在 Team 内生成当日打卡。Team 内成员的训练数据 SHALL 对全体成员可见：打卡列表展示训练摘要，点击可查看每组重量与次数的详情（MVP 不做可见性权限控制）。

#### Scenario: 训练即打卡
- **WHEN** 成员完成并保存一次训练
- **THEN** 该成员在其 Team 当日打卡列表中显示为已打卡，并附训练摘要

#### Scenario: 查看队友训练详情
- **WHEN** 某成员点击队友的当日打卡条目
- **THEN** 系统展示该次训练每个动作每一组的重量与次数

### Requirement: 表情回应

系统 SHALL 允许成员对 Team 内的训练打卡给予 4 个预设 emoji（💪🔥👏❤️）之一的回应。系统 MUST NOT 提供文字评论、群聊或私信功能。

#### Scenario: 给队友打卡点表情
- **WHEN** 成员对某条打卡选择一个 emoji 回应
- **THEN** 该回应记录在此打卡上并对 Team 可见，被回应者收到 APNs 推送

### Requirement: 海报分享

系统 SHALL 在训练完成后允许用户生成一张包含本次训练数据的分享海报，用于分享到外部平台（如微信、小红书）。海报 MUST 由客户端本地生成，服务端仅提供结构化数据。

#### Scenario: 生成训练海报
- **WHEN** 用户在训练完成后选择「生成海报」
- **THEN** 系统在客户端渲染出含训练数据的海报图片，供用户保存或分享到外部
