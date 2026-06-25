## ADDED Requirements

### Requirement: 训练动作显式排序

App SHALL 允许用户在训练计划详情页和训练进行中页，通过明确的「排序」入口进入专门排序模式调整动作顺序。完成排序后 SHALL 将对应 `orderIndex` 重写为连续 `0...n-1` 顺序，并立即持久化所属聚合根。

- 在计划详情页，重排 SHALL 更新 `WorkoutPlan.items[].orderIndex`、将 `WorkoutPlan` 标脏，并影响未来从该计划开始的训练。
- 在训练进行中页，重排 SHALL 更新 `WorkoutExercise.orderIndex`、将当前 `Workout` 标脏，并且只影响当前训练记录。
- 训练进行中的重排 MUST NOT 自动更新来源计划的 `PlanItem.orderIndex`。
- 重排 SHALL 只能从可见排序入口进入，MUST NOT 通过拖动正常动作行或正常动作卡片触发。
- 正常动作行/动作卡头 MUST NOT 常驻排序 handle。
- 排序模式 SHALL 支持取消与完成：取消不保存，完成后一次性提交排序。
- 排序模式 SHALL 使用与项目 sheet 视觉一致的自定义顶部按钮与背景，MUST NOT 依赖系统 toolbar 文本按钮。
- 排序模式 MUST 禁用系统下滑关闭，避免与上下拖动排序产生手势冲突。
- 已完成训练只读页 MUST NOT 暴露动作排序入口。
- 排序模式 SHALL 使用 VoiceOver 可操作的列表移动能力。

#### Scenario: 计划详情完成排序后保存计划顺序
- **WHEN** 用户在计划详情页打开排序面板并将第 3 个动作移到第 1 个位置后点击完成
- **THEN** 该计划的 `PlanItem.orderIndex` 被重写为连续顺序
- **AND** `WorkoutPlan` 被标脏并保存
- **AND** 下次从该计划开始训练时按新的动作顺序生成训练

#### Scenario: 计划详情取消排序不保存
- **WHEN** 用户在计划详情页打开排序面板并调整顺序后点击取消
- **THEN** 计划详情动作顺序不发生变化
- **AND** `WorkoutPlan` 不因该次取消操作被标脏

#### Scenario: 训练进行中完成排序只影响本次训练
- **WHEN** 用户在训练进行中页打开排序面板并调整动作顺序后点击完成
- **THEN** 当前 `WorkoutExercise.orderIndex` 被重写为连续顺序
- **AND** 当前 `Workout` 被标脏并保存
- **AND** 来源计划的 `PlanItem.orderIndex` 不发生变化

#### Scenario: 正常页面不被排序手势抢占
- **WHEN** 用户点击计划动作行、左滑动作行，或点击训练动作卡头
- **THEN** 原有编辑、左滑删除、展开/收起、菜单、滚动与输入交互保持可用
- **AND** 正常行/卡片内不展示常驻排序 handle

#### Scenario: 已完成训练不允许排序
- **WHEN** 用户打开已完成训练的只读详情
- **THEN** 页面不展示动作排序入口
- **AND** 用户无法调整动作顺序

#### Scenario: VoiceOver 用户可在排序模式调整顺序
- **WHEN** VoiceOver 用户打开排序面板
- **THEN** 系统提供可操作的列表移动能力
- **AND** 点击完成后执行与普通排序相同的保存逻辑

#### Scenario: 排序面板拖动时不触发下滑关闭
- **WHEN** 用户在排序面板内上下拖动 reorder control
- **THEN** 面板保持打开
- **AND** 系统下滑关闭手势不响应
- **AND** 用户只能通过取消或完成退出排序模式
