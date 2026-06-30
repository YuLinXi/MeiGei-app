## ADDED Requirements

### Requirement: 训练会话 Live Activity 正向计时

训练计时启动后，系统 SHALL 创建或更新单一训练会话 Live Activity，并在 `workout` phase 展示本次训练的正向计时。正向计时 MUST 以 `Workout.timerStartedAt` 为起点；若训练会话已创建但 `timerStartedAt == nil`，系统 MUST NOT 启动训练会话 Live Activity。训练正向计时 MUST 使用系统可自走的计时展示方式，MUST NOT 为秒级刷新频繁更新 Activity state。

系统 MUST NOT 同时创建“训练正向计时 Live Activity”和“休息倒计时 Live Activity”两个并行活动；训练与休息 MUST 由同一个训练会话 Live Activity 的 phase 表达。

#### Scenario: 完成第一组后显示训练计时
- **WHEN** 用户完成第一组并触发 `timerStartedAt` 落定
- **THEN** 系统创建或更新训练会话 Live Activity 为 `workout` phase
- **AND** Dynamic Island / 锁屏卡片显示从 `timerStartedAt` 起算的训练正向计时

#### Scenario: 手动开始训练后显示训练计时
- **WHEN** 用户在训练进行中页点击开始训练按钮并落定 `timerStartedAt`
- **THEN** 系统创建或更新训练会话 Live Activity 为 `workout` phase
- **AND** 计时基准与 App 内 REC header 使用同一个 `timerStartedAt`

#### Scenario: 仅创建会话但未开始计时
- **WHEN** 用户只创建训练会话但尚未完成任何组，也未手动开始训练
- **THEN** 系统不启动训练会话 Live Activity

#### Scenario: Live Activity 不可用时降级
- **WHEN** 用户关闭 Live Activity 权限、设备不支持 Live Activity 或系统预算暂不允许展示
- **THEN** App 内 REC header、LIVE 悬浮胶囊、休息 FAB、休息弹窗、本地通知、声音和触觉仍按现有规则工作

### Requirement: 训练会话 Live Activity 休息 phase 切换

组间休息开始时，系统 SHALL 将同一个训练会话 Live Activity 更新为 `rest` phase，并使用本次休息的墙钟 `restEndDate` 展示倒计时。`rest` phase MUST 展示下一组动作、组序号、重量和次数（若这些值存在）。休息自然结束或用户提前结束休息后，系统 SHALL 将同一个 Live Activity 更新回 `workout` phase，恢复展示训练正向计时，MUST NOT 因单次休息结束而结束整场训练会话 Live Activity。

训练会话 Live Activity 的 `rest` phase 倒计时 MUST 与 App 内休息 FAB、休息弹窗和本地通知共享同一墙钟 `restEndDate`。调整休息时长时，系统 SHALL 更新 `restEndDate`，并保持 App 内与 Live Activity 展示一致。

#### Scenario: 完成一组后进入休息 phase
- **WHEN** 用户完成一组并启动 90 秒组间休息
- **THEN** 当前训练会话 Live Activity 更新为 `rest` phase
- **AND** Dynamic Island / 锁屏卡片显示与 App 内 FAB 相同 `restEndDate` 的休息倒计时
- **AND** 展示下一组动作、组序号、重量和次数（若存在）

#### Scenario: 休息调时同步到 Live Activity
- **WHEN** 用户在休息弹窗中点击 `+10s` 或 `-10s`
- **THEN** App 内 FAB、休息弹窗、本地通知和训练会话 Live Activity 的倒计时均使用调整后的同一个 `restEndDate`

#### Scenario: 休息自然结束后恢复训练计时
- **WHEN** 组间休息自然倒计时到达 `restEndDate`
- **THEN** App 内休息 FAB 与休息弹窗按现有规则收起
- **AND** 训练会话 Live Activity 更新回 `workout` phase
- **AND** Dynamic Island / 锁屏卡片继续显示本次训练正向计时

#### Scenario: 提前结束休息后恢复训练计时
- **WHEN** 用户在 App 内或 Live Activity 上提前结束当前休息
- **THEN** 当前休息结束并产生既有休息完成回写
- **AND** 训练会话 Live Activity 更新回 `workout` phase
- **AND** 该操作 MUST NOT 结束或归档整场训练

### Requirement: 训练会话 Live Activity 结束与失效收束

结束训练、放弃训练或系统检测到不存在有效进行中训练会话时，系统 SHALL 立即结束训练会话 Live Activity，避免 Dynamic Island、锁屏卡片或 Watch Smart Stack 残留过期训练状态。结束训练时若正处于 `rest` phase，系统 SHALL 同时撤销休息本地通知、收起 App 内休息 FAB/弹窗，并立即结束训练会话 Live Activity。

#### Scenario: 非休息状态结束训练
- **WHEN** 用户在 `workout` phase 下确认结束训练
- **THEN** 系统归档训练并立即结束训练会话 Live Activity

#### Scenario: 休息状态结束训练
- **WHEN** 用户在 `rest` phase 下确认结束训练
- **THEN** 系统撤销待发休息通知、收起 App 内休息 UI，并立即结束训练会话 Live Activity

#### Scenario: 放弃训练
- **WHEN** 用户放弃当前进行中训练
- **THEN** 系统删除或软删该训练会话，并立即结束训练会话 Live Activity

#### Scenario: 回前台发现无有效会话
- **WHEN** App 回到前台且本地不存在有效进行中训练会话
- **THEN** 系统结束任何仍处于 active 状态的训练会话 Live Activity

## MODIFIED Requirements

### Requirement: Live Activity Watch Smart Stack 条件呈现与降级

训练会话 Live Activity SHALL 在 iPhone 锁屏与支持 Dynamic Island 的设备上按既有规则呈现。配对 Apple Watch Smart Stack 呈现 SHALL 被视为平台条件能力：仅当系统版本、设备能力、连接状态与 ActivityKit/WidgetKit 预算支持时呈现。系统 MUST NOT 将 Apple Watch Smart Stack 不出现视为训练、休息倒计时或提醒失败。Watch 不支持或未及时同步时，系统 SHALL 继续依靠 iPhone 锁屏 Live Activity、App 内 REC/FAB/弹窗、本地通知、前台声音与触觉反馈完成展示与提醒。

#### Scenario: 支持平台显示 Watch Smart Stack
- **WHEN** 用户使用支持 iPhone Live Activity 自动转呈的 iOS/watchOS 组合，并且 Apple Watch 与 iPhone 连接正常
- **THEN** 训练会话 Live Activity 可在 Apple Watch Smart Stack 中呈现
- **AND** `workout` phase 显示训练正向计时，`rest` phase 显示休息倒计时

#### Scenario: 不支持 Watch 时降级
- **WHEN** 用户没有 Apple Watch、watchOS 版本不支持、或连接状态导致 Smart Stack 未呈现
- **THEN** iPhone 锁屏 Live Activity、App 内 REC/FAB/弹窗与本地通知仍按训练会话和休息倒计时规则工作
- **AND** 验收不得因 Watch Smart Stack 缺席而判定训练计时或休息提醒失败

#### Scenario: Watch 更新延迟不影响倒计时真相
- **WHEN** Apple Watch 因连接或系统预算未及时显示最新 Live Activity 状态
- **THEN** App 内休息计时与 iPhone 端 Live Activity 仍以同一墙钟 `restEndDate` 为准
- **AND** App 内训练正向计时与 iPhone 端 Live Activity 仍以同一 `timerStartedAt` 为准

## REMOVED Requirements

### Requirement: 休息 Live Activity 倒计时结束自动消失

**Reason**: 休息 Live Activity 被训练会话 Live Activity 替代；休息结束不再代表系统级活动结束，而是同一训练会话从 `rest` phase 回到 `workout` phase。

**Migration**: 实现时将休息倒计时结束逻辑从“结束 Activity”迁移为“退出 `rest` phase 并恢复训练正向计时”。只有结束训练、放弃训练或不存在有效进行中训练会话时，才立即结束训练会话 Live Activity。
