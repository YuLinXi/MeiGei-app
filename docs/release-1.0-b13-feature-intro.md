# v1.0-b13 发版功能介绍

> 适用版本：`1.0 (build 13)`
> 后端状态：已部署。生产 Flyway 最新为 `V15 checkin reaction push receipts success=true`。
> iOS 状态：准备上传 TestFlight。

## 一句话摘要

本次 build 13 聚焦训练完成后的分享体验、训练 Live Activity 稳定性，以及 Team 表情回应的幂等与推送去重收口。

## 面向测试用户的更新说明

- 训练完成后可以生成更清晰的训练分享海报，海报只保留视觉卡片，保存后会识别已保存状态，避免重复点击。
- 分享海报弹窗改为可下拉关闭的通用底部弹窗样式，不再显示多余标题或返回按钮。
- 保存海报后的顶部全局提示现在会显示在弹窗之上，不会再被分享弹窗遮挡。
- 海报里的训练动作、组数、时长、训练量等文案改为中文，动作与组数信息更大、更容易读。
- 对无重量或自重动作，海报不再误写“未记录重量”，会展示次数或已完成组数。
- 训练 Live Activity 更稳定：训练中、休息中、结束训练等状态连续变化时，锁屏/灵动岛不应残留旧状态。
- Live Activity 的休息状态增加“结束”入口，锁屏或灵动岛里提前结束休息后，会尽量立即恢复训练状态。
- iPad 系统分享面板增加 popover 锚点，避免分享图片时因缺少来源视图而崩溃。
- Team 表情回应更稳：重复点击和并发首次点表情时，服务端会按幂等键与唯一约束兜底，减少重复推送或状态错乱。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 13`，App、widget、测试 target 已同步。
- 新增 `GlobalOverlayWindowHost`，用透明顶层 `UIWindow` 承载 `GlobalMessageOverlay` 和 `GlobalSyncProgressOverlay`，窗口层级为 `.alert + 1`，不拦截触摸。
- 训练海报保存流程增加 `hasSavedPoster` 状态，保存成功后按钮进入“已保存”态并禁用再次保存。
- `WorkoutPosterData` 优化无重量动作的 top set 文案：优先展示重量和次数，其次展示最大次数，最后展示已完成组数。
- `ActivityView` 为 `UIActivityViewController` 设置 iPad popover source view/source rect。
- `WorkoutLiveActivityController` 增加串行 ActivityKit 操作队列和 generation 校验，避免 request/update/end 乱序。
- `EndRestIntent` 在 widget 进程内先把休息 Activity 更新为训练状态，再通过 Darwin 通知主 App 清理本地休息状态。
- Live Activity expanded 与锁屏卡片增加“结束休息”按钮。
- 后端新增 Flyway `V15__checkin_reaction_push_receipts.sql`，创建 `checkin_reaction_push_receipt` 表并回填历史非自评 reaction receipt。
- `CheckinReactionMapper` 新增 `insertReactionIfAbsent`，使用 `ON CONFLICT (checkin_id, user_id) DO NOTHING` 处理并发首次插入。
- `CheckinService.react` 在并发插入失败时读取既有 reaction，同 emoji 复用，不同 emoji 更新。
- `POST /checkins/{checkinId}/reactions` 增加 `Idempotency-Key` 要求；iOS `TeamService.react` 已随请求发送 key。

## 兼容性说明

- 后端已部署到 `V15`，TestFlight build 13 回归可以直接验证 reaction push receipt 表和历史回填后的行为。
- 未升级 iOS 用户的训练记录、计划、Team 浏览、打卡列表读取不受影响。
- 后端先发后，旧版 iOS 若仍未携带 `Idempotency-Key` 调用 Team 表情回应写接口，可能收到 `400 缺少 Idempotency-Key`；build 13 已补齐该 header。
- V15 只新增表与历史回填，不修改既有 workout、plan、checkin 主表结构。
- 全局提示改为透明顶层窗口，理论上不影响触摸；需在真机上重点验证保存海报提示、同步提示、sheet/fullScreenCover 场景。
- Live Activity 仍依赖系统 ActivityKit 行为；锁屏/灵动岛入口需要真机验证，模拟器只能覆盖编译和基础测试。

## 已完成验证

- 生产后端已于 2026-06-30 18:03 CST 完成部署，迁移前备份文件：`./backups/dontlift_2026-06-30_180248.sql.gz`。
- 生产后端健康检查通过：`curl https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`。
- 生产 Flyway 当前最新为 `V15 checkin reaction push receipts success=true`。
- 后端构建通过：`export JAVA_HOME=$(/usr/libexec/java_home -v 21) && ./gradlew build`。
- iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- iOS simulator test 通过：同 destination 下 `xcodebuild ... test -resultBundlePath /tmp/DontLift-b13-tests.xcresult`。
- xcresult summary：`result = Passed`，`totalTestCount = 100`，`failedTests = 0`，`skippedTests = 0`。
- `git diff --check` 通过。
- OpenSpec 校验按本次要求未执行。

## TestFlight 回归重点

- 部署后端后确认 `flyway_schema_history` 最新为 `15 checkin reaction push receipts success=true`。
- 从 build 12 升级到 build 13 后，登录、同步、训练首页、计划、Team 首页可正常进入。
- 训练完成页打开分享海报弹窗：顶部无“分享海报”标题，可下拉关闭，无返回按钮。
- 保存海报成功后，顶部全局 message 必须显示在弹窗之上，且保存按钮进入“已保存”态，不能再次点击。
- 分享海报里的中文指标、励志文案、动作列表、组数和自重/无重量动作展示正确。
- iPhone 和 iPad 都能打开系统分享面板，iPad 不崩溃。
- 训练中开启 Live Activity 后，完成组、进入休息、调整休息、提前结束休息、结束训练，锁屏/灵动岛状态不残留。
- 锁屏或灵动岛点击“结束休息”后，主 App 回前台时本地休息状态和通知状态能正确清理。
- Team 动态里点表情、切换表情、取消表情后，列表回拉状态正确。
- 同一打卡多人快速点表情时，推送不重复，自己给自己点表情不发推送。
- 后台同步提示和其他全局 message 在 sheet/fullScreenCover 上方展示且不拦截操作。
