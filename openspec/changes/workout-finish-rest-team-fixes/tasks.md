> 五块（A 结束确认 / B 停休息 / C 提醒声 / D 灵动岛 / E Team 刷新）逻辑独立、可分批。A+B 同改 `finish()` 建议一并做。后端无改动。
>
> **实现进度（2026-06-17）**：A/B/C/D/E 全部代码已实现。**编译未验证**——本机未安装 iOS 26.4 平台/模拟器运行时，`xcodebuild` 无可用目标（`iOS 26.4 is not installed`）；§6.1 及所有「手测」项需在装好平台的机器/真机上跑。SourceKit 报错均为 macOS SDK 误判（AVAudioSession/UIKit）与同步组索引竞态，非真实错误。

## 1. 结束训练：文案对齐 + 未完成组数强确认（A）

- [x] 1.1 `Workout/WorkoutViews.swift`：按钮文案 `停止训练 → 结束训练`（含 accessibilityLabel）
- [x] 1.2 新增 `remainingSetCount`（`workout.exercises.flatMap(\.sets).filter { !$0.completed }.count`），与 `completedSetCount`/`remainingExerciseCount` 同处
- [x] 1.3 确认框（`paperConfirmDialog`）文案分支：`finishConfirmTitle`/`finishConfirmMessage` 计算属性——`remainingSetCount==0` 维持「结束训练?/将归档本次训练并计算 PR」；`>0` 改「还有 N 组未完成/确定结束训练吗?将归档本次训练并计算 PR」
- [x] 1.4 确认框仍**始终弹出**（不因 0 未完成而跳过）

## 2. 结束/丢弃会话即停休息计时（B）

- [x] 2.1 `finish()` 补 `restTimer.stop()`（撤通知 + 收 FAB/弹窗 + `endActivity`）
- [x] 2.2 `WorkoutSession.discard(...)` 两处调用点（`WorkoutListView` / `PlanDetailView`）补 `restTimer.stop()`
- [x] 2.3 确认 `restTimer` 可达：`WorkoutLoggingView` 已注入；`WorkoutListView`/`PlanDetailView` 新增 `@Environment(RestTimerController.self)`
- [ ] 2.4 手测：结束训练后 FAB/弹窗/灵动岛立即消失，无残留倒计时；待发本地通知被撤销 ⏳需平台

## 3. 休息结束提醒声（前台，无视静音键）（C）

- [x] 3.1 新增短音效资源 `Workout/rest_complete.caf`（0.42s 双音「叮」，IMA4，~14KB，afconvert 生成）入 app target
- [x] 3.2 `Workout/RestTimer.swift`：`playEndSound()` 配 `AVAudioSession.playback` + `[.duckOthers, .mixWithOthers]`；`setActive(true)→play()→播完 Task.sleep 后 setActive(false, .notifyOthersOnDeactivation)`
- [x] 3.3 `onTick()` 到点分支：`playEndSound()`（内部按 `soundEnabled` 守卫）+ 维持 Haptics
- [x] 3.4 新增 `soundEnabled`（UserDefaults，默认开），`RestTimerSheet` 底部加「声音」开关 pill（与「震动」同款）
- [x] 3.5 前台/通知声去重：`PushManager.willPresent` 对 `RestTimerController.notificationId` 返回 `[.banner]`（抑制通知声，前台声由 AVAudioPlayer 负责）
- [ ] 3.6 手测：静音档下前台到点能听到一声；播放时背景音乐被 duck 后恢复；开关关闭后无声 ⏳需平台
- [ ] 3.7 ⚠️ 落地核对：`rest_complete.caf` 是否被同步组纳入「Copy Bundle Resources」（运行期 `Bundle.main.url` 取得到）；取不到则手动加入 target membership

## 4. 灵动岛倒计时结束自动消失（D）

- [x] 4.1 `RestTimer.swift` `startActivity`：`request` 后 `act.end(content, dismissalPolicy: .after(endDate + dismissGrace(2s)))` 预约自动消失
- [x] 4.2 前台自然结束 / 提前结束 / 结束训练：仍 `endActivity(.immediate)` 覆盖预约；`adjust(±10s)` 改为整体重建（已 end 的 activity 不可 update）
- [ ] 4.3 验证 ActivityKit `.after` 行为：休息 < 5min 安全；确认「先 request 后 end(.after:)」期间灵动岛仍正常显示 `Text(timerInterval:)` 倒计时 ⏳需平台
- [ ] 4.4 兜底（若 4.3 行为异常才需要）：scenePhase 回前台时清理过期 activity ⏳条件性，暂未实现
- [ ] 4.5 手测：后台/锁屏让倒计时自然归零 → 灵动岛在 endDate + grace 后自动消失，不再停留 ⏳需平台

## 5. 删训练后 Team 今日动态一致（E，iOS 侧）

- [x] 5.1 `Sync/SyncEngine.swift`：`syncAll()` 完成后 post `.dontliftSyncCompleted`（新增 `Notification.Name` 扩展）
- [x] 5.2 `Team/TeamViews.swift`：`TeamDetailView` `onReceive(.dontliftSyncCompleted)` → `reload()`
- [x] 5.3 `TeamDetailView` 加 `@Environment(\.scenePhase)`，回 `.active` 时兜底 `reload()`
- [ ] 5.4 手测：Team 页停留 → 删对应训练 → 等同步完成 → feed 中该动态消失（无需手动下拉）⏳需平台

## 6. 验证与归档

- [ ] 6.1 ⛔ `xcodebuild` 编译 **未能执行**——本机未装 iOS 26.4 平台/运行时；需在装好平台的机器上跑（iPhone 17 Pro 模拟器，`CODE_SIGNING_ALLOWED=NO`）
- [ ] 6.2 五条场景真机/模拟器走查（尤其 C 的静音档、D 的后台归零，需真机更准）⏳需平台
- [x] 6.3 `openspec validate workout-finish-rest-team-fixes --strict` 通过
- [ ] 6.4 归档：`openspec archive workout-finish-rest-team-fixes`（待编译 + 走查通过后）
