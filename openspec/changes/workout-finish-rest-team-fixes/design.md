# 设计说明

本 change 是 5 个聚焦「会话收尾 + 休息计时生命周期 + 跨域一致性」的修复，逻辑互相独立、可分批落地。记录其中有岔路/有坑的 4 个决策。

## D1. 结束训练确认框：始终弹，文案随未完成组数变

**决策**：维持「结束训练 = 重操作，始终二次确认」的一致性（既有 spec 已要求），不走「无未完成就不弹」的捷径。仅在**存在未完成组**时把确认文案升级为强警示。

- 沿用现成 `paperConfirmDialog`（`DesignSystem/Components.swift:192-325`），不引入新 UI。
- 新增统计 `remainingSetCount = workout.exercises.flatMap(\.sets).filter { !$0.completed }.count`（与现有 `completedSetCount` / `remainingExerciseCount` 同处，`WorkoutViews.swift:580-587`）。
- 文案分支：
  - `remainingSetCount == 0`：标题「结束训练?」/正文「将归档本次训练并计算 PR」。
  - `remainingSetCount > 0`：标题「还有 \(remainingSetCount) 组未完成」/正文「确定结束训练吗?将归档本次训练并计算 PR」。

**理由**：用户原话是「有未完成时弹确认框」，但既有 spec 已要求**无条件**确认且展示已完成组摘要——若改成「无未完成不弹」会与 spec 冲突且削弱归档心理预期。取「始终弹 + 文案随状态变」两者兼得，spec 改动最小。

## D2. 结束/丢弃会话即收束休息计时全套

**决策**：会话离开「进行中」态（结束或丢弃）时，MUST 调一次 `restTimer.stop()`。

- `RestTimer.stop()`（`RestTimer.swift:88-93`）已是「清状态 + 撤待发通知 + `endActivity`」的全套，直接复用，零新逻辑。
- 触发点：`finish()`（`WorkoutViews.swift:1089`）与 `WorkoutSession.discard(...)` 路径各补一处。
- 前置确认：`WorkoutDetailView`/相关视图能拿到 `restTimer`（`DontLiftApp.swift:12` 注入，落地时确认 environment 可达；若不可达则经回调上抛到持有 restTimer 的层级）。

**坑**：RestTimer 是全局单例、生命周期与会话解耦——这正是 bug 根因。不要试图把 RestTimer 绑进会话，改动面太大且违背「休息计时跨会话/锁屏存活」的既有设计；只在会话退出进行中态时显式 stop 即可。

## D3. 休息结束提醒声：自带音效 + .playback 无视静音键

**决策**：自带一个短音效文件，用 `AVAudioPlayer` 播，`AVAudioSession` 配 `.playback`。

```
AVAudioSession.sharedInstance()
  .setCategory(.playback, options: [.duckOthers, .mixWithOthers])
  到点：setActive(true) → player.play() → 播完 setActive(false, .notifyOthersOnDeactivation)
```

| 维度 | 取舍 |
|------|------|
| 无视静音键 | `.playback` 类别天然无视静音键——健身房/口袋静音档刚需，对齐 Strong/Hevy 等「严肃工具」 |
| 与用户音乐 | `.duckOthers + .mixWithOthers`：播提示音时把背景音乐瞬时压低而非掐断，播完恢复 |
| 音源 | 自带 `.caf`/`.wav` 短音（几 KB，音色可控），不用 `AudioServicesPlaySystemSound`（跟随静音键 = 静音档不响，等于功能失效） |
| 开关 | 新增 `soundEnabled`（UserDefaults，默认开），与 `hapticsEnabled` 同款 |

**前台/后台去重**：后台靠本地通知 `.sound`，前台靠本 AVAudioPlayer。前台 `onTick()` 到点时本地通知**同刻也会触发**——需确保不重复响两声。方案：前台到点先撤掉待发本地通知（`stop()` 已做 removePending），再由 AVAudioPlayer 出声；或前台分支只播 AVAudioPlayer、不依赖通知声。落地时实测一遍叠加行为。

**坑**：`setActive(true)` 会打断/影响其他音频会话；务必播完 `setActive(false, .notifyOthersOnDeactivation)` 让用户音乐恢复。`.playback` 不要常驻激活，只在到点瞬间激活。

## D4. 灵动岛自动消失：启动即预约 .after，前台再 .immediate 覆盖

**决策**：`startActivity` 时即预约「到点后自动 dismiss」，后台不需要任何唤醒。

```
startActivity:
  Activity.request(...)               // 启动
  activity.end(finalContent, dismissalPolicy: .after(endDate + grace))  // 预约消失
前台自然结束 / 提前结束 / 结束训练:
  endActivity()  →  activity.end(nil, dismissalPolicy: .immediate)      // 立即收，覆盖预约
```

**为何不靠后台触发**：后台 `Timer` 被系统挂起，`onTick()` 停摆；本地通知到点回调里也没 end activity——没有可靠的后台触发点。`.after` 把消失时机交给系统，是唯一不需后台代码的稳妥解。

**待验证（落地时）**：
- ActivityKit `.after(date)` 的**最大允许延迟**（系统对 dismiss 延迟有上限，超出会被钳制）；休息时长通常 < 5 分钟，远低于上限，安全。
- 「先 `request` 紧接着 `end(.after:)`」是否会让 activity 立刻进入 ended 态而提前隐藏——需确认 `.after` 期间灵动岛仍正常显示 `Text(timerInterval:)` 倒计时。若行为异常，退化方案：保留预约逻辑，另在 scenePhase 回前台兜底清理过期 activity（D 路线 3）。
- `grace` 宽限（如 +2~3s）给「到点那声提醒」留出可见窗口，避免归零瞬间灵动岛就没了。

## D5. Team feed 删除一致性：以「同步完成」为触发，非「删除动作」

**决策**：iOS Team 页刷新由 `syncAll()` 成功后广播的通知触发，而非用户删除动作的瞬间。

```
删训练: markDeleted (pendingDelete) ──┐
                                      │ 离线，本地即时
SyncEngine.syncAll() push 成功 ───────┤ → 后端 checkinService.removeForWorkout()
                                      │
post .dontliftSyncCompleted ──────────┘ → TeamDetailView.onReceive → reload()
scenePhase → active (兜底) ──────────────→ reload()
```

**理由**：删除是离线 `pendingDelete`，后端 checkin 要等下一次 push 成功才真正删。若以「删除动作」触发刷新，会在后端还没删时拉回旧 checkin，反而显示不一致。绑定到「同步完成」事件，保证「后端已删 → 再拉 → 看到移除」的有序。

**坑**：`syncAll()` 完成通知要在 push 成功后 post（区分成功/失败）；Team 页若未打开则订阅无副作用。不引入 WebSocket/APNs 实时刷新（非 goal）。

## 落地顺序（互相独立，可分批）

A（文案+确认）/ B（停休息）/ C（提醒声）/ D（灵动岛）/ E（Team 刷新）五块无强依赖。建议先 A+B（同改 `finish()`，一处收口）→ D（灵动岛）→ C（音效，需加资源）→ E（跨域，需 SyncEngine 事件）。
