## 1. 后端：计划整体备注列与透传

- [x] 1.1 新增迁移 `V21__workout_plan_note.sql`（`ALTER TABLE workout_plan ADD COLUMN note text`），执行 `./gradlew test` 确认 Flyway 校验通过
- [x] 1.2 `WorkoutPlan` 实体与同步 DTO/信封增加可选 `note` 透传；补充含 note 与无 note（旧信封）两类 push/pull 测试并全部通过
- [x] 1.3 补充 Team 计划分享服务端测试：分享版本保留整体备注且递归剥离重量时保留计划项 `note` 键，测试通过

## 2. iOS 计划模型与兼容

- [x] 2.1 `PlanItem` JSON 增加可选 `note`（普通动作/递减组项直挂、超级组项挂其嵌套结构），添加新旧 JSON round-trip 兼容测试并通过
- [x] 2.2 `WorkoutPlan` 增加可选整体备注字段并纳入同步信封编解码；旧计划缺字段按无备注处理的测试通过

## 3. iOS 计划 UI

- [x] 3.1 计划编辑支持整体备注与动作备注的创建/修改/清空（trim、空存 nil、≤200 字），保存后详情可见
- [x] 3.2 计划详情展示整体备注与有备注动作项的摘要，不增加折叠卡冗余信息；Simulator 人工确认展示与既有版式协调（并入 6.3 人工验证）

## 4. iOS 开始训练带入与训练整体备注

- [x] 4.1 `buildFromPlan`（个人计划与 Team 分享快照路径）将整体备注预填 `Workout.note`、动作备注预填 `WorkoutExercise.note`/超级组备注；添加覆盖显式备注、无备注、三类单元的测试并通过
- [x] 4.2 训练会话页新增整体备注查看/编辑入口，已完成详情只读展示（对齐动作备注交互）；Simulator 人工验证编辑、清空、长度限制与历史展示（并入 6.3 人工验证）
- [x] 4.3 确认 `PlanWriteback` 不含 note：严格/自适应完成训练后计划备注不变、回写回执不展示备注变化，测试通过

## 5. iOS 计划转换与 Team 路径

- [x] 5.1 复制计划保留整体备注与动作备注；保存为模板将训练整体备注与动作备注一次性写入模板，测试通过
- [x] 5.2 Team 无重量快照重建保留 `note` 键；分享版本直接开始与 Fork 后均带入备注且相互独立，测试通过
- [x] 5.3 回归确认 Team checkin 快照、feed 与训练海报不含任何备注

## 6. 验证与验收

- [x] 6.1 运行计划、自适应回写、模板转换与 Team 分享相关 iOS 定向测试，全部通过
- [x] 6.2 iPhone 17 Pro Simulator 无签名 Debug build 成功；后端 `./gradlew test` 全部通过
- [ ] 6.3 Simulator 人工验证 spec 全部场景：编辑/清空/超长、带入训练、训练中编辑不回写、模板与复制转换、Team 分享/Fork/直接开始
- [x] 6.4 运行 `openspec validate add-plan-notes --strict` 与 `git diff --check`，确认改动聚焦
