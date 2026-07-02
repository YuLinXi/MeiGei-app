## Why

当前训练记录只能把一个 `WorkoutSet` 表达为单一重量和次数，无法记录健身中常见的「递减组」：一组内连续完成多段重量/次数。用户只能拆成多条普通组，导致逻辑组数、休息触发、计划回写和 Team 展示都偏离真实训练语义。

本 change 将「递减组」作为训练记录的一等能力，并把计划模板处方一并打通，保证从记录、统计、同步、Team 打卡到下次训练预填都能完整复现。

## What Changes

- **训练记录新增递减组**：UI 文案统一为「递减组」；数据模型用中性多段组表达，不校验重量方向，允许用户记录任意连续段。
- **递减组录入交互**：动作卡底部在「加一组」左侧并列提供「递减组」快速添加；每组右侧 `⋯` 菜单支持普通组与递减组切换。
- **递减组分段编辑**：递减组内支持多个有序 segment，每段包含重量与次数；父级 `WorkoutSet` 仍承担完成、休息、排序、备注和同步聚合身份。
- **统计口径更新**：递减组计为 1 个逻辑组；训练量、总次数、PR、历史曲线、计划回写顶组按有效 segments 展开计算，统计结果仍可由原始记录重算。
- **同步与后端持久化**：`workout_set` 增加 segments jsonb；Workout 聚合树 push/pull 保留递减组分段；旧数据缺失 segments 时按普通组处理。
- **训练详情、海报与 Team 打卡**：只读流水、分享海报和 Team checkin 摘要能展示递减组分段，并按 segments 计算容量。
- **计划模板完整复现递减组**：`PlanItem` 增加可选 set prescriptions；保存为计划、严格模式预填、自适应回写、计划详情预览、Team 计划分享与 Fork 都保留递减组结构。
- **隐私脱敏延伸**：Team 分享计划时必须清除计划处方中所有重量字段，包括递减组 segments 内的重量。
- **兼容性**：旧计划无 set prescriptions 时继续使用现有 `suggestedSets/suggestedReps/suggestedWeightKg`；旧训练无 segments 时继续按普通组处理。

## Non-goals

- 不做「递增组」独立类型；不识别、不展示、不持久化递增/混合方向。
- 不校验递减组内重量必须递减；系统只记录用户输入的有序分段。
- 不支持热身递减组组合；热身组与递减组互斥。
- 不新增递减组独立同步实体或逐 segment 冲突合并；仍沿用 Workout 聚合根 last-write-wins。
- 不引入新的后端写接口；继续复用既有同步和 Team REST 流程。

## Capabilities

### New Capabilities
<!-- 无新增 capability -->

### Modified Capabilities
- `workout-tracking`: 扩展训练组模型、录入 UI、统计/PR/历史曲线、训练详情、Team 打卡、计划处方、计划预填、计划回写与 Team 计划分享规则，使递减组从记录到计划闭环可用。

## Impact

- **iOS 数据模型**：`WorkoutSetType` 新增递减组内部类型；`WorkoutSet` 新增 segments 存储；`PlanItem` 新增 set prescriptions；相关 Codable 兼容旧 payload。
- **iOS 训练 UI**：`WorkoutLoggingView`、`ExerciseBlock`、`SetRow`、数字键盘焦点序列、组级菜单、训练详情、海报、Team 摘要渲染需要更新。
- **iOS 统计/计划**：`WorkoutWeeklyStats`、`PRStats`、`WorkoutHistoryStore`、`PersonalRecord`、`AdaptivePlan`、`PlanPrefill`、计划详情预览和保存为计划需要统一走递减组展开 helper。
- **后端**：Flyway 增加 `workout_set.segments`；`WorkoutSet` 实体和同步序列化需要兼容 segments；Team 计划分享脱敏需要清理嵌套重量。
- **OpenSpec/测试/文档**：新增 workout-tracking delta spec、实现任务清单、自动化测试和手动回归用例文档。
