## Context

当前 `DontLiftWidgetsExtension` 只注册训练会话 Live Activity，适合训练中实时展示；主屏/锁屏常驻 Widget 还不存在。训练首页已有 `WorkoutHistoryStore.HomeWorkoutSnapshot` 派生口径，包含本周训练量、次数、节奏、最近训练和连续天数，常驻 Widget 不需要重新扫描完整 SwiftData 聚合树。

Widget extension 与主 App 是独立进程，不能读取主 App 内存状态。当前 SwiftData `ModelContainer` 也没有放入 App Group 容器。第一版小组件应使用主 App 写入 App Group 的小型 JSON 快照，让 extension 只读快照并渲染 timeline。

本变更不涉及后端、身份、幂等写接口、同步对象或软删除。Widget 快照是本机派生展示缓存，不是云同步真相源；丢失后由主 App 从原始训练记录重新写出。

## Goals / Non-Goals

**Goals:**

- 新增 small 与 medium 训练摘要 Widget。
- 复用训练首页派生摘要口径，展示今日/本周训练状态、7 天节奏与最近训练。
- 有进行中训练时，在 Widget 中优先展示继续训练状态。
- 使用 App Group JSON 快照在主 App 与 extension 间共享最小数据。
- Widget 点击只打开 App 或深链到训练页。

**Non-Goals:**

- 不让 Widget extension 直接读取 SwiftData、Keychain/JWT 或访问后端 API。
- 不在 Widget 内创建训练、完成组、结束训练或修改本地数据。
- 不新增 Team、计划选择、Control Widget、Shortcuts、Siri 或 Spotlight 能力。
- 不改变现有 Live Activity、训练记录、同步、HealthKit 或 Team 分享契约。

## Decisions

### 1. App Group JSON 快照，而不是 extension 读 SwiftData

主 App 新增 `WorkoutWidgetSnapshot` 与 `WorkoutWidgetSnapshotStore`。`WorkoutHistoryStore` 生成或刷新首页摘要后，主 App 将必要字段写入 `UserDefaults(suiteName:)`；Widget timeline provider 从同一个 suite 读取。

理由：第一版只需要十几个展示字段。App Group JSON 比迁移 SwiftData store 到 group container 更小，也避免 extension 扫完整训练树。

备选方案：Widget extension 直接创建 SwiftData `ModelContainer` 读取训练。放弃原因是容器位置、schema、extension 预算和并发读写边界都更复杂，且不需要。

### 2. 快照字段保持展示级，不保存完整训练树

快照包含：

- 写入时间。
- 今日已完成训练次数。
- 本周训练量、训练次数、组数、次数。
- 7 天节奏数组。
- 当前连续训练天数。
- 最近一条本周训练摘要。
- 进行中训练标题与计时起点（若存在）。

理由：这些字段覆盖 small/medium UI；更细的动作、组、重量明细留在 App 内。统计仍可从原始训练记录重算，快照不参与同步冲突。

### 3. Widget 只做展示和打开 App

Widget 使用 `StaticConfiguration` + `TimelineProvider`，不引入配置 intent。点击区域使用 `widgetURL` / `Link` 打开 `dontlift://workout` 或 `dontlift://workout/live`。

理由：第一版核心是 glanceable summary。计划选择、直接开始训练和系统 Control 都需要更多 App Intent surface，先不做。

### 4. 刷新点收敛在主 App 已有状态变化

主 App 在以下时机写快照并触发 `WidgetCenter.reloadTimelines`：

- App 启动后 `WorkoutHistoryStore` 初始化/刷新。
- sync 完成或训练变更导致历史摘要刷新。
- 进行中训练开始、计时启动、结束或放弃。

理由：Widget timeline 刷新由系统调度，不保证实时；训练中实时状态已由 Live Activity 承担。常驻 Widget 只需在离散事件后尽快刷新。

## Risks / Trade-offs

- [Risk] 未配置 App Group 时 extension 读不到快照。
  Mitigation：App 与 `DontLiftWidgetsExtension` 增加同一个 application group entitlement；读取失败时展示默认空状态。

- [Risk] Widget 刷新不是实时，刚完成训练后主屏可能短暂显示旧数据。
  Mitigation：主 App 写快照后调用 `WidgetCenter.reloadTimelines`；验收口径允许系统调度延迟。

- [Risk] 进行中训练的计时在 Widget 上不应承担 Live Activity 的实时职责。
  Mitigation：Widget 只展示「进行中 / 继续训练」和可选起点摘要；秒级计时继续由 Live Activity 负责。

- [Risk] 深链目标如果未处理，会只打开 App 不跳到训练页。
  Mitigation：先保证可打开 App；接入已有根路由时只增加 `workout` / `workout/live` 两个窄路径。

## Migration Plan

1. 增加 App Group entitlement 到主 App 与 Widget extension。
2. 新增共享快照模型和快照 store。
3. 主 App 在历史摘要与训练会话变化时写快照。
4. Widget bundle 注册训练摘要 Widget，保留现有 Live Activity。
5. 构建验证主 App 与 extension 编译通过。

Rollback：移除 Widget 注册与新增快照写入即可；不改后端和持久化 schema，无数据迁移风险。

## Open Questions

- App Store Connect/Developer Portal 中对应 App Group 是否已创建，需要真机签名阶段确认；本地 simulator 构建可用 `CODE_SIGNING_ALLOWED=NO` 验证代码路径。
