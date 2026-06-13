## Why

「计划」列表的 featured 卡（`PlanListView.featuredCard`）当前在展示一套 **MVP 数据模型并不支持的周期化语义**，且部分字段是硬编码假数据：

- `WEEK {n} / {total}`——`n` 是关联此计划的已完成训练次数（不是周），`total = max(8, n+4)` 是凭空构造的，暗示一个根本不存在的「8 周课表」。
- `剩余 = total − n`——因 `total` 随 `n` 增长，该值**永远 ≥4、永不归零**，周进度小条因此恒假。
- `次/周` 列固定写死 `3`，与任何真实数据无关。
- 副标题硬编码 `· 严肃推/拉/腿循环`，「练腿日」也会显示「推/拉/腿循环」。
- 对一个刚建好、尚未训练的新计划，整张卡会呈现 `WEEK 0/8 · 严肃推/拉/腿循环 · 剩余 8 · 次/周 3`，几乎全是假数据。

根因在规格层：`workout-tracking` 的「计划列表（PlanList）版式」需求本身就要求了 `WEEK {n}/{total}` pill、周进度条与「已完成/剩余/次每周」三列 meta。但项目 spec 明确写有「**MVP 不支持周计划或周期化结构**」（见「训练计划模板」需求）。二者直接矛盾。

同时「推荐模板」段是一张永远点不动的 `opacity 0.6` 占位卡（「PPL·6 周·数据采集中」），在内置动作库素材采集完成前对用户是纯噪声，显得产品未完成。

本次变更把 featured 卡**收敛为诚实的单次模板卡**：只展示可由本地 `Workout / WorkoutPlan` 记录重算的真实信号，并在数据就绪前隐藏「推荐模板」段。这是上架前的体验必修项，不引入任何新数据模型或周期化能力。

## What Changes

- **MODIFIED 规格**：`workout-tracking` 的「计划列表（PlanList）版式」需求去除一切周期化语义——删除 `WEEK {n}/{total}` pill、周进度小条、「剩余」「次/周」两列 meta、硬编码副标题，改为「真实信号可重算」的展示约束。
- featured 卡新版内容：
  - eyebrow：近 14 天有关联已完成训练 → 「上次训练 · {相对时间}」；从未训练 → 「未开始」。
  - 标题：计划名。
  - 副标题：「{动作数} 个动作」（部位统计依赖未采集的内置动作库，本阶段不做）。
  - 3 列 meta：「累计 {n} 次」/「总组数 {Σ suggestedSets}」/「预计 ≈{est} 分」，全部可重算。
- 「推荐模板」段在内置动作库数据采集完成前不渲染（连同段标题 eyebrow）。

## Capabilities

### New Capabilities
<!-- 无新增能力：仅收敛既有「计划列表版式」的展示约束。 -->

### Modified Capabilities
- `workout-tracking`: 「计划列表（PlanList）版式」需求去除周期化展示（WEEK pill / 周进度条 / 剩余 / 次每周 / 硬编码副标题），改为「featured 卡仅展示可由记录重算的真实信号」；新增「推荐模板段在数据就绪前隐藏」约束。保留两段式结构、纸感样式（白底 + accent 竖条 + paperShadow）与「进行中」判定复用逻辑。

## Impact

- **iOS 代码**：仅 `ios/DontLift/DontLift/Workout/PlanViews.swift`
  - `PlanListView.featuredCard`：去 `WEEK` pill / `weekProgress` 调用 / 「剩余」「次/周」meta / 硬编码副标题；eyebrow 改「上次训练/未开始」；meta 改「累计次数 / 总组数 / 预计分钟」。
  - `PlanListView.weekProgress(done:total:)`：删除（不再被引用）。
  - `PlanListView.recommendedCard` 与 body 中「推荐模板」段：在数据就绪前不渲染。
- **OpenSpec**：`openspec/specs/workout-tracking/spec.md` 经本 delta 更新。
- **不影响**：后端、同步协议、`WorkoutPlan`/`PlanItem` 数据模型（无字段增删）、PlanDetail/编辑/选择器、业务逻辑。纯展示层收敛。

## Non-goals

- **不做周期化能力**：不给 `WorkoutPlan` 加 `weeklyFrequency / cycleWeeks` 等字段，不做真实的「x/N 周」进度（那是新 feature，需改 spec + 数据模型 + 同步契约，本次明确排除）。
- **不做部位统计**：副标题不拼部位（依赖未采集的内置动作库），留到素材就绪后另议。
- **不动 PlanDetail/新建流程/排序/复制反馈等其他计划页问题**：本 change 只收敛列表展示的「不撒谎」必修项，其余体验项另开。
- **不引入新组件或第三方库**。
