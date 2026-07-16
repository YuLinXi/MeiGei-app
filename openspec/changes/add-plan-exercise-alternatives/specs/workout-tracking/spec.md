## ADDED Requirements

### Requirement: 计划普通动作支持备选动作

系统 SHALL 允许用户为普通单动作 `PlanItem` 添加和移除有序备选动作。备选动作 MUST 保存可离线展示和开始训练所需的动作引用与名称快照，MUST 与默认动作及同项其他备选按 canonical `historyKey` 去重。递减组和超级组 MUST NOT 在本 change 中提供备选入口。

备选动作 MUST 作为同一计划动作位的候选，每次训练只执行默认动作或其中一个备选；备选 MUST NOT 增加计划动作数、总组数或预计训练量。计划详情 SHALL 展示该项存在的备选动作。

#### Scenario: 添加普通动作备选
- **WHEN** 用户在普通计划动作「杠铃卧推」中添加「哑铃卧推」
- **THEN** 计划项保存该备选动作引用与名称快照
- **AND** 计划动作数和总组数保持不变

#### Scenario: 拒绝重复候选
- **WHEN** 用户选择与默认动作或已有备选 canonical `historyKey` 相同的动作
- **THEN** 系统 MUST NOT 重复添加该动作

#### Scenario: 非普通动作不提供备选
- **WHEN** 用户编辑递减组或超级组
- **THEN** 页面不提供添加备选动作入口

### Requirement: 训练中临时更换为计划备选动作

从含备选的计划或 Team 分享版本创建训练时，系统 SHALL 把默认动作、全部备选、来源计划模式和默认动作初始逐组落值作为本次 `WorkoutUnit` 快照保存。训练动作 SHALL 继续携带父 `PlanItem.itemId` 作为 `planItemId`。

训练中的普通动作仅在不存在任何 `completed == true` 的组时 SHALL 允许更换，热身组也计入该限制。更换 SHALL 只影响本次训练，不修改计划默认动作；系统 SHALL 在确认后保留 exercise/unit/planItem 标识与动作顺序，清空动作备注，并重建全部未完成组。

#### Scenario: 未完成任何组时更换备选
- **WHEN** 用户从计划开始训练，某普通动作尚无完成组，并选择该项的有效备选
- **THEN** 系统确认后把本次 `WorkoutExercise` 改为该备选动作
- **AND** `WorkoutExercise.localId`、`planItemId`、训练单元顺序和动作级休息设置保持不变
- **AND** 计划模板默认动作保持不变

#### Scenario: 完成热身组后禁止更换
- **WHEN** 该动作已有一个完成的热身组
- **THEN** 系统 MUST 禁止更换动作
- **AND** 已完成训练数据保持原动作身份

#### Scenario: 重启后仍可切换
- **WHEN** 含备选的进行中训练被同步、App 退出并重新打开
- **THEN** 系统从训练单元快照恢复默认动作与全部备选
- **AND** 在仍无完成组时继续允许更换

### Requirement: 备选动作处方与历史隔离

严格模式选择备选时，系统 SHALL 保留默认动作的组数、次数、热身与普通组结构，并 MUST 清空所有重量；切回默认动作 SHALL 恢复本次训练创建时保存的默认落值。严格模式 MUST NOT 从历史为备选适配重量。

自适应模式 SHALL 以 `planItemId + 实际动作 historyKey` 查找该备选在同一动作位下最近一次完成实绩；命中时按该历史逐组落值，无历史时 SHALL 沿用默认动作结构并清空重量。默认动作和不同备选之间 MUST NOT 互相借用历史重量。

计划详情的下次处方 SHALL 继续表示默认动作路径；用户在训练中主动更换后，本次处方 MAY 与详情预览不同。

#### Scenario: 严格模式备选清空重量
- **WHEN** 严格计划默认动作预设为 `80kg × 8`，用户在训练中选择备选动作
- **THEN** 新动作保留组数、次数和热身结构
- **AND** 所有组重量为空

#### Scenario: 自适应备选使用自身历史
- **WHEN** 同一计划项的默认杠铃卧推最近为 `80kg × 8`，备选哑铃卧推最近为 `30kg × 10`
- **THEN** 用户选择哑铃卧推时预填 `30kg × 10`
- **AND** 下次使用默认杠铃卧推时仍以杠铃卧推历史为准

#### Scenario: 自适应备选无历史
- **WHEN** 用户首次选择某个备选动作
- **THEN** 系统沿用默认动作的组数、次数和热身结构
- **AND** 不复制默认动作重量或其他动作位的同动作重量

### Requirement: 备选实绩不覆盖默认动作处方

自适应计划完成训练时，若某 `WorkoutExercise.planItemId` 命中父计划项，但实际动作属于该项备选且不同于默认动作，系统 SHALL 把父项视为本次已触达，但 MUST NOT 更新默认动作引用、`suggested*` 或 `setPrescriptions`，MUST NOT 把备选追加为新的 `PlanItem`，并 MUST NOT 在回写回执中把父项显示为跳过保留。

备选动作的实际训练记录 SHALL 正常参与该实际动作的 PR、历史与 Team checkin。

#### Scenario: 备选完成不污染默认处方
- **WHEN** 自适应计划默认杠铃卧推为 `80kg × 8`，本次改练备选哑铃卧推并完成 `30kg × 10`
- **THEN** 实际训练历史记录哑铃卧推 `30kg × 10`
- **AND** 默认杠铃卧推处方保持 `80kg × 8`
- **AND** 计划不新增第二个哑铃卧推计划项

#### Scenario: 备选动作计入动作位完成
- **WHEN** 用户完成某计划项的备选动作
- **THEN** 该父计划项 MUST NOT 被标记为本次跳过或未训练
