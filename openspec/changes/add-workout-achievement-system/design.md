## Context

当前客户端基于 SwiftData 持有本地 `Workout`、`WorkoutExercise`、`WorkoutSet` 训练历史记录。`WorkoutHistoryStore` 负责在内存中派生当前周频统计、肌群负荷及单动作历史 PR 记录。

根据 Day-1 铁律：
- 统计（PR/历史曲线/汇总）能重算就重算，少存冗余结果；
- 离线优先：本地即时落盘与响应，不依赖弱网环境；
- 保持严肃健身工具的极简性与高性能。

本设计基于现有架构，引入轻量存根实体 `BadgeGrant` 与纯函数判定引擎 `BadgeEngine`，实现 24 枚独立成就勋章的离线判定、存量回溯与 UI 呈现。

## Goals / Non-Goals

**Goals:**
- **确定性与离线可用**：所有成就判定纯本地完成，断网或无网络环境下训练结束即时弹出庆祝。
- **情感留存与可溯源**：已解锁的勋章精确记录是在哪一天的哪一次训练中解锁的，支持在徽章馆中反查当日训练记录。
- **平滑存量升级**：老用户升级无需任何复杂服务端操作，首启后台异步秒级回溯，主界面展示一次性「生涯回顾」。
- **零冗余膨胀**：徽章元数据（名称、描述、达成阈值、所属板块、图腾标识）全部作为客户端静态枚举代码（`BadgeDefinition`），数据库仅存轻量存根。

**Non-Goals:**
- **服务端权威评审**：不把成就判定搬到后端（避免离线不可用及网络往返延迟）。
- **成就反向降级**：勋章一旦解锁永久成立，即使后续体重上升或某次训练被删除，已获得的荣誉存根不作惩罚性剥夺。

## Decisions

### 1. 数据架构：代码静态定义 + 本地存根表（`BadgeGrant`）

- **决策**：
  采用「静态配置枚举 `BadgeDefinition` + SwiftData 本地实体 `BadgeGrant`」的轻量组合：
  ```swift
  @Model
  final class BadgeGrant {
      @Attribute(.unique) var badgeCode: String // 唯一键，例如 "tonnage_100t"
      var unlockedAt: Date
      var workoutId: UUID?                      // 触发解锁的 Workout.localId
      var snapshotMetric: Double                // 达成时的度量快照 (如当时的重量/吨位)

      init(badgeCode: String, unlockedAt: Date = .now, workoutId: UUID? = nil, snapshotMetric: Double = 0) {
          self.badgeCode = badgeCode
          self.unlockedAt = unlockedAt
          self.workoutId = workoutId
          self.snapshotMetric = snapshotMetric
      }
  }
  ```
- **替代方案对比**：
  - *纯内存动态重算（不存任何表）*：无法确定“是在哪一次训练中被解锁的”（必须每次倒排按时间推导），无法稳定提供“反查当日训练”和“增量弹窗庆祝”的判断基线。
  - *服务端全量管理*：违反离线优先原则，若训练结算时处于弱网或飞行模式，无法呈现高光庆祝弹窗。

### 2. 三大项与体重倍数精准识别策略

- **决策**：
  - **三大项动作绑定**：严格校验 `WorkoutExercise.resolvedBuiltinCode`：
    - 深蹲：`BB_SQUAT`
    - 卧推：`BB_BENCH_PRESS`
    - 硬拉：`max(DEADLIFT, SUMO_DEADLIFT)`（遵循国际力量举 IPF 规则）
  - **自重倍数计算源**：读取 `WorkoutCaloriePreferences.currentWeight`（用户在资料中保存的当前体重）。若用户未录入体重，倍数类勋章不可达成并在未解锁卡片中展示引导文案。
- **替代方案对比**：
  - *按动作名称模糊匹配（包含“深蹲”）*：不可取。容易误将哑铃深蹲、哈克深蹲、高脚杯深蹲等非标准杠铃动作计入，破坏严肃健身严肃性。

### 3. 计算与执行流水线双轨制

```
+--------------------------------------------------------------------------+
|                             BADGE PIPELINE                               |
+--------------------------------------------------------------------------+
|                                                                          |
|  [场景 A: 老用户存量回溯]                  [场景 B: 日常单次训练结算]    |
|  触发: App 装配期 / UserDefaults 未置位    触发: finishWorkout() 确认     |
|                                                                          |
|  1. Task.detached 后台异步拉取全部已完成   1. 提取本次训练数据            |
|     Workouts (时间正序排序)                2. 取出当前未解锁的 BadgeCodes |
|  2. 模拟历史时间线依次判定                 3. 纯函数匹配增量指标          |
|  3. 批量写入 BadgeGrant 存根               4. 若命中:                     |
|  4. 置位 hasCompletedBadgeBackfill = true     - 插入 BadgeGrant          |
|  5. 切换回 MainActor 唤起「生涯回顾」弹窗     - 唤起「训练结算庆祝」弹窗 |
|                                                                          |
+--------------------------------------------------------------------------+
```

- **替代方案对比**：
  - *每次启动同步重算所有历史*：随着用户训练次数增加（如 500 次），启动期开销虽可承受但纯属浪费算力。一次性回溯存根 + 增量判定是标准高性能模式。

### 4. 视觉与 UI 架构

- **卡片网格布局**：
  - `ProfileView` 顶部新增 `BadgeOverviewCard`，作为二级页入口；
  - 二级页 `BadgeWallView` 使用 SwiftUI `LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3))`；
- **材质与渲染**：
  - 继承工程已有的 `Theme.Color.surface`、`Theme.Color.accent`（`#E04328` 朱砂红）与纸感阴影 `paperShadow`；
  - 徽章卡片使用自适应暗钛金属配色与圆角微浮雕，统一 24 枚徽章视觉语义。

## Risks / Trade-offs

- **[Risk] 用户更替新设备或重装 App 导致本地 SwiftData 存根丢失**
  → **Mitigation**: 提供自愈兜底机制。当 `SyncEngine` 拉取历史 `Workout` 完成后，检查若 `BadgeGrant` 表为空但存在历史完成训练，自动后台补跑一次静默 Backfill，勋章瞬间恢复。
- **[Risk] 用户修改或删除了产生徽章的历史训练**
  → **Mitigation**: 荣誉一旦授予永不扣除（授予是永久历史事实），`BadgeGrant.workoutId` 变成可空关联。
- **[Risk] 体重倍数在体重动态波动下的基准判定**
  → **Mitigation**: 以当时完成训练时的当前有效体重为基准判定；快照记录 `snapshotMetric` 记录当时的达成倍数，保证历史严肃可查。

## Migration Plan

1. **SwiftData 模型升级**：在 `AppModelContainer.make()` 的 schema 中追加 `BadgeGrant.self`（全新独立实体，无需复杂轻量级迁移映射）。
2. **渐进式回溯**：新版启动时自动检测并初始化 `hasCompletedBadgeBackfill`。
3. **回滚策略**：纯本地新增实体，无后端破坏性改动。若回滚仅需移除客户端代码与容器注册。
