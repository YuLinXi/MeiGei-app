## 范围

仅训练相关 3 张主屏 + 1 个 Sheet 模态。其它 tab 不在本 change 范围。

## 决策记录

### D1：先做哪三屏

候选：训练首页 / 训练进行中 / 动作详情 / 历史 / 计划详情。

**选择：训练首页 + 训练进行中 + 动作详情**。理由：
- 这三屏构成「打开 App → 开始训练 → 看 PR」的完整闭环，演示链路最完整。
- 训练历史与计划详情在数据维度上同源（都依赖训练记录聚合），等首页周聚合代码沉淀下来再做，复用率高。
- Live Activity 已在生产路径上，三屏覆盖了它的触发点。

### D2：周聚合实时算 vs 入库

设计稿三宫格需要"本周总组数/总次数/平均时长"。两种实现：

| 方案 | 优点 | 缺点 |
|---|---|---|
| SwiftData 即时 query | 零迁移；CLAUDE.md 铁律"能重算就重算" | 大数据量下首页加载慢 |
| 入库 `weekly_summary` 表 | 启动快 | 多一张表 + 跨日刷新逻辑 |

**选择：即时 query**。MVP 用户 1 周训练 ≤7 次，每次 ≤ 6 动作 ≤ 24 组，总记录 < 200 条，SwiftData fetch + reduce 走主线程都 < 5ms。等用户半年数据沉淀再考虑物化。

### D3：1RM 估算公式

Epley vs Brzycki vs Lombardi：

- **Epley**：`1RM = w × (1 + r/30)`，业界用得最广，r=1 时刚好等于 w。
- **Brzycki**：`1RM = w × 36 / (37 - r)`，r >12 时偏差大。
- **Lombardi**：`w × r^0.10`，对超高次数样本表现好但低 r 偏小。

**选择：Epley**。简单、对 3-10 次区间最准（健身房常态），与 Strong / Hevy 这类同类 App 对齐，用户切换感知差小。

公式落地：取过去 90 天，按 `historyKey`（builtinCode ?? customId ?? name）归并每组数据 → 每组算 estimated 1RM → 取每日峰值 → 折线展示。

### D4：浮动圆环 FAB 的渲染选择

设计稿是右下 64×64 圆形 + 进度环 + 数字 + cyan 发光。SwiftUI 实现路径：

**方案 A：`Circle().trim(from:to:).stroke()` + ZStack 数字**
- 优点：纯 SwiftUI，跟 RestTimer 的现有 `Timer.publish` 自然绑定。
- 缺点：发光要靠 shadow 叠加。

**方案 B：Canvas 自绘**
- 优点：性能最好，60fps 稳。
- 缺点：动态阴影/blur 在 Canvas 里不好做。

**选择：A**。每秒 tick 一次 shape 重绘对 SwiftUI 完全无压力，且 Theme 的 `.neonGlow(.cyan, .sm)` 可直接复用。

FAB 不悬浮在 tab bar 之上——因为训练进行中页设计稿中底部 tab bar 仍然显示。FAB `bottom = 90pt`（在 tab bar 74pt 之上留 16pt gap）。

### D5：训练进行中页的 Sheet 还是 Modal

休息计时展开态是「全屏遮罩 + 居中弹窗」（设计稿 02b）。SwiftUI 选项：

- `.sheet(isPresented:)` → 默认从底部滑入，与设计稿"中心放大"不符。
- `.fullScreenCover(isPresented:)` → 全屏，过重。
- 自绘 ZStack overlay → 控制力最强。

**选择：ZStack overlay**。`RestTimerSheet` 是一个普通 View，由 `WorkoutSessionView` 用 `if isRestExpanded { ... }` 条件渲染，配合 `.transition(.scale.combined(with: .opacity))` 实现中心放大动画。

### D6：占位策略一致性

设计稿用 `28.4t`、`14`、`82'` 这种具体数字让画面饱满。但 CLAUDE.md 已警告"动作要点 / 1500 食材未采集"。两难：

- 全部走真实数据 → 新用户首次打开训练首页全是 `—`，演示效果差。
- 用假数据兜底 → 用户产生不信任。

**选择：真实数据 + Empty State 设计**。
- 周训练量 0 时 hero 不显示 `0.0 t`，而是显示「准备好了吗？」+ CTA "开始第 1 次训练"。
- 三宫格 0 时显示 `—`，不显示 `0`。
- PR 卡无 PR 时整张卡片隐藏，不留位置。
- 1RM 曲线点数 < 3 时显示「数据不足 · 至少需要 3 次记录」占位。

## Day-1 铁律适用性

本 change **不新增数据模型**，不触及同步/幂等/软删/UUID v7。读取走 SwiftData 现有 `Workout` / `WorkoutExercise` / `WorkoutSet` 模型。Day-1 铁律 N/A。

## 失败模式

| 场景 | 表现 | 处理 |
|---|---|---|
| `WorkoutWeeklyStats` 计算 throw | 训练首页 hero 显示 `—` | 不弹窗，记 OSLog |
| `OneRepMaxChart` 数据为空 | 显示「数据不足」占位 | — |
| Live Activity 启动失败 | 浮动圆环 FAB 仍按本地 Timer 运行 | 已有 fallback，不动 |
| JetBrains Mono 字体未注册 | 自动 fallback `.monospaced` | 已在 design-system change 处理 |

## 验收口径

「设计稿与实现的差异 ≤ 5%」由眼睛判定，不做像素级 diff。重点对比项：

1. 颜色（accent cyan / magenta、bg、surface）
2. 字体（display 大数字、mono 等宽数字）
3. 关键发光阴影（CTA、PR 卡、FAB）
4. 间距（22pt 水平内边距、44pt 热区）
