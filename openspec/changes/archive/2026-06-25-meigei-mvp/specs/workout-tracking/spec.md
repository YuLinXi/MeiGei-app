## ADDED Requirements

### Requirement: 内置动作库

系统 SHALL 内置 150-200 个常见健身动作，每个动作 MUST 包含名称、主要肌群、器械类型（MVP 不含动图或视频；部位高亮图已于 2026-06-10 移出 MVP 范围，留待后续单独立项）。

#### Scenario: 浏览与按部位筛选动作
- **WHEN** 用户进入动作库并选择某一肌群（如「胸」）
- **THEN** 系统展示该肌群下的所有内置动作

#### Scenario: 搜索动作
- **WHEN** 用户输入动作名称关键词
- **THEN** 系统返回名称匹配的内置动作与用户自定义动作

### Requirement: 自定义动作

系统 SHALL 允许用户创建自定义动作，至少包含名称与主要肌群，创建后可在记录训练时与内置动作一同使用。

#### Scenario: 创建自定义动作
- **WHEN** 用户填写名称与肌群并保存一个新动作
- **THEN** 该动作加入用户的动作库，后续记录训练时可被搜索和选用

### Requirement: 训练计划模板

系统 SHALL 支持创建单次训练计划模板，模板包含有序的动作列表，每个动作项含建议组数/次数/重量，且每个动作项 MUST 拥有稳定的 itemId。MVP 不支持周计划或周期化结构。

#### Scenario: 创建训练模板
- **WHEN** 用户新建一个名为「推日 A」的模板并加入若干动作
- **THEN** 系统保存该模板，模板内每个动作项均带有稳定 itemId

#### Scenario: 由模板发起训练
- **WHEN** 用户选择一个模板开始训练
- **THEN** 系统按模板动作列表预填本次训练的动作与建议参数，用户可在记录时修改

### Requirement: 训练记录

系统 SHALL 允许用户记录一次训练，针对每个动作的每一组记录重量、次数与组数，并支持完成标记与单组备注。系统 MUST NOT 自动预填上次重量。

#### Scenario: 记录一组
- **WHEN** 用户为某动作输入一组的重量与次数并标记完成
- **THEN** 系统保存该组数据并在该动作下累计组数

#### Scenario: 添加单组备注
- **WHEN** 用户对某一组填写文字备注
- **THEN** 系统将备注与该组数据一并保存

### Requirement: 组间休息计时器与 Live Activity

系统 SHALL 在用户完成一组后提供可配置的组间休息倒计时。倒计时 MUST 在 App 退到后台或设备锁屏时继续运行，并通过 Live Activity 在锁屏/灵动岛展示剩余时间与下一个动作；倒计时结束 MUST 触发提醒。Live Activity MUST 经配对的 Apple Watch 在 Smart Stack 呈现，并提供「提前结束休息」的 App Intent 按钮。MVP 不实现独立 WatchKit App。

#### Scenario: 锁屏继续计时
- **WHEN** 休息倒计时进行中用户锁屏
- **THEN** 锁屏 Live Activity 持续显示剩余秒数与下一个动作，倒计时不中断

#### Scenario: 在 Watch 上提前结束休息
- **WHEN** 用户在配对 Apple Watch 的 Smart Stack 中点击「提前结束休息」
- **THEN** 当前休息计时立即结束并提示进入下一组

### Requirement: 训练历史与 PR 识别

系统 SHALL 提供训练日历（按日期查看已完成训练）与单动作历史曲线（默认展示重量趋势）。系统 SHALL 在保存训练时自动识别个人记录（PR）并给予提示。统计数据 MUST 可由原始记录重算，系统 SHOULD 避免持久化冗余统计结果。

#### Scenario: 查看动作历史曲线
- **WHEN** 用户打开某个动作的历史
- **THEN** 系统以时间为横轴展示该动作的重量趋势曲线

#### Scenario: 自动识别 PR
- **WHEN** 用户某动作本次的重量超过其历史最大值
- **THEN** 系统标记该次为新 PR 并向用户展示庆祝提示

### Requirement: HealthKit 写入

系统 SHALL 在用户完成一次训练后，将其作为力量训练 Workout 写入 HealthKit（需用户授权）。

#### Scenario: 训练完成写入 HealthKit
- **WHEN** 用户结束并保存一次训练且已授权 HealthKit
- **THEN** 系统向 HealthKit 写入一条对应时长的力量训练 Workout 记录
