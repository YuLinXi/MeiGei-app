## Why

训练「收尾」链路（结束训练 → 组间休息计时 → 灵动岛 → Team 今日动态）在 build 3 后暴露 5 个体验/一致性问题，都集中在「会话结束与休息计时的生命周期」和「删除后跨域一致性」上：

1. **结束按钮文案与既有 spec 不符**：`workout-tracking` 的「结束训练需二次确认」Requirement 早已规定点「结束」并展示「动作数·已完成组数」摘要，但 `WorkoutViews.swift:1327` 的按钮仍写「停止训练」。同时缺一个用户高频踩的场景——**还有动作组没勾完就结束**时，确认框没有任何警示，容易误归档。

2. **结束训练不停休息计时（确认存在的 bug）**：`finish()`（`WorkoutViews.swift:1089-1098`）只置 `endedAt`、写 HealthKit、重算派生，**从不调用 `restTimer.stop()`**。RestTimer 是与会话解耦的全局单例（`DontLiftApp.swift:12`），所以结束训练后若仍有休息在跑，FAB/弹窗/灵动岛会继续跑到自然归零。

3. **休息结束前台无声**：后台/锁屏靠本地通知带 `.sound`（`RestTimer.swift:122-133`），但**前台到点只有 Haptics 震动**（`RestTimer.swift:113-120`），工程内无任何音频播放代码。健身房嘈杂 + 手机常静音档，缺一声明确提醒。

4. **灵动岛倒计时结束不消失**：前台 `onTick()` 到点会 `clear()→endActivity()`；但**后台 Timer 被系统挂起，没有任何触发点调 `activity.end()`**（`RestTimer.swift:154-158` 的 `endActivity` 用了正确的 `.immediate`，只是没人在后台调它）。灵动岛 `Text(timerInterval:)` 自走到 00:00 后一直停留。

5. **删训练后 Team 今日动态不同步**：后端链路完整——workout 墓碑 push 到 `/sync/workouts/push` 时 `WorkoutSyncService` 会 `checkinService.removeForWorkout()` 级联删 checkin（`WorkoutSyncService.java:81-87`）。问题纯在 iOS：`TeamDetailView` 的 checkins **只在首次 `.task` 与手动 `.refreshable` 时加载**（`TeamViews.swift`），不监听删除/同步完成事件，用户停在 Team 页时仍显示已删训练的旧动态。

本 change 一次修齐这 5 条，统一「会话结束即收束休息计时全套（FAB/弹窗/通知/灵动岛）」并补「同步完成 → Team feed 刷新」的跨域一致性。

## What Changes

### A. 结束训练：文案对齐 + 未完成组数强确认

- 按钮文案 `停止训练 → 结束训练`（`WorkoutViews.swift:1327`），与既有 spec 与确认框一致。
- 二次确认**始终弹出**（沿用现有 `paperConfirmDialog`），但**文案随未完成组数变**：
  - 全部勾完：维持「结束训练?/将归档本次训练并计算 PR」。
  - 有未完成组（新增统计 `remainingSetCount`）：标题/正文强提示「还有 N 组未完成，确定结束训练吗?」。
- 不改副作用集合本身（仍 HealthKit + PR + Team 打卡），仅强化误操作防护。

### B. 结束训练即停休息计时（修 bug #2）

- `finish()` 内补 `restTimer.stop()`：撤销待发本地通知、收起 FAB/弹窗、`endActivity(.immediate)`。复用现成的 `RestTimer.stop()`（`RestTimer.swift:88-93`），无新逻辑。
- 「丢弃进行中会话」（`WorkoutSession.discard`）路径同样需停休息计时，保持一致。

### C. 休息结束加一声提醒（前台，无视静音键）

- 自带一个**短音效资源文件**（`.caf`/`.wav`，几 KB），随 app bundle。
- 用 `AVAudioPlayer` + `AVAudioSession` `category=.playback, options=[.duckOthers, .mixWithOthers]`：**无视静音键**（健身工具刚需，对齐 Strong/Hevy）、与用户后台音乐共存只 duck 不抢占。
- 前台 `onTick()` 到点：播一声 + 维持现有 Haptics；与本地通知声**去重**（前台不重复响）。
- 设置项新增 `soundEnabled` 开关（默认开），与现有 `hapticsEnabled` 同款。

### D. 灵动岛倒计时结束自动消失（修 bug #4）

- `startActivity` 时即用 `Activity.end(content, dismissalPolicy: .after(endDate + 宽限))` **预约到点自动消失**，把「何时消失」交给系统，**后台无需任何唤醒**。
- 前台自然结束 / 提前结束 / 结束训练时，仍 `endActivity(.immediate)` 立即收，覆盖预约。
- 落地验证 ActivityKit `.after` 的最大延迟与「先预约后 update」的行为。

### E. 删训练后 Team 今日动态一致（修 #5，iOS 侧）

- iOS：Team 详情页订阅「同步完成」事件（`NotificationCenter`），`syncAll()` 成功后广播，Team 页 `onReceive` 时 `reload()`；scenePhase 回前台也兜底刷新。
- **以「同步完成」而非「删除动作」为触发**：删除是离线 `pendingDelete`，须等 push 成功后端才真正删 checkin，过早刷新会拉回旧数据。
- 后端无需改动（级联删已完整）。

## Capabilities

### Modified Capabilities

- `workout-tracking`：「结束训练需二次确认」Requirement 补「按钮文案=结束训练」「未完成组数强确认文案」「结束/丢弃时 MUST 停止休息计时全套（FAB/弹窗/通知/灵动岛）」；新增「休息结束提醒（前台声音 + 震动，无视静音键）」与「休息 Live Activity 倒计时结束自动消失」两条 Requirement。
- `team-ui`：新增「删除训练后今日动态一致性」Requirement——Team feed MUST 在对应训练删除并同步后反映移除（同步完成事件触发刷新 + 回前台兜底）。

## Impact

- **iOS 视图层**：`Workout/WorkoutViews.swift`——`finish()` 补 `restTimer.stop()`、按钮文案、`remainingSetCount` 与确认框分支；丢弃会话路径同停休息。`Team/TeamViews.swift`——订阅同步完成 / scenePhase 刷新 checkins。
- **iOS 休息计时层**：`Workout/RestTimer.swift`——前台到点播音效（AVAudioPlayer + AVAudioSession）、`soundEnabled` 开关、`startActivity` 预约 `.after` 自动消失。
- **iOS 同步层**：`Sync/SyncEngine.swift`——`syncAll()` 成功后 post 同步完成通知（供 Team 刷新订阅）。
- **资源**：新增一个短音效文件入 app target。
- **设置**：新增 `soundEnabled`（UserDefaults），与 `hapticsEnabled` 同管理位置。
- **后端**：无改动（workout 删除级联撤销 checkin 已完整）。
- **非影响**：不改同步聚合/LWW/幂等契约；不改 Team 服务端权威模型；不改 PR/历史曲线重算逻辑；不改动作库。

## Non-goals

- **不做**「暂停整场训练」——既有 spec 明确不提供，本 change 不引入。
- **不做** 休息计时的后台音频持续播放/后台任务唤醒——靠 `.after` 预约 + 本地通知，不申请后台音频后台模式。
- **不做** 多档提醒音/自定义铃声选择——只一声固定短音 + 开关。
- **不做** Team feed 的实时推送刷新（WebSocket/APNs 触发 Team 页 live 更新）——沿用进页面/下拉/同步完成/回前台刷新；删除一致性靠后端级联 + iOS 重拉。
- **不做** 已完成会话编辑后的 Team 摘要更新链路改造（既有 spec「显式编辑」已覆盖，不在本 change 重做）。
- **不做** 后端 checkin 级联逻辑改动（已完整）。
