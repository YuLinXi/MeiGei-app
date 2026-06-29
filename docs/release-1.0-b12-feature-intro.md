# v1.0-b12 发版功能介绍

> 适用版本：`1.0 (build 12)`
> 后端状态：需要部署。本次包含 `workout_set` 休息秒数字段和 Flyway `V14 workout set rest seconds`；当前生产最新仍为 `V13`。
> iOS 状态：准备上传 TestFlight。

## 一句话摘要

本次 build 12 聚焦训练体验收口：持久化组间休息秒数、优化休息提醒声音策略、降低回前台同步卡顿、修正 Team 计划详情点击热区，并补齐若干动作库标准名和别名。

## 面向测试用户的更新说明

- 休息结束提醒更稳定：声音开关统一控制 App 内音效和后台/锁屏通知声音，前台仍由 App 播放提示音，后台和锁屏继续交给系统通知。
- 休息提醒保留系统“即时通知”级别：这是 iOS 对 Time Sensitive 通知的系统标签，能提高提醒到达优先级。
- 休息记录更完整：每组完成后的预计休息秒数和真实休息秒数可以随训练同步保存，跨设备和历史展示更可靠。
- 回到前台更顺：App 不再每次从后台切回就立刻全量同步，会延迟并按条件触发，减少同步中操作界面的卡顿。
- Team 计划列表更好点：点击计划卡片右侧空白区域也能进入计划详情，不再出现点了没反应的感觉。
- 动作库命名更准确：`哑铃臂屈伸后踢` 统一显示为 `哑铃臂屈伸`，同时新增 `单臂哑铃臂屈伸`。
- 肩部热身更具体：新增 `招财猫` 和 `弹力带肩外旋`，并把 `肩部热身` 标准化为 `肩部动态热身`。
- 历史名称继续兼容：旧名称如 `肩关节外旋训练`、`招财猫式肩外旋`、`哑铃三头后踢` 仍会搜索或解析到对应标准动作。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 12`，App、widget、测试 target 已同步。
- 后端新增 Flyway 迁移 `V14__workout_set_rest_seconds.sql`，为 `workout_set` 增加 `planned_rest_seconds` 和 `actual_rest_seconds` 以及非负约束。
- 后端 `WorkoutSet` 同步实体增加 `plannedRestSeconds` / `actualRestSeconds`，用于 workout 聚合 push/pull 保留组间休息信息。
- 休息提醒策略保持 Time Sensitive entitlement，不申请 Critical Alerts，不新增音频素材。
- `RestTimerController` 保留 `rest_complete.caf`，在休息开始时预加载音频，并按 `soundEnabled` 重排本地通知声音。
- `RootView` 回前台同步改为门控调度：短时间切回不触发，存在非当前训练 pending、Team 待补发或后台超过阈值时才延迟同步。
- `SyncEngine` 增加轻量 pending 检查，避免为了判断是否需要同步而执行完整 push/pull。
- Team 分享计划卡片详情入口补齐满宽 hit-test 区域，只影响进入详情热区，不改变底部「开始训练 / 复制」操作。
- 动作库预置 manifest 新增三头和肩外旋相关动作，补充别名映射，并增加 taxonomy 测试覆盖。
- 本次无新增后端 API 路径，但有 workout 同步载荷字段和数据库 schema 变更。

## 兼容性说明

- 必须先部署后端并完成 `V14` 迁移，再上传或放量 TestFlight build 12，确保新版客户端同步的休息秒数字段可被服务端持久化。
- 未升级 iOS 用户不受影响；动作库命名和别名解析属于新版客户端本地能力。
- 既有训练历史不会被重写，旧动作名称通过 alias 继续归并到标准动作。
- 旧训练记录的休息秒数字段保持 `NULL`，新版客户端按 nil 兼容。
- Time Sensitive 通知继续显示系统“即时通知”标签；若未来要去掉该标签，只能降级为普通通知，同时会降低专注模式等场景下的投递优先级。
- 回前台自动同步仍保留兜底能力，只是不再无条件立即执行。

## 已完成验证

- 生产后端健康检查通过：`curl https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`；生产 Flyway 当前仍为 `V13`，`V14` 待部署。
- 后端构建通过：`JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home ./gradlew build`。
- OpenSpec 严格校验通过：`openspec validate --all --strict`，13 passed / 0 failed。
- 动作库 manifest 校验通过：`node scripts/exercise-library-v1.mjs validate`。
- iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- iOS simulator test 通过：同 destination 下 `xcodebuild ... test`，xcresult summary 为 `Passed`，`totalTestCount = 100`，`failedTests = 0`，`skippedTests = 0`。
- 测试结果包：`/Users/yumengyuan/Library/Developer/Xcode/DerivedData/DontLift-guqqjazfhpbnohehmkrhrctumwsk/Logs/Test/Test-DontLift-2026.06.29_17-17-58-+0800.xcresult`。

## TestFlight 回归重点

- 先部署后端，确认 `flyway_schema_history` 最新版本为 `14 workout set rest seconds success=true`。
- 从 build 11 升级到 build 12 后，登录、同步、训练首页、计划、Team 首页可正常进入。
- 完成组间休息后，预计休息和实际休息秒数能在本地保存；同步后重新登录/换设备拉取不丢失。
- 休息声音开：前台到点只响一次，后台/锁屏通知播放 `rest_complete.caf`。
- 休息声音关：前台不播放 App 内音效，后台/锁屏通知静音但仍展示。
- 后台切回前台时，短时间切回不应立刻出现全量同步卡顿；有待同步内容时延迟同步仍能完成。
- Team 计划列表点击卡片标题、右侧箭头和右侧空白区域，都能进入计划详情。
- Team 计划卡片底部「开始训练」和「复制」仍只执行对应操作，不误触详情。
- 动作搜索 `哑铃臂屈伸后踢`、`哑铃三头后踢` 可找到 `哑铃臂屈伸`。
- 动作搜索 `肩关节外旋训练` 可找到 `弹力带肩外旋`。
- 动作搜索 `招财猫式肩外旋` 可找到 `招财猫`。
- 使用包含旧动作名的计划开始训练时，显示和历史归并保持标准动作名称。
