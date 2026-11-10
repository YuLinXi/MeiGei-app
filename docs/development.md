# 开发与验证指南

验证范围与模拟器生命周期遵循 [AGENTS.md](../AGENTS.md)。本文提供按需使用的命令和架构注意事项；以下命令不表示每次开发都要全部执行。

## iOS 编译：无需启动模拟器

在仓库根目录运行：

```bash
xcodebuild -project ios/DontLift/DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

只需确认测试源码能编译时，将 action 换成 `build-for-testing`；主 scheme 包含单元测试和 UI 测试，`DontLiftTests` scheme 只包含单元/集成测试 target。`build-for-testing` 不执行用例，不能报告为测试通过。

SourceKit 的跨文件索引可能暂时报找不到类型，以构建结果为准。主 App 的 `.swift` 文件使用 `PBXFileSystemSynchronizedRootGroup` 自动纳入 target；widget extension 的共享文件仍需核对 Sources membership。

主 App 有 `ios/DontLift/DontLift-Info.plist`，与 `GENERATE_INFOPLIST_FILE=YES` 注入的设置合并。ATS 本地网络设置已在该文件中；调整时核对实际配置，不新建第二份 Info.plist 或开启任意公网 HTTP。

## iOS 定向测试：单个模拟器串行运行

先只读查询：

```bash
xcrun simctl list devices available
```

优先选择已启动且兼容的设备，将其 UDID 设置到 `DONTLIFT_SIMULATOR_ID`；如果没有，选一个现有设备启动一次。后续所有测试复用这个 UDID，不按设备名称反复选择或新建设备。

iPad 的全屏与窄窗口分别验收。窗口化模式下，设备已横放不代表 App 窗口也已横向；全屏横屏用例先确认实际窗口宽大于高，保留不满足前置条件的失败记录。横屏和多窗口的视觉证据使用 `XCUIScreen.main.screenshot()`，同时记录 App／窗口尺寸，避免 App 局部截图坐标裁切造成误判。系统窗口操作见 [Apple 窗口使用指南](https://support.apple.com/guide/ipad/work-with-multiple-windows-at-the-same-time-ipad08c9970c/ipados)。

例如，休息策略改动只运行对应测试类（先将变量值替换为实际 UDID）：

```bash
export DONTLIFT_SIMULATOR_ID='填写选定设备的 UDID'
xcodebuild test -project ios/DontLift/DontLift.xcodeproj -scheme DontLiftTests \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$DONTLIFT_SIMULATOR_ID" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:DontLiftTests/WorkoutRestPolicyTests
```

需要验证排序弹窗交互时，选择一个有相关行为断言的 UI 用例：

```bash
xcodebuild test -project ios/DontLift/DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$DONTLIFT_SIMULATOR_ID" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:DontLiftUITests/DontLiftUITests/testReorderSheetBlocksOtherAreas
```

需要多个相关类或方法时，在同一条命令添加多个 `-only-testing`，减少重复构建和启动。使用 XcodeBuildMCP 时也保持相同 UDID、筛选范围和串行参数，不在 CLI 验证通过后再用 MCP 重跑同一检查。

UI 测试复用固定的运行器 Bundle ID。每批测试结束、结果与日志已落盘且没有运行中任务后，及时卸载本批用完的临时 `DontLiftUITests-Runner`，避免测试图标堆积；保留主 App、日常训练库、模拟器设备及验证结果。排查旧测试包缓存时核对实际运行镜像，不通过持续新增运行器 Bundle ID 规避。

本项目标准运行器的清理命令如下。测试失败时也要在测试进程结束后执行；自动化脚本应保留原测试退出码和清理结果，不能因清理成功将失败报告为通过。

```bash
xcrun simctl uninstall "$DONTLIFT_SIMULATOR_ID" com.yulinxi.app.DontLiftUITests.xctrunner
```

2026-11-09 在本地 iOS17.4 长 UI 用例中抓到 `XCTAutomationSupport.runtime_issue_os_log_fault_callback` 在日志高流量隔离时调用 `strcmp` 空地址。该堆栈位于测试注入框架，定位结论及验证边界见[专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)；原始临时日志已按用户要求清理。当时只在临时 `xctestrun` 的 `UITargetAppEnvironmentVariables` 设置 `OS_ACTIVITY_MODE=disable`，已核对实际目标进程环境，再对原流程复验；不修改正式 App 配置或 Xcode 全局偏好，不以测试日志减少证明运行警告已清零。未来出现同类退出应先核对堆栈，不能凭“App 不在运行”直接套用此配置。

变更影响广泛、发布候选或明确要求全量回归时，才使用主 scheme 执行完整测试。测试可能启动或重启宿主 App，这是 XCTest 的运行机制；无需为此开关模拟器。完整测试结束也要核对实际执行、失败与跳过数量，尤其注意筛选未命中和依赖缺失导致的跳过。

## 现有测试能证明什么

- `DontLiftTests` 在 `project.pbxproj` 配置了 `TEST_HOST`，包含业务模型、持久化、同步等单元/集成测试。它们需要 App 宿主，但通常不操作 UI。
- SwiftData 关系图的计算用例使用 `WorkoutTestStore` 管理隔离内存数据；不要依赖裸模型在不同系统上的关系行为。保存失败和编辑保留用例直接控制 context，通过 `WorkoutSession.start` 建立已保存训练，再模拟未保存编辑；`processPendingChanges()` 在自动保存开启时可能写盘，不能作为“保存前”的证据。
- App 的明确保存使用 `LocalModelSave.save(context)`，界面缓存订阅 `LocalModelSave.didSave`；该同步函数沿用调用方context的执行器，仅在可靠保存后发布事件。框架自动保存保持原行为，数据库fixture的原始`context.save()`不能替代产品保存事件验证。
- `DontLiftUITests` 有训练结束、排序弹窗等实际交互断言；许多用例通过启动参数注入本地测试数据，不能自动证明登录、真实后端和跨设备同步的全链路。
- SwiftUI 合成控件的文本 AX 框可能与父 Button 相同，不能用框的长宽比证明文字已显示或保持单行；文字换行与裁切仍需核对实际渲染截图。
- `testExample` 仅启动 App；`DontLiftUITestsLaunchTests` 主要截图；`testLaunchPerformance` 和 `testColdRestoreTenTimes` 会反复启动 App。这些不是每次功能开发的默认验收，应按启动、性能或恢复场景选择。
- 真 Apple 登录、APNs 投递、Watch 展示、HealthKit 和签名相关能力需按受影响路径真机验收。`simctl push` 仅模拟客户端收到推送，不验证服务端到 APNs 的投递链路。

报告端到端结果时，列出实际入口、操作、断言及所用环境；使用测试数据、替身或跳过的外部依赖应说明。现有测试没有覆盖的流程应写明未验证，不用启动截图补作通过证据。

`scripts/ios-sim-dev.sh up` 是需要安装并展示 App 时的联调入口，会 boot 并打开 Simulator；不作为日常编译入口。它不是端到端测试脚本。

## 后端本地环境与验证

本机联调使用 Homebrew 的 PostgreSQL/JDK；使用仓库 `./gradlew`，不用全局 Gradle。以下命令在 `backend/` 下运行，按需选择：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

# 定向测试示例
./gradlew test --tests 'com.dontlift.workout.WorkoutPlanSyncServiceTest'

# 需要完整构建时执行；build 已包含 test，无需随后重复跑 test
./gradlew build
```

需要本地服务联调时，先检查是否已有实例。PostgreSQL 的本机启动命令为：

```bash
/opt/homebrew/opt/postgresql@16/bin/pg_ctl \
  -D /opt/homebrew/var/postgresql@16 -l /tmp/pg_dontlift.log start
```

在 `backend/` 下运行 `./gradlew bootRun`，启动时自动执行 Flyway；本机默认端口为 8001。需要 dev token 时参考 `backend/scripts/dev-start.sh`，仅本地启用 `APP_DEV_TOKEN=true` 后调用 `POST /auth/dev/token`。生产保持关闭。API 文档为 `/swagger-ui.html`，健康检查为 `/actuator/health`。

## 修改相关架构时核对

### 后端与同步

- 同步域使用 `sync/AbstractSyncService` 或 workout 聚合的专用实现，信封含 `serverId/localId/updatedAt/deletedAt/version`。push 按幂等键去重，pull 按 `since` 增量，冲突采用 LWW 并回传服务端值。
- workout 的 exercise/set 子树随聚合上传与替换，不增加独立同步信封。计划 items 使用稳定 itemId；JSON 字段契约以当前 DTO 和迁移为准。
- Team 通过 REST 管理共享状态，进页面拉取、APNs 通知更新；不要套用客户端权威同步模型。
- UUID 主外键使用 `common/type/UuidTypeHandler`；新增错误沿用 `AppException` 与 `GlobalExceptionHandler` 的 ProblemDetail 映射。
- 同步 SQL 的可空 `since` 使用 `CAST(#{since} AS timestamptz)`，避免 PostgreSQL 无法推断 null 参数类型。
- MyBatis-Plus 的 `updateById` 不写 `@TableLogic` 字段；墓碑走 mapper 的显式 `softDelete`，拉取包含墓碑，聚合删除同步处理子树。
- 调整依赖或校验链时保留 `mybatis-plus-jsqlparser`、UUID handler 注册和 SecurityConfig 的 `/error` 放行，分别核对解析、绑定及 400 错误返回。
- 新增 schema 前查看 `backend/src/main/resources/db/migration/` 的现有版本，使用新的迁移编号；不把历史 V1 baseline 当作当前全部 schema。

### iOS

- `AppModelContainer.make()` 显式设置 `cloudKitDatabase: .none`；本地编辑使用 `markDirty`/`markDeleted` 并保存，再由 `SyncEngine` 上传。新增实体沿用 `Syncable` 与现有同步状态。
- `SyncEngine` 每域先 push 后 pull，失败保留 pending 等待重试；更新水位和覆盖本地值时遵循现有 LWW 规则。线上 `WorkoutPlan.items` 与 Team `summary` 是 JSON 字符串，需要二次编解码，修改时同时检查服务端契约。
- `SessionStore` 管理登录态，JWT 放 Keychain。`APIClient.tokenProvider` 是 `@Sendable` 闭包，不能捕获 MainActor 隔离的 token。
- Team 的共享状态通过 `TeamService` 按需加载，不存入客户端权威的 SwiftData 同步实体。
- `RestActivityAttributes`/`EndRestIntent` 跨 App 与 widget 编译，类型与成员关系保持一致；App Intent 经 Darwin 通知回传。休息计时以墙钟 `endDate` 为准，检查后台/锁屏后的恢复与结束提醒。
- 历史曲线与 PR 按稳定动作标识归并、从训练记录重算，避免引入冗余持久化统计。
