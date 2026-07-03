## ADDED Requirements

### Requirement: 动作库右侧快速定位索引

iOS 动作库 SHALL 将右侧快速定位/筛选锚点实现为独立触控索引区，支持类似 iOS 通讯录的按下、上下拖动、连续切换体验。索引区 SHALL 根据当前动作库右侧锚点数据源渲染稳定尺寸的竖向项目，并在触点进入新的索引项时执行对应定位或筛选动作。索引区 MUST 拥有独立命中区域并消费自身手势，右侧索引触控 MUST NOT 触发动作卡片点击、进入动作详情或选择动作。

#### Scenario: 拖动连续切换索引项
- **WHEN** 用户按住动作库右侧索引并上下拖动经过多个索引项
- **THEN** 系统 SHALL 随触点位置连续切换到对应索引项
- **AND** 只在索引项实际变化时触发筛选、定位或轻触反馈

#### Scenario: 索引触控不误入动作详情
- **WHEN** 用户在右侧索引命中区按下、滑动或松手
- **THEN** 系统 MUST NOT 触发索引区下方或左侧动作 row 的点击事件
- **AND** browse 模式下 MUST NOT 打开动作详情
- **AND** pick 模式下 MUST NOT 选择动作

#### Scenario: 点击索引项仍可直接定位
- **WHEN** 用户轻点右侧索引中的某个项目
- **THEN** 系统 SHALL 执行与该索引项对应的定位或筛选动作
- **AND** 列表 SHALL 使用现有动画节奏滚动到对应位置或回到顶部

#### Scenario: 索引区不遮挡动作内容
- **WHEN** 动作名称、副标或 PR 文案较长
- **THEN** 动作 row 文本 SHALL 在自身内容区内截断或缩放
- **AND** 右侧索引区 SHALL 与动作 row 点击区保持明确分隔
- **AND** UI MUST NOT 出现索引文字覆盖动作卡片主要信息的情况

#### Scenario: 辅助功能可用
- **WHEN** 用户使用 VoiceOver 浏览动作库右侧索引
- **THEN** 每个索引项 SHALL 提供明确的 accessibility label
- **AND** 当前激活项 SHALL 暴露选中状态
- **AND** 用户 SHALL 能通过单项选择完成对应定位或筛选
