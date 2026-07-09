## Why

当前 iOS 小组件 target 只承载训练 Live Activity，用户只有在训练进行中或休息阶段才能看到系统级训练状态；非训练中无法从主屏快速扫一眼今日、本周训练进度。第一版常驻小组件补上「训练摘要 + 回到训练」入口，同时避免把训练写入、Team 网络数据或 SwiftData 全量读取搬进 extension。

## What Changes

- 新增训练摘要小组件，支持 small 与 medium 两种主屏尺寸。
- 小组件展示今日训练状态、本周训练次数、本周训练量、组数、次数、7 天节奏与最近训练摘要。
- 若存在进行中的训练，小组件优先展示「训练进行中 / 继续训练」状态。
- 主 App 将训练首页派生摘要写入 App Group JSON 快照；Widget extension 只读快照生成 timeline。
- 小组件点击只打开 App 或深链到训练页，不在 Widget extension 内完成组、结束训练、创建训练或访问后端。

## Non-goals

- 不新增 Team 小组件，不读取 Team feed、checkin、reaction 或服务端权威数据。
- 不新增可配置计划小组件，不暴露计划 `AppEntity` 或计划选择 intent。
- 不新增 Control Widget、Shortcuts 或 Siri 动作。
- 不让 Widget extension 直接读取 SwiftData 聚合树、Keychain/JWT 或调用后端 API。
- 不改变现有训练记录、同步、Live Activity、本地通知、HealthKit 或 Team 分享行为。

## Capabilities

### New Capabilities

- `ios-workout-summary-widget`: iOS 常驻训练摘要小组件的数据快照、展示、刷新与深链行为。

### Modified Capabilities

- 无。

## Impact

- iOS 主 App：新增 App Group 快照写入逻辑，在历史摘要刷新、训练状态变化和启动时更新 Widget 快照。
- Widget Extension：在现有 `DontLiftWidgetsExtension` 中新增常驻训练摘要 Widget，并继续保留训练会话 Live Activity。
- Xcode 工程：新增 widget 端 Swift 源文件需加入 `DontLiftWidgetsExtension` Sources；主 App 与 extension 需配置同一个 App Group entitlement。
- 验证：需通过 iOS simulator `xcodebuild` 构建；真机阶段再验证主屏 widget 刷新与深链。
