## ADDED Requirements

### Requirement: 本地训练 kcal 估算

iOS SHALL 基于已完成训练的时长、用户本地设置的估算体重、粗粒度强度系数和训练密度折扣计算 kcal 估算值。估算结果 MUST 由本地原始训练记录即时派生或在本地可重建快照中派生，MUST NOT 作为 `Workout` 同步真相字段上传。详情页展示文案 MUST 使用「约」表达估算性质，分享海报 MAY 使用 `≈` 符号表达同一估算性质。

#### Scenario: 常规力量训练估算
- **WHEN** 用户已设置估算体重且查看一条有有效时长的已完成训练
- **THEN** iOS 按 `MET × 3.5 × bodyWeightKg / 200 × durationMinutes × densityFactor` 计算整数 kcal
- **AND** 展示文案包含「约」与 `kcal`

#### Scenario: 无估算体重
- **WHEN** 用户未设置估算体重
- **THEN** iOS 不展示该训练的 kcal 估算结果
- **AND** 不写入任何训练同步字段

#### Scenario: 训练无有效时长
- **WHEN** 训练缺少 `endedAt` 或时长不大于 0
- **THEN** iOS 不展示 kcal 估算结果

### Requirement: 训练详情页展示 kcal

已完成训练详情页 SHALL 在现有「时长 / 总组数 / 训练量」三联数下方展示单次训练 kcal 估算行。该展示 MUST 不替代三联数中的任何核心训练指标，并 MUST 在用户关闭消耗估算或缺少估算体重时隐藏。

#### Scenario: 详情页显示估算行
- **WHEN** 用户打开已完成训练详情页且 kcal 估算可用
- **THEN** 三联数仍显示「时长 / 总组数 / 训练量」
- **AND** 三联数下方显示 `约 xxx kcal · <强度>` 辅助行

#### Scenario: 详情页隐藏估算行
- **WHEN** 用户关闭消耗估算或未设置估算体重
- **THEN** 已完成训练详情页不显示 kcal 估算行

### Requirement: 分享海报重点展示 kcal

训练分享海报 SHALL 在 kcal 估算可用时重点展示 `≈xxx kcal`，并保持其它训练指标可读。用户关闭消耗估算或未设置估算体重时，海报 MUST 不展示 kcal。

#### Scenario: 海报展示 kcal
- **WHEN** 用户预览一张 kcal 估算可用的训练分享海报
- **THEN** 海报指标区展示 `≈xxx kcal`
- **AND** kcal 的视觉层级不低于时长、训练量、动作数等摘要指标
- **AND** `≈` 的字号小于数字且与数字紧密衔接

#### Scenario: 海报不展示 kcal
- **WHEN** 用户关闭消耗估算或未设置估算体重
- **THEN** 训练分享海报不展示 kcal 指标

### Requirement: 训练偏好配置 kcal 估算

「我的 > 训练偏好」SHALL 提供本地估算配置：用户可设置估算体重，并可开启或关闭消耗估算展示。该配置 MUST 保存在本机，不上传到后端，不纳入账号画像或同步域。

#### Scenario: 设置估算体重
- **WHEN** 用户在训练偏好中设置估算体重
- **THEN** 后续训练详情页和分享海报可基于该体重展示 kcal 估算

#### Scenario: 关闭消耗估算
- **WHEN** 用户关闭消耗估算展示
- **THEN** 训练详情页和分享海报均不展示 kcal 估算

### Requirement: kcal 不进入实时训练、Team 与 HealthKit 能量

kcal 估算 MUST NOT 在训练进行中页面实时展示，MUST NOT 默认出现在 Team 动态或 Team 打卡摘要中，MUST NOT 写入 HealthKit active energy。现有 HealthKit workout 写入能力 SHALL 保持可用。

#### Scenario: 训练进行中不展示 kcal
- **WHEN** 用户正在记录训练
- **THEN** 训练进行中页面不显示实时 kcal 估算

#### Scenario: Team 打卡不包含 kcal
- **WHEN** 用户完成训练并分享到 Team
- **THEN** Team 打卡摘要不包含 kcal 估算字段或展示文案

#### Scenario: HealthKit 不写 active energy
- **WHEN** 用户结束训练且 HealthKit 写入成功
- **THEN** iOS 仍只写入 strength training workout
- **AND** 不把本地估算 kcal 写入 HealthKit active energy
