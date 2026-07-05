# v1.0-b16 发版功能介绍

> 适用版本：`1.0 (build 16)`
> 后端状态：已部署。2026-07-05 23:13 CST 通过 `./backend/deploy/release-update.sh` 部署到生产，Flyway 最新为 `V18 workout set is warmup success=true`，部署前 DB 备份为 `./backups/dontlift_2026-07-05_231315.sql.gz`。
> iOS 状态：已准备上传 TestFlight，尚未上传。

## 一句话摘要

本次 build 16 把训练记录升级为「普通组 / 递减组 / 超级组」三类训练单元，并在训练详情与分享海报中加入本地 kcal 估算。

## 面向测试用户的更新说明

- 新增「超级组」：可以把两个动作组成一组，按轮连续完成，适合胸背、推拉或孤立动作组合训练。
- 训练页底部入口更清晰：主按钮继续添加普通动作，结构菜单用于添加递减组或超级组。
- 递减组成为独立训练单元，不再藏在普通组菜单里；普通组、递减组、超级组创建后不互相转换，训练结构更稳定。
- 热身标记独立出来：普通组、递减组、超级组都可以按各自语义标记热身，热身不参与统计。
- 递减组统计口径更新：有效内部组按实际段数计入组数，训练量、次数和 PR 继续按有效重量/次数展开。
- 训练详情、Team 打卡详情和分享海报会保留超级组与递减组结构，不再把结构训练误读成普通动作列表。
- 分享海报新增 `约 xxx kcal`，便于分享时表达本次训练消耗；该数值是本地估算，不是 HealthKit 能量数据。
- 「我的 > 训练偏好」新增消耗估算开关和估算体重设置；未设置体重时不展示 kcal。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 16`，App、widget、测试 target 已同步。
- 后端新增 `V17__workout_units.sql`：为 `workout` 增加 `units jsonb`，保存一级训练单元结构。
- 后端新增 `V18__workout_set_is_warmup.sql`：为 `workout_set` 增加 `is_warmup`，并把旧 `set_type='warmup'` 迁移为 `set_type='working' + is_warmup=true`。
- 后端 Workout 聚合同步兼容旧 warmup raw 值，旧客户端上传 `setType=warmup` 时服务端转为新 `isWarmup` 字段。
- iOS `Workout` 引入普通组、递减组、超级组三类训练单元；旧训练缺少 `units` 时按动作顺序派生普通训练单元。
- iOS `WorkoutPlan` 与 Team 分享计划支持超级组和递减组结构，Fork/分享继续清空重量字段，保留结构和次数。
- iOS 统计、PR、历史曲线、周统计、训练详情、Team 摘要和海报统一按新训练单元展开计算。
- 新增 `WorkoutCalorieEstimator` 与本地 `WorkoutCaloriePreferences`，kcal 只由本地训练时长、估算体重和粗强度派生。
- kcal 不写入 `Workout` 同步实体、不上传后端、不进入 Team checkin、不写入 HealthKit active energy。
- OpenSpec 本次涉及 `add-superset-training-units`、`reframe-drop-set-as-training-unit`、`add-workout-calorie-estimates`。

## 兼容性说明

- 后端已部署到 `V18`，build 16 的训练单元同步、热身标记和超级组/递减组跨设备展示已具备服务端支持。
- V17/V18 对旧客户端兼容：旧 workout 没有 `units` 时按普通动作列表展示；旧 warmup raw 值由服务端和新客户端兼容迁移。
- 未升级 iOS 用户不会看到超级组、新训练单元入口和 kcal 估算；旧客户端继续可记录普通训练，但无法表达 build 16 的新结构。
- build 16 的 kcal 估算是设备本地辅助信息，不影响旧客户端、后端接口或 HealthKit。
- TestFlight 未上传前不要创建 `v1.0-b16` tag；后端部署完成且 TestFlight 可安装后再打 tag。

## 已完成验证

- iOS build 号已递增到 `1.0 (16)`，App、widget、测试 target 同步。
- OpenSpec 校验通过：`openspec validate add-workout-calorie-estimates --type change --strict`。
- 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- iOS simulator test 通过：XcodeBuildMCP `test_sim CODE_SIGNING_ALLOWED=NO`，`145 passed, 0 failed, 0 skipped`，本轮无 warnings/errors。
- iOS simulator build 通过：XcodeBuildMCP `build_sim CODE_SIGNING_ALLOWED=NO`，本轮无 warnings/errors。
- `git diff --check` 通过。
- 后端生产部署完成：2026-07-05 23:13 CST 运行 `./backend/deploy/release-update.sh` 成功，部署前 DB 备份为 `./backups/dontlift_2026-07-05_231315.sql.gz`。
- 生产 health 已确认：`curl -fsS https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`。
- 生产 dev token 已确认关闭：`POST https://dontlift.peipadada.com/auth/dev/token` 返回 `404`。
- 生产 Flyway 已确认最新为 `18  workout set is warmup  success=true`，并包含 `17  workout units  success=true`。

## TestFlight 回归重点

- 确认生产 Flyway 仍为 `V18 workout set is warmup success=true`。
- Apple 登录、冷启动同步、Team 页加载和训练同步正常。
- 训练中底部「添加动作」只添加普通动作；结构菜单可添加递减组和超级组。
- 普通组、递减组、超级组三类训练单元创建后不可互相转换；删除后重新添加目标类型。
- 超级组创建两个动作、统一轮数；按轮录入重量/次数，完成一轮时两个成员组一起完成。
- 超级组轮后休息、下一组提示、加减轮数、删除超级组正常。
- 递减组独立训练单元录入、添加/删除内部组、整体完成、整体热身和组后休息正常。
- 热身组不计入组数、训练量、次数、PR；超级组热身按整轮生效，递减组热身按整个递减组生效。
- 训练详情、历史日历、PR、周统计和分享海报展示超级组/递减组结构正确。
- 训练详情在设置估算体重后显示 `约 xxx kcal · <强度>`；关闭消耗估算或未设置体重时隐藏。
- 分享海报展示 `约 xxx kcal`，并保持时长、训练量、组数、动作列表可读。
- 计划详情可创建/编辑超级组和递减组；从计划开始训练能生成对应训练单元。
- 保存训练为计划后保留超级组/递减组结构。
- Team 分享计划与 Fork 保留结构和次数，重量字段仍被清空。
- Team 打卡详情能展示超级组与递减组结构；Team 摘要不展示 kcal。
