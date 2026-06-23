## 1. 基线与诊断

- [x] 1.1 增加性能 signpost：首页进入、Tab 切换回首页、动作库进入/筛选、计划详情进入、动作详情进入、结束训练 PR 检测、`syncAll` 完成后刷新
- [x] 1.2 增加 DEBUG-only 数据规模日志：`Workout` / `WorkoutExercise` / `WorkoutSet` 数量、finished/active/pending 数量
- [x] 1.3 记录当前库基线：439 workouts / 1936 exercises / 8188 sets 下各场景耗时
- [x] 1.4 准备压测数据集：1000 workouts、5000 workouts，每条约 4-6 动作、15-25 组

## 2. 首页止血

- [x] 2.1 将 `WorkoutListView` 从全量 `@Query<Workout>` 改为消费 `HomeWorkoutSnapshot`
- [x] 2.2 active session 使用 `fetchLimit = 1` 的窄查询（保留 `MainTabView` 全局胶囊语义）
- [x] 2.3 当前周统计只按 week bounds 查询/计算，不从全量 finished workouts 过滤
- [x] 2.4 最近训练只取最近 8 条，并生成 `WorkoutRowSummary` 纯值
- [x] 2.5 `prByWorkout` 改为一次性快照计算，禁止行渲染时反复全量扫描
- [x] 2.6 首页 CTA 的 active plan 判定只看近 14 天带 `planId` 的训练摘要，不传全量 workouts

## 3. 派生 projection

- [x] 3.1 新增 `WorkoutHistoryStore` / `WorkoutHistoryProjection`，由 App 根环境注入
- [x] 3.2 定义纯值快照：`HomeWorkoutSnapshot`、`WorkoutRowSummary`、`PRBadge`、`ExerciseHistorySnapshot`、`PlanHistoryLookup`、`ProfileWorkoutSnapshot`
- [x] 3.3 实现 `refresh(reason:)`：一次扫描原始记录构建所有基础 lookup
- [x] 3.4 实现变更防抖：训练完成/删除/同步 pull 后合并刷新，避免多次连续重建
- [x] 3.5 确保 projection 不参与同步、不作为冲突真相，必要时可清空重建

## 4. 动作库与动作详情

- [x] 4.1 `ExerciseLibraryContentView` 移除全量 workouts query，列表行 PR 从 `historyStore.exercisePRs` 读取
- [x] 4.2 `ExerciseDetailView` 按 exercise key 读取 `ExerciseHistorySnapshot`
- [x] 4.3 动作详情支持 timeframe 或至少限制图表点数量，避免全量点直接进 Swift Charts
- [x] 4.4 `PRStats.maxWeightByKey` / `latestPR` 保留为 projection 构建工具，不在视图 computed property 中直接调用全量 workouts

## 5. 计划详情与自适应预填

- [x] 5.1 新增 `PlanHistoryLookup`，一次构建 `latestByPlanItemId` / `latestByHistoryKey` / skipped 信息
- [x] 5.2 `PlanPrescriptionPreview.make` 改为查 lookup，避免每个 item filter/sort 全历史
- [x] 5.3 `PlanDetailView.planItemRow` 不再直接传 `finishedWorkouts`
- [x] 5.4 `start(from plan)` / `buildFromPlan()` 使用同一 lookup，保证“页面所见”和“开始训练落值”一致

## 6. Profile 与详情页

- [x] 6.1 `ProfileView` 的总训练数、最长连续天数改读 `ProfileWorkoutSnapshot`
- [x] 6.2 `WorkoutDetailView` 的 PR strip 优先读 projection 中的 workout PR 结果
- [x] 6.3 训练详情若 projection 缺失，做一次按 `startedAt < workout.startedAt` 的窄重算，不订阅全部 finished workouts

## 7. 启动与同步减负

- [x] 7.1 `ExerciseHistoryMerge.run` 增加一次性 UserDefaults 标记，完成后后续启动跳过全量 fetch
- [x] 7.2 `SyncEngine.syncWorkouts()` push 阶段只 fetch pending workouts
- [x] 7.3 pull upsert 阶段按 pulled ids 做 lookup，避免每个 dto 或每轮同步全量 fetch
- [x] 7.4 `syncAll` 完成后只触发一次 projection refresh

## 8. 验收

- [x] 8.1 当前库 439/1936/8188 下：首页首次可交互 < 200ms，Tab 切回首页 < 100ms
- [x] 8.2 1000 workouts 压测：首页 < 300ms，动作库筛选 < 150ms，计划详情 < 250ms
- [x] 8.3 5000 workouts 压测：首页主 UI 不阻塞；projection 可后台构建，完成后异步刷新
- [x] 8.4 验证统计口径不变：PR、周训练量、动作曲线、计划预填与优化前结果一致
- [x] 8.5 验证离线优先不变：训练完成先落本地，projection 刷新失败不影响保存与同步
- [x] 8.6 iOS `xcodebuild` 编译通过；关键纯函数/lookup 增加单测
