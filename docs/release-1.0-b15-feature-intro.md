# v1.0-b15 发版功能介绍

> 适用版本：`1.0 (build 15)`
> 后端状态：已于 2026-07-03 00:18 CST 部署，生产 Flyway 最新为 `V16 workout set segments success=true`。
> iOS 状态：TestFlight `1.0 (15)` 已由用户确认发布完成。

## 一句话摘要

本次 build 15 打通递减组记录闭环：训练录入、统计、计划模板、Team 分享和同步都能理解递减组，并修复登录后 Team 请求偶发 403 的问题。

## 面向测试用户的更新说明

- 训练中可直接添加「递减组」，一组内记录多组重量和次数，不再需要拆成多条普通组。
- 递减组支持展开、折叠、添加内部组、删除内部组，也可以和普通组互相转换。
- 递减组内部重量不强制递减，真实训练里递增、递减或混合输入都可以照实记录。
- 训练统计、PR、训练详情和分享海报会按递减组内部有效组计算容量和最高重量，但逻辑组数仍按父级递减组计 1 组。
- 新建训练模板和编辑计划动作时，可以添加递减组处方；从计划开始训练时会按处方生成递减组。
- Team 分享计划会保留递减组结构和次数，同时清空重量，避免把个人训练重量暴露给队友。
- Team 页登录后加载稳定性提升，修复开发/冷启动路径下请求未带登录态导致的 403。
- 计划分组下没有计划时不再显示空分组文案，展开后保持留白。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 15`，App、widget、测试 target 已同步。
- 后端新增 `V16__workout_set_segments.sql`，为 `workout_set` 增加 `segments jsonb NOT NULL DEFAULT '[]'` 和数组约束。
- 后端 Workout 聚合同步已支持 `segments`，旧 payload 缺失时按空数组兼容。
- iOS `WorkoutSet` 增加递减组内部结构，统计派生统一走递减组展开口径。
- iOS `PlanItem` 增加 `setPrescriptions`，支持普通组和递减组处方，并保留 `suggested*` 摘要兼容旧计划。
- 保存训练为计划、自适应回写、严格计划预填、计划详情预览和 Team 计划 Fork 均保留递减组结构。
- Team 计划分享脱敏扩展到嵌套递减组重量字段。
- `SessionStore` 登录后等待 `APIClient` token provider 安装完成，并用登录 token 作为 Keychain 读取兜底，修复 `/me`、sync、`/teams` 请求 `auth=N` 的竞态。
- `docs/manual-regression-add-drop-set-recording.md` 已改为完整验收清单，可供 XcodeBuildMCP 模拟器自动化执行。
- OpenSpec `add-drop-set-recording` 已同步补充训练模板新建支持递减组，并将 UI 文案统一为“组/内部组”。

## 兼容性说明

- 后端已完成 V16 迁移，build 15 的递减组同步和跨设备展示可用。
- V16 对旧客户端兼容：旧客户端不发送 `segments` 时服务端使用默认空数组，普通组和旧训练继续正常同步。
- 未升级 iOS 用户不会看到递减组入口；升级到 build 15 后才能记录、编辑和预填递减组。
- TestFlight 已完成发布；递减组的后端同步、Team 打卡和跨设备验证可在 build 15 上做最终真机回归。

## 已完成验证

- iOS 版本号已递增到 `1.0 (15)`，App、widget、测试 target 同步。
- OpenSpec 校验通过：`openspec validate add-drop-set-recording --strict`。
- add-drop-set-recording 自动化验收已完成：iOS simulator 测试 `111 passed, 0 failed, 0 skipped`。
- 后端测试已通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew test`。
- 版本号变更后的 iOS simulator test 通过：XcodeBuildMCP `test_sim`，`111 passed, 0 failed, 0 skipped`，诊断无 warnings/errors。
- `git diff --check` 通过。
- 模拟器复测 Team 登录链路：`GET /teams auth=Y`，返回 `200`，Team 页正常显示测试 Team。
- Swift 用户可见字符串扫描未命中旧文案「添加一段」「第 N 段重量」「第 N 段次数」。
- 后端生产部署完成：`./backend/deploy/release-update.sh` 已完成 DB 备份、rsync、远程 Docker build、容器重启、health 和 Flyway 校验。
- 生产 health 已确认：`curl -fsS https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`。
- 生产 Flyway 已确认：`16  workout set segments  success=true`。
- TestFlight 真机回归细节仍需在实际测试记录中补充。

## TestFlight 回归重点

- 普通训练中添加递减组：不自动弹键盘，首个内部组继承上一正式组重量/次数，第二个内部组为空。
- 递减组内部「添加」只新增内部组，不自动选中输入框；删除后编号重新排序。
- 递减组折叠/展开状态、左侧区分线、内部组缩进和输入框尺寸符合当前设计。
- 普通组可改为递减组，递减组改回普通组前有确认，并保留第一个有效内部组。
- 热身组不直接提供「改为递减组」。
- 自定义数字键盘在递减组内部按重量 -> 次数 -> 下一内部组重量 -> 下一内部组次数移动；键盘「加一组」仍新增父级普通组。
- 完成递减组后，完成组数按 1 组计算，训练量和次数按所有有效内部组展开计算。
- 训练详情、PR、历史曲线和分享海报能正确展示递减组。
- 新建训练模板和计划详情编辑中可以添加、编辑、删除递减组处方；从计划开始训练能按处方生成递减组。
- 保存训练为计划模板后，递减组结构被写入计划处方。
- Team 分享计划和 Fork 后保留递减组结构与次数，重量被清空。
- 后端部署完成后，验证递减组训练同步、Team 打卡列表和打卡详情。
- 计划分组下没有计划时，展开后不显示空分组文案。
