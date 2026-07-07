## 1. iOS 端：计划处方模型与纯逻辑

- [x] 1.1 为普通动作计划项补齐热身/正式处方派生 helper，确保热身组只对 `singleExercise` 生效。
- [x] 1.2 调整计划总组数、动作行主摘要和处方预览，使主摘要只统计正式组，热身组单独弱化展示。
- [x] 1.3 调整 `PlanPrefill`，普通动作自适应历史预填使用包含热身的 completed 执行处方，递减组和超级组不生成热身组。
- [x] 1.4 调整 `PlanWriteback`，普通动作回写保留 completed 热身处方，但 `suggestedSets/suggestedWeightKg/suggestedReps` 只来自 completed 正式组。
- [x] 1.5 确保严格模式必填校验只约束正式训练处方，热身组不是必填条件。

## 2. iOS 端：计划编辑与展示

- [x] 2.1 在普通动作计划项编辑页加入默认折叠的「热身组」区域，支持添加、删除、编辑逐组重量/次数。
- [x] 2.2 确保新增普通动作默认无热身组，并继续默认生成 4 个正式组、10 次。
- [x] 2.3 在计划详情动作行展示弱化热身摘要，长摘要截断，不影响正式组主信息。
- [x] 2.4 从递减组和超级组计划编辑入口移除热身入口，并在保存时过滤这些类型的热身标记。

## 3. iOS 端：分享、Fork 与模板

- [x] 3.1 调整 Team 分享和 Fork 去重量逻辑，保留普通动作热身组序、热身标记和次数，清空所有热身重量。
- [x] 3.2 调整从完成训练保存为计划模板的逻辑，普通动作可保留 completed 热身处方，递减组和超级组不生成热身处方。
- [x] 3.3 确认计划 jsonb 编解码继续兼容旧 payload，缺失 `isWarmup` 时按正式组处理。

## 4. 后端 / 基础设施

- [x] 4.1 确认后端 `WorkoutPlan.items`、Team 分享版本 `items` 继续原样透传 jsonb，无需新增 migration、表或 API。
- [x] 4.2 确认同步仍走 `WorkoutPlan` 既有 LWW 与幂等写路径，无新增同步域。

## 5. iOS 端：测试与验证

- [x] 5.1 增加普通动作热身处方预填测试：严格模式和自适应模式均生成热身组 + 正式组。
- [x] 5.2 增加自适应回写测试：completed 热身组写回处方，但不影响正式组强度摘要。
- [x] 5.3 增加跳过热身测试：本次未完成热身时不自动删除计划既有热身处方。
- [x] 5.4 增加递减组/超级组排除测试：这些计划项不展示、不保存、不回写热身处方。
- [x] 5.5 增加 Team 分享/Fork 去重量测试：普通动作热身次数保留、重量清空。
- [x] 5.6 运行 `xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
