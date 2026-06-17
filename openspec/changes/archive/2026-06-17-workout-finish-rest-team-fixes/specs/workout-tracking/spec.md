## MODIFIED Requirements

### Requirement: 结束训练需二次确认

结束训练 SHALL 经过二次确认。进行中会话的结束按钮文案 MUST 为「结束训练」。点击「结束训练」MUST **始终**弹出确认（即使所有组已完成，不得跳过确认），确认弹窗 MUST 复用统一的二次确认 UI（`paperConfirmDialog`）并展示本次「动作数 · 已完成组数」摘要。

确认文案 SHALL 随**未完成组数**变化：当存在未勾选完成的组（`remainingSetCount > 0`）时，确认弹窗 MUST 以强警示文案提示尚有 N 组未完成；当全部组已完成时，使用常规归档提示文案。

仅确认后系统才将会话置为已完成（设置 `endedAt`）并执行归档副作用（HealthKit 写入、PR 检测、Team 打卡）。结束训练 MUST 同时停止当前进行中的组间休息计时全套——撤销待发本地通知、收起浮动 FAB 与休息弹窗、立即结束休息 Live Activity。取消 SHALL 使会话保持进行中，不产生任何副作用，且 MUST NOT 影响正在进行的休息计时。

「丢弃进行中会话」路径 MUST 同样停止当前休息计时全套。

#### Scenario: 按钮文案为结束训练
- **WHEN** 用户进入进行中会话
- **THEN** 结束入口按钮文案显示「结束训练」（而非「停止训练」）

#### Scenario: 全部完成时确认结束
- **WHEN** 所有动作组均已勾选完成，用户点击「结束训练」
- **THEN** 弹出常规确认（「结束训练?/将归档本次训练并计算 PR」+「动作数·已完成组数」摘要）；确认后会话置为已完成并执行 HealthKit 写入、PR 检测与 Team 打卡

#### Scenario: 有未完成组时强确认
- **WHEN** 仍有 N(>0) 组未勾选完成，用户点击「结束训练」
- **THEN** 确认弹窗以强警示文案提示「还有 N 组未完成」并征询是否仍要结束；确认后才归档

#### Scenario: 取消结束
- **WHEN** 用户点击「结束训练」但在确认弹窗中取消
- **THEN** 会话保持进行中，不设置 `endedAt`，不触发任何归档副作用，进行中的休息计时不受影响

#### Scenario: 结束训练即停休息计时
- **WHEN** 休息计时进行中，用户确认结束训练（或丢弃该进行中会话）
- **THEN** 浮动 FAB 与休息弹窗立即收起、待发休息提醒通知被撤销、休息 Live Activity 立即结束，不再残留倒计时

## ADDED Requirements

### Requirement: 休息结束提醒（前台声音 + 震动）

组间休息计时归零时系统 SHALL 给出明确的多通道提醒。后台/锁屏 MUST 经本地通知（含声音）提醒（既有行为）；App 在前台时，系统 MUST 在到点瞬间播放一声短促提醒音效并维持触觉反馈（按 `hapticsEnabled` 开关）。

提醒音效 SHALL 来自随包的短音效资源文件，经 `AVAudioSession` `.playback` 类别播放，因而 MUST 无视静音键（健身场景刚需）；播放 MUST 采用 `.duckOthers + .mixWithOthers`，仅瞬时压低用户后台音乐而非掐断，并在播完恢复。系统 SHALL 提供 `soundEnabled` 开关（默认开）控制该音效。前台到点的音效与本地通知声 MUST NOT 重复响两声。

#### Scenario: 前台到点出声
- **WHEN** App 在前台，休息计时归零，`soundEnabled` 为开
- **THEN** 即使手机处于静音/震动档，也播放一声短促提醒音 + 触觉反馈

#### Scenario: 不打断用户音乐
- **WHEN** 用户边训练边播放背景音乐，休息到点出声
- **THEN** 背景音乐被瞬时压低（duck）后于音效播完恢复，不被掐断

#### Scenario: 关闭声音开关
- **WHEN** `soundEnabled` 为关，休息计时归零
- **THEN** 前台不播放音效（触觉与本地通知行为不受该开关影响）

### Requirement: 休息 Live Activity 倒计时结束自动消失

休息计时的 Live Activity（灵动岛）MUST 在倒计时到达 `endDate` 后自动消失，MUST NOT 在归零后长期停留。系统 SHALL 在启动该 Live Activity 时即预约其在 `endDate`（含短暂宽限）后自动 dismiss（`dismissalPolicy: .after(...)`），从而无需 App 在后台被唤醒即可消失。当休息被提前结束、自然结束（前台）或随结束训练而终止时，系统 SHALL 以 `.immediate` 立即结束该 Live Activity，覆盖预约。

#### Scenario: 后台自然归零后自动消失
- **WHEN** App 在后台/锁屏，休息计时自然倒计时至 `endDate`
- **THEN** 灵动岛在 `endDate`（含宽限）后自动消失，无需用户回到 App 或手动操作

#### Scenario: 提前结束立即消失
- **WHEN** 用户在灵动岛点「结束」或在 App 内提前结束休息
- **THEN** 灵动岛立即消失（`.immediate`）

#### Scenario: 结束训练时一并消失
- **WHEN** 休息计时进行中，用户结束训练
- **THEN** 休息 Live Activity 立即结束消失
