# v1.0-b18 临时修复版功能介绍

> 适用版本：`1.0 (build 18)`
> 后端状态：本次无后端运行时代码和数据库迁移变更，无需重新部署；生产 health 已于 2026-07-07 23:13 CST 确认为 `UP`，Flyway 最新仍为 `V18 workout set is warmup success=true`。
> iOS 状态：TestFlight `1.0 (18)` 已安装并完成回归，2026-07-07 23:34 CST 由用户确认。

## 一句话摘要

本次 build 18 是临时 hotfix，专门修复添加动作抽屉里点击动作库搜索框后，真机键盘弹起导致顶部搜索框被遮挡的问题。

## 面向测试用户的更新说明

- 修复训练中「添加动作」抽屉的搜索框遮挡问题：点击搜索框后，键盘弹起时顶部输入框应保持可见。
- 搜索框所在的动作库抽屉顶部间距更稳定，不应再被 sheet 拖拽条或状态栏区域压住。
- 这版不包含新的训练功能、Team 功能或数据模型变化。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 18`，App、widget、测试 target 已同步。
- `ExercisePickerView` 改为使用满高 `ZStack` 承载动作库内容，让 sheet 背景和内容拥有稳定的顶部布局上下文。
- 添加动作抽屉顶部间距从普通 `.padding(.top, 14)` 调整为 `.safeAreaPadding(.top, 14)`，避免键盘触发 sheet 可用区域变化时把搜索框推到顶部安全区外。
- `.ignoresSafeArea(.keyboard, edges: .bottom)` 保留在满高容器层，降低键盘避让对整个动作库抽屉纵向布局的影响。
- 本次无 OpenSpec 行为规格变更，无后端生产代码和 Flyway 迁移。

## 兼容性说明

- build 18 只影响 iOS 客户端 UI 布局，不改变同步数据、后端接口、Team 分享、训练记录或计划数据结构。
- 未升级用户仍可能在真机上遇到 build 17 的添加动作搜索框键盘遮挡问题。
- 后端继续沿用 build 16/17 已部署的 `V18` schema，无需发布后端。
- TestFlight `1.0 (18)` 已安装并完成回归，本次发布可以合并并创建 `v1.0-b18` tag。

## 已完成验证

- iOS build 号已递增到 `1.0 (18)`，App、widget、测试 target 同步。
- 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- iOS simulator test 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO test`，单元测试 `157` 个通过，UI 测试 `6` 个通过，`0` failure。
- XcodeBuildMCP 模拟器路径验证通过：开发者登录后进入训练，打开「添加动作」抽屉，聚焦搜索框并输入 `bench`，搜索框保持在顶部可见。
- `git diff --check` 通过。
- 生产 health 已确认：`curl -fsS https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`。
- 生产 dev token 已确认关闭：`POST https://dontlift.peipadada.com/auth/dev/token` 返回 `404`。
- 生产 Flyway 已确认最新为 `18  workout set is warmup  success=true`，并包含 `17  workout units  success=true`。
- TestFlight `1.0 (18)` 已安装并完成回归，2026-07-07 23:34 CST 由用户确认。

## TestFlight 回归重点

- 真机安装 TestFlight `1.0 (18)` 后，从训练页进入一条训练。
- 点击底部「添加动作」，打开动作库抽屉。
- 点击顶部「搜索动作」输入框，确认键盘弹起后搜索框仍完整可见，不被顶部拖拽条或圆角区域遮挡。
- 输入中文关键词和英文关键词，确认列表过滤正常，左侧分类栏和右侧动作列表不异常跳动。
- 收起键盘后，搜索框、列表、右侧器械快捷索引位置正常。
- 从搜索结果选择动作后，抽屉关闭并成功添加动作。
- 回归计划编辑里打开动作选择器的路径，确认同样不出现顶部搜索框遮挡。
