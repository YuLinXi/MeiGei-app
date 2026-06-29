## ADDED Requirements

### Requirement: 组间休息回填持久化

系统 SHALL 将完成组后启动的预计休息时长保存到该 `WorkoutSet.plannedRestSeconds`，并在休息完成后将真实休息用时保存到同一个 `WorkoutSet.actualRestSeconds`。这两个字段 MUST 随 workout 聚合同步 push/pull。旧数据缺失字段时 MUST 兼容为 `nil`。

训练页展示某组休息用时时 SHALL 读取该组 `actualRestSeconds`；未完成组或没有真实休息记录的组 SHALL 不展示休息用时占位。

#### Scenario: 休息完成后回填真实用时
- **WHEN** 用户完成某一组并完成随后的组间休息
- **THEN** 系统将本次真实休息秒数写入该组 `actualRestSeconds`
- **AND** 训练页该组行展示格式化后的休息用时
- **AND** 该值随 workout 保存与同步

#### Scenario: 页面生命周期变化后仍保留回填
- **WHEN** 休息完成后训练页重新渲染、最小化再恢复或训练被同步到其他设备
- **THEN** 已完成组的休息用时仍从 `WorkoutSet.actualRestSeconds` 展示

### Requirement: 同一动作内下一组默认休息规则

系统 SHALL 在完成某组并启动下一段休息时，为当前组写入 `plannedRestSeconds`。同一动作内默认休息时长的来源 SHALL 按当前展示顺序判断上一组：

- 若上一组不存在，或上一组为热身组，则沿用现有动作默认休息逻辑。
- 若上一组为正式组，则使用上一组的 `plannedRestSeconds`。
- 系统 MUST NOT 使用上一组 `actualRestSeconds` 作为下一组默认休息时长。

#### Scenario: 热身组后沿用动作默认休息
- **WHEN** 用户在同一动作内完成热身组后的第一组正式组
- **THEN** 系统使用动作级默认休息时长启动休息

#### Scenario: 正式组后继承上一组预计休息
- **WHEN** 用户在同一动作内完成上一组为正式组的下一组
- **THEN** 系统使用上一正式组的 `plannedRestSeconds` 启动休息
- **AND** 即使上一组 `actualRestSeconds` 不同，也不得用真实休息时长覆盖默认值
