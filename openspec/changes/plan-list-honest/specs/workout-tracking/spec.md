## MODIFIED Requirements

### Requirement: 计划列表（PlanList）版式

`PlanListView` SHALL 渲染「进行中 / 我的计划」两段；「推荐模板」段在内置动作库数据采集完成前 MUST NOT 渲染（连同其段标题 eyebrow）。进行中段 MUST 显示至多 1 张 featured plan-card：白底 `Theme.Color.surface` + 1px `border` + 左侧 `accent` 竖条 + `paperShadow(.sm)`，MUST NOT 使用青色渐变或辉光。

featured 卡展示的所有数据 MUST 可由本地 `Workout / WorkoutPlan` 记录重算，MUST NOT 展示周计划、课表周数或周期化进度等 MVP 数据模型不支持的语义（参见「训练计划模板」需求：MVP 不支持周计划或周期化结构）。featured 卡 SHALL 包含：

- **eyebrow**：若该计划近 14 天内存在关联的已完成训练，显示「上次训练 · {相对时间}」；若该计划从未有关联的已完成训练，显示「未开始」。MUST NOT 显示「WEEK {n} / {total}」pill。
- **标题**：计划名。
- **副标题**：「{动作数} 个动作」。MUST NOT 硬编码固定循环描述（如「严肃推/拉/腿循环」）。
- **3 列 meta**：「累计 {n} 次」（关联此计划的已完成训练数）/「总组数 {Σ suggestedSets}」/「预计 ≈{est} 分」。MUST NOT 包含「剩余」「次/周」等无真实数据来源的列。
- featured 卡 MUST NOT 渲染周进度小条。

「进行中」计划的判定 MUST 复用与首页「开始训练」CTA 一致的同一份逻辑（近 14 天内有关联该计划的已完成训练，否则取最近更新的计划），不得另写一套。

#### Scenario: 存在进行中计划且已训练过
- **WHEN** 用户近 14 天有关联计划「严肃推拉腿」的已完成训练，进入「计划」页
- **THEN** 「进行中」段显示该计划的 featured 卡，eyebrow 为「上次训练 · {相对时间}」，meta「累计」为该计划关联的已完成训练次数，且 MUST NOT 出现「WEEK」「剩余」「次/周」或周进度条

#### Scenario: 新建未训练的计划成为进行中
- **WHEN** 用户刚新建计划「练胸」、从未由它发起过训练，进入「计划」页（无近 14 天关联训练，判定退回最近更新的计划）
- **THEN** featured 卡 eyebrow 显示「未开始」，meta「累计」为 `0` 次，「总组数 / 预计」按当前 items 计算，全卡不出现任何周期化或假数据字段

#### Scenario: 推荐模板段在数据未就绪时隐藏
- **WHEN** 内置动作库数据尚未采集完成，用户进入「计划」页
- **THEN** 页面只渲染「进行中 / 我的计划」两段，MUST NOT 渲染「推荐模板」段标题或占位卡

#### Scenario: 无任何计划
- **WHEN** 用户没有任何计划
- **THEN** 「进行中」段折叠（不渲染 eyebrow 与卡），「我的计划」段显示空状态卡引导新建
