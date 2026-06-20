# Tasks: 训练计划严格 / 自适应模式

## 1. 前置核实（实现前必做）
- [x] 1.1 复查所有 `countsForStats` 调用点：均为统计/容量聚合用途，加 `completed` 语义正确；纯「热身/正式」展示走 `setType`（displaySortedSets/徽章），无误伤。单点改定义即可
- [x] 1.2 确认「未打勾组清理」采静默丢弃
- [x] 1.3 Flyway 下一可用版本号 = V5（V4 已被 `workout-set-type-warmup` 占用）

## 2. 数据模型（iOS）
- [x] 2.1 `Models/WorkoutPlan.swift`：加 `modeRaw`（默认 `"adaptive"`）+ `WorkoutPlanMode { strict, adaptive }` 枚举 + `mode` 计算属性（兜底 `adaptive`）+ init 参数
- [x] 2.2 `Models/Workout.swift`：`WorkoutExercise` 加 `planItemId: UUID?`（+ init 参数）
- [x] 2.3 `Models/Workout.swift`：`WorkoutSet.countsForStats` 收紧为 `setType != .warmup && completed`
- [x] 2.4 同步 DTO：`WorkoutPlanDTO` 加 `mode`、`WorkoutExerciseDTO` 加 `planItemId`；SyncEngine 四个映射点（dto/applyServer/tree/replaceChildren）接入，兜底 adaptive/working

## 3. 数据模型（后端）
- [x] 3.1 `V5__plan_adaptive_mode.sql`：`workout_plan` 加 `mode text NOT NULL DEFAULT 'adaptive'`；`workout_exercise` 加 `plan_item_id uuid`
- [x] 3.2 实体加字段（`WorkoutPlan.mode` / `WorkoutExercise.planItemId`）
- [x] 3.3 确认走同步：mapper 用 MyBatis-Plus 默认 insert/updateById 自动带新字段；plan 级 mode 走同步域 LWW、plan_item_id 随聚合整树替换

## 4. 开始训练（落值 + 携带来源 id）
- [x] 4.1 `buildFromPlan()` 把 `item.itemId` 写入 `WorkoutExercise.planItemId`
- [x] 4.2 严格模式：`PlanPrefill.sets` 按 `suggestedSets` 建组并整组落值 `suggestedReps/suggestedWeightKg`
- [x] 4.3 自适应模式：`PlanPrefill` 历史优先（`lastCompletedSets` 按 `historyKey` 取上次 completed 逐组）→ 回退计划 `suggested*` → 留空，落值且 `completed=false`
- [x] 4.4 临时新增动作 `planItemId = nil`（buildFromPlan 不带 itemId 的路径默认 nil）

## 5. 完成训练（回写 + 清理）
- [x] 5.1 `finish()` 调 `cleanupIncompleteSets()`：删除未 `completed` 组、移除变空动作
- [x] 5.2 `PlanWriteback.merge`：upsert（`planItemId`/`historyKey` 去重）、组数 `max`、重量次数取顶组代表值、跳过保留、新增 append
- [x] 5.3 `applyAdaptiveWriteback()` 仅 `mode == .adaptive` 触发；经 `WorkoutPlan` `markDirty` 走 LWW
- [x] 5.4 回写前快照 `plan.items`，存入 `PlanWritebackCenter.Receipt.snapshot` 供撤销

## 6. UI
- [x] 6.1 必填校验：严格模式由 `PlanItemEditorView` stepper（组数/次数恒有值）天然满足；`PlanModeSheet` 切严格时校验缺失项
- [x] 6.2 计划详情：三点菜单「计划模式 · 严格/自适应」标识 + `PlanModeSheet` 规则说明入口
- [x] 6.3 `PlanModeSheet.select`：切严格校验缺组数/次数并提示补齐
- [x] 6.4 `PlanWritebackSheet`（根层 MainTabView 呈现）：diff 回执（更新/新增/已保留）+「撤销此次更新」
- [x] 6.5 创建计划默认 `adaptive`（`WorkoutPlan` init 默认值；PlanEditorView 未覆盖）
- [x] 6.6 新建计划页加入严格 / 自适应模式选择与说明，保存时写入所选模式
- [x] 6.7 计划列表 featured 卡与计划详情 statRow 移除预计时长，原位置展示当前计划模式
- [x] 6.8 计划中添加动作默认写入 `suggestedSets=4`、`suggestedReps=10`；`PlanItemEditorView` 新项默认 4×10；自适应无历史 fallback 4 组

## 7. Fork / Team 联动
- [x] 7.1 本地 `duplicate()` + 后端 `TeamPlanService.fork`：复制 动作+组数+次数，清空 `suggestedWeightKg`，新计划默认 `adaptive`

## 8. 验证
- [x] 8.1 `AdaptivePlanTests`：回写合并器各分支（更新/新增/保留/去重/组数 max/顶组/deload 下降）
- [x] 8.2 `AdaptivePlanTests`：`countsForStats` 收紧（未打勾/热身组不计）+ PlanPrefill 历史/回退/忽略未完成
- [~] 8.3a `AdaptivePlanTests`：已补自适应无历史 fallback 4 组、默认 4×10 常量测试；执行阻塞：`DontLift` scheme 未配置 test action，直接 build `DontLiftTests` 被 `MuscleMap_MuscleMap.bundle` / `MuscleMap` module 解析挡住
- [x] 8.3 后端 `./gradlew compileJava` ✅ BUILD SUCCESSFUL；iOS `xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build` ✅ BUILD SUCCEEDED
- [ ] 8.4 端到端（环境阻塞：需 iOS runtime + 真机多设备）：自适应训练→回执→撤销；严格训练→计划不变；多设备 LWW
