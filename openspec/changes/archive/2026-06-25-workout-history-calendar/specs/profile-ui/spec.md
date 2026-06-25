## MODIFIED Requirements

### Requirement: 训练统计卡

ProfileHeader 下方 SHALL 渲染单个全宽统计卡：「总训练」。该统计卡背景为 `Theme.Color.surface`，外层 1px `Theme.Color.border`，数字使用 `Theme.Color.fg`。App MUST NOT 展示或计算「最长连续」指标。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 统计卡显示「总训练 0」，不报错不空白。

#### Scenario: 不再展示最长连续
- **WHEN** 用户进入「我的」页
- **THEN** 顶部统计仅含「总训练」
- **AND** 不渲染「最长连续」格
