## ADDED Requirements

### Requirement: Team checkin 超级组详情展示

iOS Team checkin 详情 SHALL 保留并展示训练快照中的超级组结构。若 checkin summary 包含超级组训练单元，详情页 MUST 将该超级组作为与单动作平级的训练单元展示，展示成员动作、轮数以及每轮两个成员动作的重量/次数。系统 MUST NOT 将超级组误展平成两个无关联单动作。

#### Scenario: Team 详情展示超级组
- **WHEN** Team checkin summary 包含超级组「杠铃片夹胸 + 下斜杠铃卧推」共 4 轮
- **THEN** Team checkin 详情 SHALL 展示一个超级组训练单元
- **AND** 显示两个成员动作和 4 轮记录
- **AND** 不把两个成员动作展示为两个独立无关联动作卡

#### Scenario: 旧 checkin 兼容
- **WHEN** Team checkin summary 不包含训练单元结构而只包含旧动作列表
- **THEN** Team checkin 详情 SHALL 按旧单动作列表展示
- **AND** 页面不得因缺少超级组字段而报错或空白
