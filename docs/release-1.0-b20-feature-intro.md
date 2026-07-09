# v1.0-b20 训练摘要小组件和设置页优化功能介绍

> 适用版本：`1.0 (build 20)`
> 生成时间：2026-07-09 18:10 CST。
> 后端状态：本次无后端运行时代码和数据库迁移变更，无需重新部署；生产 health 已确认为 `UP`，Flyway 最新仍为 `V18 workout set is warmup success=true`。
> iOS 状态：已完成本地 build/test 验证；TestFlight `1.0 (20)` 尚未上传，仍待用户用 Xcode Archive 上传。

## 一句话摘要

本次 build 20 新增训练摘要主屏小组件，并把设置页里的休息时长和消耗估算配置改成更适合真机输入的 sheet 流程。

## 面向测试用户的更新说明

- 新增训练摘要小组件，可以在主屏快速查看今天是否训练、本周训练次数、训练量、组数、次数和一周节奏。
- 中尺寸小组件会展示最近训练摘要；有进行中训练时，小组件会优先显示“训练进行中”和当前训练名。
- 小组件左上角使用 App 图标和中文名称“别练了”，点击后会打开 App 的训练区域；进行中训练会尽量回到当前训练会话。
- 设置页的默认休息时长改为点击后在 sheet 中输入分钟和秒，避免小按钮步进在真机上难点。
- 消耗估算在开启前会要求先填写估算体重；体重输入支持 30–250 kg 范围校验。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 20`，App、widget、测试 target 已同步。
- 新增 `WorkoutSummaryWidget`，支持 small 与 medium 两种 Widget family。
- 主 App 通过 App Group `group.com.yulinxi.app.DontLift` 写入训练摘要 JSON 快照，widget extension 只读快照，不访问 SwiftData、Keychain 或后端。
- 新增 `dontlift://workout` 与 `dontlift://workout/live` 深链处理，用于小组件打开训练区域和进行中训练。
- `ProfileView` 将法律页、默认休息时长、估算体重统一到 `ProfileSheet` sheet 承载，减少行内复杂控件。
- 新增 OpenSpec workflow 工具文件，补齐 new/continue/ff/onboard/sync/verify/bulk-archive 等命令和 Codex/Claude skill。
- 本次无后端 API、同步协议、数据库 migration 或生产部署变更。

## 兼容性说明

- build 20 的用户可使用新的训练摘要小组件；未升级用户仍保持 build 19 行为。
- Widget 快照只是本机派生展示缓存，不上传后端，不参与 LWW 同步冲突，也不会改变训练记录数据。
- App Group entitlement 需要在 Apple Developer Portal 中配置后才能正常 Archive/TestFlight 签名。
- 后端可以先保持现状，不影响 build 20 上传；新版小组件能力需要新版 iOS 客户端。
- TestFlight `1.0 (20)` 尚未上传；上传并真机验证前不要创建 `v1.0-b20` tag。

## 已完成验证

- OpenSpec 校验通过：`add-workout-summary-widget` strict validate。
- 后端构建通过：`JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home ./gradlew build`。
- iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- iOS simulator test 通过：`xcodebuild test ... CODE_SIGNING_ALLOWED=NO`，`162` 个测试通过，`0` failure。
- `git diff --check` 通过。
- 生产 health 已确认：`https://dontlift.peipadada.com/actuator/health` 返回 `UP`。
- 生产 dev token 已确认关闭：`POST /auth/dev/token` 返回 `404`。
- 生产 Flyway 已确认最新记录为 `18  workout set is warmup  success=true`。

## TestFlight 回归重点

- 真机安装 TestFlight `1.0 (20)` 后，确认 Apple 登录、冷启动、同步和 Team 页加载正常。
- 添加 small/medium 训练摘要小组件，分别验证空状态、本周已有训练、今日已练和最近训练展示。
- 有进行中训练时，确认小组件展示当前训练名，不出现“继续 训练”，点击能回到训练会话。
- 完成或放弃训练后，观察小组件刷新后的状态是否合理；系统延迟刷新可以接受，但不能崩溃或显示伪造数据。
- 验证 Live Activity 和组间休息倒计时没有被常驻小组件影响。
- 设置页回归默认休息时长、消耗估算开关、估算体重输入、法律页入口。
