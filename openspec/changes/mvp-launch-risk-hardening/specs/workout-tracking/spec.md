## MODIFIED Requirements

### Requirement: 结束训练需二次确认

结束训练 SHALL 经过二次确认。进行中会话的结束按钮文案 MUST 为「结束训练」。点击「结束训练」MUST **始终**弹出确认（即使所有组已完成，不得跳过确认），确认弹窗 MUST 复用统一的二次确认 UI（`paperConfirmDialog`）并展示本次「动作数 · 已完成组数」摘要。

确认文案 SHALL 随**未完成组数**变化：当存在未勾选完成的组（`remainingSetCount > 0`）时，确认弹窗 MUST 以强警示文案提示尚有 N 组未完成；当全部组已完成时，使用常规归档提示文案。

仅确认后系统才将会话置为已完成（设置 `endedAt`）并执行个人归档副作用（HealthKit 写入、PR 检测、自适应计划回写）。Team 分享 MUST NOT 作为结束训练的无条件自动副作用；结束后系统 SHALL 读取用户已在 Team 内首次确认开启的自动分享偏好，只为这些 Team 创建或更新 checkin。若未开启任何 Team 自动分享，系统 SHALL 保持「仅自己可见」，不展示强制分享确认，不创建 Team checkin。结束训练 MUST 同时停止当前进行中的组间休息计时全套——撤销待发本地通知、收起浮动 FAB 与休息弹窗、立即结束休息 Live Activity。取消 SHALL 使会话保持进行中，不产生任何副作用，且 MUST NOT 影响正在进行的休息计时。

「丢弃进行中会话」路径 MUST 同样停止当前休息计时全套，且 MUST NOT 创建 Team checkin。

#### Scenario: 按钮文案为结束训练
- **WHEN** 用户进入进行中会话
- **THEN** 结束入口按钮文案显示「结束训练」（而非「停止训练」）

#### Scenario: 全部完成时确认结束
- **WHEN** 所有动作组均已勾选完成，用户点击「结束训练」
- **THEN** 弹出常规确认（「结束训练?/将归档本次训练并计算 PR」+「动作数·已完成组数」摘要）；确认后会话置为已完成并执行 HealthKit 写入、PR 检测与个人归档副作用
- **AND** 若用户未开启任何 Team 自动分享，系统保持仅自己可见，不创建 Team checkin

#### Scenario: 有未完成组时强确认
- **WHEN** 仍有 N(>0) 组未勾选完成，用户点击「结束训练」
- **THEN** 确认弹窗以强警示文案提示「还有 N 组未完成」并征询是否仍要结束；确认后才归档

#### Scenario: 取消结束
- **WHEN** 用户点击「结束训练」但在确认弹窗中取消
- **THEN** 会话保持进行中，不设置 `endedAt`，不触发任何归档副作用，进行中的休息计时不受影响

#### Scenario: 结束训练即停休息计时
- **WHEN** 休息计时进行中，用户确认结束训练（或丢弃该进行中会话）
- **THEN** 浮动 FAB 与休息弹窗立即收起、待发休息提醒通知被撤销、休息 Live Activity 立即结束，不再残留倒计时

#### Scenario: 自动分享到已授权 Team
- **WHEN** 训练已归档，且用户已在 Team A 中开启自动分享
- **THEN** 系统为 Team A 创建或更新该训练 checkin
- **AND** 未开启自动分享的 Team 不出现该训练

#### Scenario: 丢弃会话不打卡
- **WHEN** 用户丢弃进行中会话
- **THEN** 系统删除该会话并停止休息计时
- **AND** 不展示强制 Team 分享 sheet，不创建 Team checkin

## ADDED Requirements

### Requirement: Live Activity Watch Smart Stack 条件呈现与降级

休息 Live Activity SHALL 在 iPhone 锁屏与支持 Dynamic Island 的设备上按既有规则呈现。配对 Apple Watch Smart Stack 呈现 SHALL 被视为平台条件能力：仅当系统版本、设备能力、连接状态与 ActivityKit/WidgetKit 预算支持时呈现。系统 MUST NOT 将 Apple Watch Smart Stack 不出现视为训练或休息提醒失败。Watch 不支持或未及时同步时，系统 SHALL 继续依靠 iPhone 锁屏 Live Activity、本地通知、前台声音与触觉反馈完成提醒。

#### Scenario: 支持平台显示 Watch Smart Stack
- **WHEN** 用户使用支持 iPhone Live Activity 自动转呈的 iOS/watchOS 组合，并且 Apple Watch 与 iPhone 连接正常
- **THEN** 休息 Live Activity 可在 Apple Watch Smart Stack 中呈现

#### Scenario: 不支持 Watch 时降级
- **WHEN** 用户没有 Apple Watch、watchOS 版本不支持、或连接状态导致 Smart Stack 未呈现
- **THEN** iPhone 锁屏 Live Activity 与本地通知仍按休息倒计时规则工作
- **AND** 验收不得因 Watch Smart Stack 缺席而判定休息计时失败

#### Scenario: Watch 更新延迟不影响倒计时真相
- **WHEN** Apple Watch 因连接或系统预算未及时显示最新 Live Activity 状态
- **THEN** App 内休息计时与 iPhone 端 Live Activity 仍以同一墙钟 `endDate` 为准

### Requirement: 训练计划模式属于当前 1.0 范围

当前 1.0 训练计划能力 SHALL 包含严格 / 自适应模式、开始训练历史优先预填、未完成预填组清理、训练完成后自适应回写与回写撤销。任何旧 proposal 中“不做自适应/自动重量预填”的表述 MUST 被视为已由后续 workout-tracking 规格覆盖，不得作为验收依据。

#### Scenario: 验收以主规格为准
- **WHEN** 验收人员检查训练计划行为
- **THEN** 以当前 `workout-tracking` 主规格中的严格 / 自适应、预填与回写要求为准
- **AND** 不因 `meigei-mvp` 初稿 Non-goal 中的旧表述判定这些能力越界
