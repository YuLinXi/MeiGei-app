## MODIFIED Requirements

### Requirement: 组间休息回填持久化

系统 SHALL 将完成组后启动的预计休息时长保存到该 `WorkoutSet.plannedRestSeconds`，并在休息完成后将真实休息用时保存到同一个 `WorkoutSet.actualRestSeconds`。这两个字段 MUST 随 workout 聚合同步 push/pull。旧数据缺失字段时 MUST 兼容为 `nil`。

训练页展示某组休息用时时 SHALL 读取该组 `actualRestSeconds`；未完成组或没有真实休息记录的组 SHALL 不展示休息用时占位。若用户在最后一段休息仍进行时确认结束训练，系统 MUST 将该段休息当前设置的目标总时长写入对应组的 `actualRestSeconds`，不得留下空值或写入尚未结束时的部分流逝秒数。

#### Scenario: 休息完成后回填真实用时
- **WHEN** 用户完成某一组并完成随后的组间休息
- **THEN** 系统将本次真实休息秒数写入该组 `actualRestSeconds`
- **AND** 训练页该组行展示格式化后的休息用时
- **AND** 该值随 workout 保存与同步

#### Scenario: 页面生命周期变化后仍保留回填
- **WHEN** 休息完成后训练页重新渲染、最小化再恢复或训练被同步到其他设备
- **THEN** 已完成组的休息用时仍从 `WorkoutSet.actualRestSeconds` 展示

#### Scenario: 结束训练时最后一段休息尚未完成
- **GIVEN** 最后一组已完成并启动目标为 120 秒的休息
- **WHEN** 休息倒计时尚未结束，用户确认结束训练
- **THEN** 对应组的 `actualRestSeconds` 写入 120 秒
- **AND** 系统停止休息计时、撤销通知并结束训练会话 Live Activity
