## ADDED Requirements

### Requirement: Team 历史训练月历页

iOS SHALL 在 `TeamDetailView` 提供「历史训练」入口，进入 Team 历史训练月历页。该页面 SHALL 复用个人历史日历的核心交互模型：月份标题、月份选择、左右切月、今天入口、42 格月历、选中日期抽屉。数据源 SHALL 来自 Team checkin 历史接口，而不是本地 `WorkoutHistoryStore`。

#### Scenario: 从 Team 详情进入历史月历
- **WHEN** 用户进入 Team 详情页
- **THEN** 页面提供「历史训练」入口
- **AND** 点击后进入该 Team 的历史训练月历页

#### Scenario: 月历展示 Team 训练日
- **WHEN** Team A 在某月存在仍可见 checkin
- **THEN** Team 历史月历中有 checkin 的日期显示训练摘要
- **AND** 同日多条 checkin 显示额外数量提示
- **AND** 选中日期抽屉展示该日期的 Team checkin 列表

#### Scenario: 月份切换加载对应 Team 历史
- **WHEN** 用户在 Team 历史月历中切换到另一个月份
- **THEN** 客户端加载该 Team 该月份的 checkin 历史
- **AND** 不通过逐日请求拼装整月数据

#### Scenario: 选择月份
- **WHEN** 用户点击 Team 历史月历月份旁的选择图标
- **THEN** 页面弹出与个人历史一致的月份档案 sheet
- **AND** 用户选择某月后直接跳转到该月并加载该月 Team 历史

#### Scenario: 空月份和空日期
- **WHEN** Team 在当前月份或选中日期没有可见 checkin
- **THEN** 页面展示 Team 语境下的轻量空状态
- **AND** 不跳转、不报错、不显示个人训练历史文案

### Requirement: Team checkin 详情展示

iOS SHALL 允许用户从 Team 今日动态卡片和 Team 历史月历的 checkin 行打开同一套 checkin 详情视图。详情 SHALL 使用 `TeamCheckinDTO.parsedSummary` 渲染，不依赖本地 SwiftData 中是否存在原始 `Workout`。

#### Scenario: 从今日动态打开详情
- **WHEN** 用户点击 Team 今日动态中的一条 checkin
- **THEN** 页面打开 Team checkin 详情
- **AND** 详情展示该训练的标题、时间、动作数、组数、训练量摘要
- **AND** 详情展示每个动作与每组重量/次数

#### Scenario: 从历史月历打开详情
- **WHEN** 用户在 Team 历史月历的选中日期抽屉中点击一条 checkin
- **THEN** 页面打开与今日动态相同的 Team checkin 详情视图
- **AND** 详情内容来自该 checkin 的分享快照

#### Scenario: 旧快照解析失败
- **WHEN** 客户端无法解析某条 checkin 的 `summary`
- **THEN** 详情展示「训练快照不可用」类空状态
- **AND** 不展示 0 或空列表作为真实数据

### Requirement: 日历组件复用

iOS SHALL 抽取个人历史与 Team 历史共用的日历展示壳或等价组件，使两者共享月份 Header、月历网格、月份选择 Sheet 与选中日期抽屉的布局行为。个人历史与 Team 历史 SHALL 保持独立数据源和详情目标。

#### Scenario: 个人历史行为保持不变
- **WHEN** 用户进入个人历史日历
- **THEN** 页面仍使用本地 `WorkoutHistoryStore` 派生快照展示个人训练
- **AND** 点击训练仍进入 `WorkoutDetailView`

#### Scenario: Team 历史使用服务端数据
- **WHEN** 用户进入 Team 历史日历
- **THEN** 页面使用 Team checkin 历史接口数据
- **AND** 点击 checkin 进入 Team checkin 详情
- **AND** 个人历史和 Team 历史不共用同一个数据 store
