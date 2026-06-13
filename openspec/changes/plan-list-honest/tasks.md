## 1. featured 卡诚实化（`PlanViews.swift` · `PlanListView`）

- [x] 1.1 `featuredCard`：删除顶部 `WEEK {n} / {total}` pill（含 `total = max(8, n+4)` 推算）
- [x] 1.2 `featuredCard`：删除 `weekProgress(done:total:)` 调用与该私有方法本体（删后确认无其它引用）
- [x] 1.3 `featuredCard`：eyebrow 改为派生文案——计算该计划近 14 天内关联的最近一条已完成 `Workout`，有则「上次训练 · {startedAt 相对时间}」，无则「未开始」
- [x] 1.4 `featuredCard`：副标题从 `"\(items.count) 个动作 · 严肃推/拉/腿循环"` 改为 `"\(items.count) 个动作"`（去硬编码循环描述）
- [x] 1.5 `featuredCard`：3 列 meta 改为「累计 {关联已完成训练数} 次」/「总组数 {Σ suggestedSets}」/「预计 ≈{est} 分」；删除「剩余」「次/周」列。总组数/预计复用 PlanDetail 既有算法（`Σ suggestedSets`、`max(15, sets*130/60)`），可下沉为 `WorkoutPlan` 扩展或视图私有方法避免两处漂移

## 2. 隐藏「推荐模板」段（`PlanViews.swift` · `PlanListView`）

- [x] 2.1 `body`：在内置动作库数据就绪前，不渲染「推荐模板」eyebrow 与 `recommendedCard`（用单一开关常量/特性标记控制，便于数据就绪后一行打开）
- [x] 2.2 `recommendedCard`：保留定义但不再挂载，或随段一并移除（择一，注释说明数据就绪后恢复路径）

## 3. 验证

- [x] 3.1 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 编译通过（确认删除 `weekProgress` 后无悬空引用）—— **BUILD SUCCEEDED**
- [~] 3.2 模拟器实测三态：① 有近 14 天关联训练（eyebrow=上次训练、累计>0）② 新建未训练（eyebrow=未开始、累计=0）③ 无任何计划（进行中段折叠）—— **已做三态代码路径静态核对（见下）**；模拟器像素目检需登录 + 造三态数据，留本地联调时补
- [x] 3.3 确认全页无 `WEEK`、无周进度条、无「剩余/次每周」、无硬编码副标题、无「推荐模板」渲染（仅注释/开关/未挂载定义）
- [x] 3.4 `openspec validate plan-list-honest --strict` 通过
