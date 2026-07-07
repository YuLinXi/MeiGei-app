## Why

训练详情和分享海报目前只展示时长、组数、训练量、PR 等硬训练指标，缺少用户复盘时常见的能量消耗参考。力量训练 kcal 天然误差较大，但以“约 kcal”的轻量本地估算呈现，可以满足个人复盘和分享表达，同时不改变训练记录的核心真相源。

## What Changes

- 新增训练 kcal 估算能力：基于训练时长、本地估算体重、粗粒度强度系数与训练密度折扣计算。
- 已完成训练详情页展示单次训练 `约 xxx kcal`，作为弱辅助指标，不替代三联数。
- 分享海报重点展示 `≈xxx kcal` 估算，使海报除训练量、动作数、时长外多一个用户易感知的消耗信息。
- 「我的 > 训练偏好」新增本地估算配置，用于设置估算体重与控制是否显示消耗估算。
- kcal 估算不写入后端、不参与同步冲突、不写入 HealthKit active energy、不默认出现在 Team 动态。

## Non-goals

- 不做动作级 MET 表，不按每个动作单独估算消耗。
- 不读取 HealthKit 体重或能量数据。
- 不把估算 kcal 持久化到 `Workout` 同步实体或后端字段。
- 不在训练进行中页面实时滚动显示 kcal。
- 不在训练首页 hero、本周训练列表、计划页、动作详情页展示 kcal。
- 不把 kcal 默认写入 Team checkin 摘要。

## Capabilities

### New Capabilities

- `workout-calorie-estimates`: 定义训练 kcal 本地估算、设置入口、训练详情展示、分享海报展示与非展示范围。

### Modified Capabilities

- 无。现有训练详情、分享海报、训练偏好页面通过新增能力扩展行为，不改变既有核心训练记录与分享契约。

## Impact

- iOS：新增 kcal 估算纯函数/模型，扩展训练详情页、分享海报数据和画布、我的页训练偏好。
- 测试：新增估算算法与展示数据的自动化测试，覆盖默认/关闭/缺少体重等边界。
- 后端/API/数据库：无变更。
- HealthKit：仍只写入 strength training workout，不写 active energy。
