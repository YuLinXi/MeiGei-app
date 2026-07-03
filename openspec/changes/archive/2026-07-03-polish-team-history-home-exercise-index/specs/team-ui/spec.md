## ADDED Requirements

### Requirement: Team 历史月份档案完整范围

iOS SHALL 在 Team 历史训练的「选择月份」sheet 中展示从该 Team 创建月份到当前月份的完整可选月份范围，而不是只展示已经加载过历史数据的月份。未加载月份 SHALL 可被选择；选择后客户端 SHALL 加载该 Team 对应月份的 checkin 历史并刷新月历与月份档案摘要。未加载月份 MUST NOT 被文案、accessibility 或密度条误表达为“没有训练”；只有某月份已加载且返回空 checkin 后，系统才可展示该月没有 Team 训练。

#### Scenario: 初次进入仍能看到历史月份
- **WHEN** 当前为 2026 年 7 月，Team 创建于 2026 年 6 月，且客户端首次进入 Team 历史训练页只加载了 7 月数据
- **THEN** 「选择月份」sheet SHALL 同时展示 2026 年 6 月和 2026 年 7 月
- **AND** 2026 年 6 月 SHALL 可点击选择

#### Scenario: 选择未加载月份后加载历史
- **WHEN** 用户在 Team 历史训练月份 sheet 中选择尚未加载的 2026 年 6 月
- **THEN** 客户端 SHALL 将月历切换到 2026 年 6 月
- **AND** 调用 Team checkin 历史按月接口加载该月数据
- **AND** 加载成功后月历 SHALL 显示该月真实 Team checkin 日期与选中日期列表

#### Scenario: 未加载月份不显示空训练结论
- **WHEN** 月份 sheet 中存在尚未加载的历史月份
- **THEN** 该月份行 SHALL 使用中性占位或“点按加载”语义
- **AND** accessibility SHALL NOT 朗读“没有训练”
- **AND** 密度条 MUST NOT 用空白状态表达该月已确认无训练

#### Scenario: 已加载空月份显示 Team 空状态
- **WHEN** 某月份已经加载完成且服务端返回空 checkin 列表
- **THEN** 月份 sheet 可展示该月没有训练
- **AND** 月历页面 SHALL 继续展示 Team 语境下的轻量空状态
