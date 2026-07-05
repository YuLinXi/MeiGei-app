## Why

当前 Live Activity 只覆盖组间休息倒计时：用户不在休息阶段离开 App、锁屏或切到其它 App 时，看不到本次训练已经进行多久。训练正向计时已经在 App 内存在，但尚未进入系统级持续展示面，导致灵动岛只在休息短窗口内有价值。

这次变更将 Live Activity 的产品语义从“休息倒计时”升级为“训练会话状态”：训练进行中显示正向计时，进入休息时切换为倒计时，休息结束后恢复正向计时。

## What Changes

- 将现有休息 Live Activity 扩展为单一训练会话 Live Activity，覆盖 `workout` 与 `rest` 两个 phase。
- 训练计时开始后，系统在支持 Live Activity 的 iPhone 锁屏、Dynamic Island 与条件支持的 Watch Smart Stack 上展示训练正向计时。
- 组间休息开始时，同一个 Live Activity 切换为休息倒计时，并继续展示下一组动作、组序号、重量和次数。
- 休息自然结束或用户提前结束休息后，同一个 Live Activity 恢复训练正向计时，而不是整体消失。
- 结束训练、放弃训练或当前训练会话失效时，立即结束训练会话 Live Activity。
- 保留现有 App 内休息 FAB、休息弹窗、本地通知、前台声音与触觉反馈；Live Activity 禁用时这些路径仍需正常工作。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `workout-tracking`: 将 Live Activity 需求从“休息倒计时短生命周期”改为“训练会话长生命周期 + 休息 phase 切换”，并调整休息结束后的灵动岛行为。

## Impact

- iOS 主 App：训练会话生命周期、训练计时起点、组间休息计时器与 Live Activity 控制边界需要重新划分。
- Widget Extension：Activity attributes 与 Dynamic Island / 锁屏视图需要支持 `workout` 与 `rest` 两种 phase。
- App Intent：现有「结束休息」按钮仍只结束当前休息 phase，不应结束整场训练 Live Activity。
- OpenSpec：`workout-tracking` 中“休息 Live Activity 倒计时结束自动消失”的要求需要改写为“休息 phase 结束后恢复训练计时”。
- 构建配置：如果新增或重命名 widget 端 Swift 源文件，需要确认 `DontLiftWidgetsExtension` target 的 Sources membership。

## Non-goals

- 不新增第二个并行 Live Activity，不让训练正向计时和休息倒计时作为两个系统活动同时竞争灵动岛位置。
- 不新增远程推送更新 Live Activity；本次仍使用本地 ActivityKit 内容更新和系统自走计时文本。
- 不新增 WatchKit app，不做 Watch 专用交互；Watch Smart Stack 仍视为平台条件能力。
- 不改变训练记录、PR、HealthKit 写入、Team checkin 或云同步的数据契约。
- 不改变 App 前台内 REC header、LIVE 悬浮胶囊、休息 FAB 与休息弹窗的核心交互。
