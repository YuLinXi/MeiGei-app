# Spec Delta

## MODIFIED Requirements

### Requirement: 动作库右侧快速定位索引

iOS 动作库 SHALL 提供独立触控的右侧索引，保留轻点直接选择、按住上下拖动连续切换及同源项目数据。每项实际触达 SHALL 至少 44×44pt；空间不足时 SHALL 允许独立滚动浏览全部项目，并区分短滑浏览与按住后的连续拖选。索引触控 MUST NOT 打开或选择相邻动作卡片。

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
- **THEN** 动作文本 SHALL 在自身区域内显示，大字时允许单列与完整换行
- **AND** 右侧索引区 SHALL 与动作点击区保持明确分隔
- **AND** 索引文字 MUST NOT 覆盖动作卡片主要信息

#### Scenario: 辅助功能可用
- **WHEN** 用户使用 VoiceOver 浏览动作库右侧索引
- **THEN** 每个索引项 SHALL 提供明确的 accessibility label
- **AND** 当前激活项 SHALL 暴露选中状态
- **AND** 用户 SHALL 能通过单项选择完成对应定位或筛选

#### Scenario: 有限高度下浏览索引
- **WHEN** 索引项目总高度超过可用空间
- **THEN** 用户 SHALL 能独立滚动索引并选择首尾项目
- **AND** 短滑浏览不改变当前筛选，按住连续拖选仍保持可用
