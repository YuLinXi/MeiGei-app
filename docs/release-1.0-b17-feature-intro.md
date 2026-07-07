# v1.0-b17 发版功能介绍

> 适用版本：`1.0 (build 17)`
> 后端状态：本次无后端运行时代码和数据库迁移变更，无需重新部署；生产 health 已于 2026-07-07 22:32 CST 确认为 `UP`，Flyway 最新仍为 `V18 workout set is warmup success=true`。
> iOS 状态：TestFlight `1.0 (17)` 已发布并完成回归，2026-07-07 22:43 CST 由用户确认。
> 合并与 tag 状态：2026-07-07 22:45 CST 完成 `main` 合并，并创建 `v1.0-b17` tag。

## 一句话摘要

本次 build 17 让训练计划可以正式保存热身处方，并优化计划详情、动作卡片、休息提示、键盘滚动和分享展示的细节体验。

## 面向测试用户的更新说明

- 计划动作现在可以配置热身组，开始训练时会自动带出热身重量/次数。
- 计划训练完成后，正式组会继续用于下次递增和总结，热身组会保留为热身处方，不会误算成正式训练强度。
- 编辑动作时，热身行、正式组输入框和删除按钮的对齐更稳定；键盘弹出时表单会保持可滚动可见。
- 计划详情里的动作卡片更简洁，只保留动作名称、计划组数和次数，减少重复信息。
- Team 计划详情继续用超级组、递减组图标区分训练结构；普通动作和递减组中的动作可点进动作库详情。
- 训练中休息提示更稳：跳过前面的组、完成超级组轮次、回到未完成组时，下一组推荐更符合实际训练顺序。
- 动作库搜索/输入时减少键盘造成的页面跳动。
- 训练分享海报和 kcal 估算做了细节修正，展示更紧凑，超级组强度估算不再被过度放大。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 17`，App、widget、测试 target 已同步。
- `WorkoutPlan` 的普通动作处方支持区分热身组和正式组，旧数据缺少热身标记时默认按正式组处理。
- `AdaptivePlan` 的预填和回写逻辑现在分别处理热身与正式组：热身只更新热身处方，正式组继续驱动摘要、递增和下次预填。
- `PlanHistoryLookup` 不再把只有热身组的历史记录当作可用正式组来源，避免下次计划被热身数据覆盖。
- Team 计划分享会保留热身次数并清空重量，继续符合共享计划不泄露个人重量的规则。
- Team 计划详情的卡片信息收敛为动作名、组数、次数，并补齐普通/递减/超级组的结构图标和详情跳转。
- `WorkoutRestPolicy` 集中处理下一组推荐、计划休息秒数和已开始休息的延续逻辑。
- `WorkoutCalorieEstimator` 调整超级组密度加成，避免仅因超级组结构就强制归为高强度。
- 本次无后端生产代码和 Flyway 迁移；后端仅补充 Team 计划分享相关测试。
- OpenSpec 本次涉及 `add-plan-warmup-prescriptions`，并继续校验 `add-workout-calorie-estimates`。

## 兼容性说明

- 后端已停留在 build 16 部署的 `V18`，build 17 不需要新增后端迁移或接口发布。
- 未升级 iOS 的用户不会看到计划热身处方、Team 计划详情精简和新的计划详情跳转体验。
- 新版客户端读取旧计划时，会把缺失 `isWarmup` 的处方按正式组处理，旧计划可继续开始训练。
- Team 共享计划仍会清空重量字段；热身次数和结构信息会保留，方便队友按同样结构训练。
- TestFlight `1.0 (17)` 已发布并完成回归，本次发布合并到 `main` 后创建 `v1.0-b17` tag。

## 已完成验证

- iOS build 号已递增到 `1.0 (17)`，App、widget、测试 target 同步。
- OpenSpec 校验通过：`openspec validate add-plan-warmup-prescriptions --type change --strict`。
- OpenSpec 校验通过：`openspec validate add-workout-calorie-estimates --type change --strict`。
- 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- iOS simulator test 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO test`，单元测试 `157` 个通过，UI 测试 `6` 个通过，`0` failure。
- `git diff --check` 通过。
- 生产 health 已确认：`curl -fsS https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`。
- 生产 dev token 已确认关闭：`POST https://dontlift.peipadada.com/auth/dev/token` 返回 `404`。
- 生产 Flyway 已确认最新为 `18  workout set is warmup  success=true`，并包含 `17  workout units  success=true`。
- TestFlight `1.0 (17)` 已发布并完成回归，2026-07-07 22:43 CST 由用户确认。
- `feature/v1.0-b17` 已合并回 `main`，并创建 `v1.0-b17` tag。

## TestFlight 回归重点

- Apple 登录、冷启动同步、Team 页加载和训练同步正常。
- 计划编辑中给普通动作添加热身组，键盘弹出时热身行和正式组输入框保持可见、可滚动。
- 热身行左侧 `热1` / `热2` 与重量、次数输入区域垂直居中；删除按钮与同一行输入框居中对齐。
- 从计划开始训练时，热身组和正式组都按计划处方带出。
- 完成训练并回写计划后，热身处方保留，正式组摘要和下次预填不被热身数据覆盖。
- 只有热身组的历史记录不应影响下一次正式组预填。
- Team 计划详情动作卡片只展示动作名、计划组数和次数。
- Team 计划详情中普通组、递减组、超级组图标区分清楚；可跳转的动作进入对应动作库详情。
- 超级组在 Team 计划详情中优先保持整体结构，可从成员动作进入动作库详情，不应误导为单个普通组。
- 递减组、超级组、热身组在计划详情、Team 分享、Fork 后仍保持结构与次数，重量字段被清空。
- 训练中跳过部分组后，休息完成后的下一组推荐符合当前训练顺序。
- 动作库搜索或编辑动作时键盘不造成异常页面跳动。
- 分享海报 kcal、时长、训练量、组数和动作列表保持可读。
