## 1. iOS 端 - Activity 数据契约与 Widget 视图

- [x] 1.1 将现有 `RestActivityAttributes` 升级或替换为训练会话 Activity attributes，包含 `workoutId`、`workoutTitle`、`startedAt`、`phase`、组统计、下一组摘要与可选休息倒计时字段。
- [x] 1.2 确保新的 Activity attributes 源码同时编入主 App 与 `DontLiftWidgetsExtension`，必要时更新 `DontLift.xcodeproj` Sources membership。
- [x] 1.3 将 `RestTimerLiveActivity` 调整为训练会话 Live Activity，并按 `workout` / `rest` phase 渲染不同 Dynamic Island expanded、compact、minimal 与锁屏内容。
- [x] 1.4 在 `workout` phase 使用系统自走计时文本展示从 `startedAt` 起算的正向计时，避免秒级 Activity update。
- [x] 1.5 在 `rest` phase 继续展示休息倒计时、下一组动作、组序号、重量、次数和「结束休息」按钮。

## 2. iOS 端 - 训练会话 Live Activity 控制器

- [x] 2.1 新增主 App 内的训练会话 Live Activity 控制器，统一持有当前 `Activity` 引用与 start/update/end 方法。
- [x] 2.2 实现 `workout` phase state 构造逻辑，派生已完成组数、剩余动作数与下一组摘要。
- [x] 2.3 在训练计时启动路径接入控制器：完成第一组或手动开始训练时创建或更新训练会话 Live Activity。
- [x] 2.4 在完成组、追加/删除组、切换完成态等会影响统计或下一组摘要的路径中更新 `workout` phase 离散状态。
- [x] 2.5 在 App 回前台时校准当前 active workout 与 Activity 状态；不存在有效进行中训练时结束残留 Activity。

## 3. iOS 端 - 休息 phase 接入

- [x] 3.1 将 `RestTimerController.start` 的 Live Activity 创建逻辑改为通知训练会话控制器进入 `rest` phase，保留本地通知、ticker、声音、触觉与完成事件逻辑。
- [x] 3.2 将休息 `+10s` / `-10s` 调时路径改为更新同一训练会话 Live Activity 的 `restEndDate`，并保持 App 内 FAB、弹窗、本地通知一致。
- [x] 3.3 将休息自然结束路径改为退出 `rest` phase 并恢复 `workout` phase，不因单次休息结束而结束整场 Live Activity。
- [x] 3.4 将 App 内提前结束休息路径改为退出 `rest` phase，保留真实休息时长回写。
- [x] 3.5 保留休息结束后台兜底逻辑，验证 App 回前台后能从过期 `rest` phase 收束到正确 `workout` phase 或结束 Activity。

## 4. iOS 端 - App Intent 与训练结束收束

- [x] 4.1 更新 `EndRestIntent` 的处理语义，使 Live Activity 上的「结束」只结束当前休息，不结束或归档训练。
- [x] 4.2 确认 Darwin 通知回传主 App 后仍调用休息提前结束逻辑，并触发训练会话 Live Activity 回到 `workout` phase。
- [x] 4.3 在结束训练确认路径中同时停止休息计时、本地通知、App 内休息 UI，并立即结束训练会话 Live Activity。
- [x] 4.4 在放弃训练路径中立即结束训练会话 Live Activity，并避免残留 Dynamic Island / 锁屏状态。
- [x] 4.5 确认 Live Activity 权限关闭或 ActivityKit request/update 失败时，不影响 App 内训练记录、休息计时和本地提醒。

## 5. 后端 - 无改动确认

- [x] 5.1 确认本变更不新增后端 API、数据库迁移、同步字段或 Team checkin 字段。
- [x] 5.2 确认 `Workout` / `WorkoutSet` 现有同步契约不变，Live Activity 状态不进入云同步真相源。

## 6. 基础设施 / 验证

- [x] 6.1 运行 iOS Simulator 构建：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [ ] 6.2 在 Simulator 或本地可执行路径中验证训练计时开始、进入休息、休息调时、提前结束休息、结束训练、放弃训练均不会崩溃。
- [ ] 6.3 真机验证锁屏与 Dynamic Island：`workout` phase 显示训练正向计时，`rest` phase 显示休息倒计时，休息结束后恢复训练正向计时。
- [ ] 6.4 真机验证 Live Activity 权限关闭时的降级路径：App 内 REC/FAB/弹窗、本地通知、声音与触觉仍可工作。
- [ ] 6.5 条件验证 Apple Watch Smart Stack；若未出现，按平台条件能力记录为降级，不作为失败。
