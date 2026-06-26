## ADDED Requirements

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
