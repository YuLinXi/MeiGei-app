# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

Spend time on thinking; you do not need to use the commentary channel to report progress to me.

## 语言规范

- 始终使用**简体中文**与用户交流、回答问题。
- 所有**文档**（README、设计文档、注释说明等）使用简体中文撰写。
- 所有**代码注释**使用简体中文撰写。
- **保留英语专业术语**：技术名词、框架名、API 名、代码标识符（类名/方法名/变量名）等保持英文原形，不强行翻译。例如 `Spring Boot`、`SwiftData`、`Live Activity`、`last-write-wins`、`JWT` 等照常使用英文。

## 项目概览

别练了（Don't Lift，代号 DontLift）是一款 iOS 原生健身 App，定位「严肃健身工具」（认真训练 + 小圈子社交）。仓库含两个工程：

- `backend/` — Java 21 + Spring Boot 3.3 + MyBatis-Plus + PostgreSQL 16 + Flyway 的 REST 后端。
- `ios/DontLift/` — SwiftUI + SwiftData 客户端（最低 iOS 17.4），含主 App、`DontLiftWidgets` Live Activity extension、测试 target。

两大模块：训练记录（最核心）、Team 共享。开发以 OpenSpec change `openspec/changes/meigei-mvp/` 为权威规格（proposal/design/data-model/tasks + 三份 spec），改动行为前应先读对应 spec。

> **饮食模块已移除**（2026-06-01）：原「严肃饮食」记录（内置食材库 / 自定义食材 / 饮食日记 / 每日营养目标）现阶段不做，相关代码、数据库表、OpenSpec 规格已整体清理，勿再按旧文档恢复。

## 常用命令

### 后端（在 `backend/` 下）

本机用 Homebrew 直装的 PostgreSQL/JDK，**非 docker-compose**（仓库虽有 docker-compose.yml/Dockerfile，本机联调不走它）。

```bash
# JDK 21（gradlew 需指向 .../Home）
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

# 启动 PostgreSQL 16（库=dontlift，角色=dontlift/dontlift，匹配 application.yml 默认）
/opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /tmp/pg_dontlift.log start

# 启动后端（Flyway 自动跑迁移，端口 8001）
./gradlew bootRun

# 构建 / 测试
./gradlew build
./gradlew test
```

- **必须用 `./gradlew`**：wrapper 锁 Gradle 8.10.2，Spring Boot 3.3 插件不支持 Gradle 9.x（勿用 brew 的全局 gradle）。
- 本机联调免 Apple 登录：以 `APP_DEV_TOKEN=true` 启动后 `POST /auth/dev/token` 造测试用户/JWT（默认关闭，生产勿开）。
- API 文档：`/swagger-ui.html`；健康检查：`/actuator/health`。

### iOS（在 `ios/DontLift/` 下）

```bash
# 编译验证（关签名绕过 entitlements 的 portal 配置）
xcodebuild -project DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

- 工程用 Xcode 26 的 `PBXFileSystemSynchronizedRootGroup`：往 `ios/DontLift/DontLift/` 目录新增 `.swift` 文件即自动纳入 target，**无需手改 pbxproj**（仅 build settings/entitlements/新 target 才需改 pbxproj）。
- 写完新文件后编辑器 SourceKit 可能瞬时误报「Cannot find type / No such module」（跨文件索引竞态），**以 `xcodebuild` 结果为准**。
- `GENERATE_INFOPLIST_FILE=YES`，无独立 Info.plist；HealthKit 用途串、`NSSupportsLiveActivities` 等经 `INFOPLIST_KEY_*` build setting 注入。

## 发版输出约定

每次准备或完成 TestFlight/生产发版时，除发版 checklist 外，必须同步输出一份「发版功能介绍」，文件建议命名为 `docs/release-<version>-b<build>-feature-intro.md`。

发版功能介绍必须使用简体中文，面向测试用户和发布负责人都能直接阅读，避免只贴 commit log。内容至少包含：

- 版本与状态：`MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`、后端部署状态、iOS 上传状态。
- 一句话摘要：说明本次发版解决的核心问题。
- 面向测试用户的更新说明：只汇总上一个已发布版本与当前候选版本最终状态之间的用户可感知差异，用用户语言说明新增、优化和修复点。
- 内部技术变更：列出关键后端迁移、API/同步/数据清理/客户端行为变化。
- 兼容性说明：说明后端先发是否影响未升级 iOS 用户，哪些能力需要新版客户端。
- 已完成验证：后端构建、iOS 构建/测试、生产 health、Flyway、dev token 等结果。
- TestFlight 回归重点：列出本次最需要人工真机验证的路径。

生成“面向测试用户的更新说明”时必须遵守以下规则：

1. 以最近一个已经完成 TestFlight/生产发布并打 tag 的版本为基线，对比该 tag 与当前候选版本的最终行为；不得把分支起点、单个 commit 或本版本早期实现当作发布基线。
2. 每一条只描述测试用户安装候选版本后能看到或感受到的最终结果。同一功能在本版本内经历多次调整时，只保留合并后的最终功能说明。
3. 不得记录本版本开发期间的中间实现、反复调整、临时方案、已撤回内容、commit 过程或“先出现后修复”的过程性问题。
4. 只有上一个已发布版本中真实存在、并在当前候选版本中得到解决的问题，才能在测试用户更新说明中写成“修复”。仅存在于当前未发布版本开发过程中的问题不得对测试用户宣称为修复。
5. API、数据库迁移、字段重命名、兼容别名和内部重构等内容只写入“内部技术变更”，除非它们直接形成可感知的最终功能。

发版最终回复用户时，要同时给出 checklist 和功能介绍文档链接；若后端已部署但 TestFlight 未上传，要明确说明 iOS 仍待用户上传。只有 TestFlight 上传并确认可用后，才建议打对应 `vX.Y-bN` tag。

## 后端架构

按领域分包于 `com.dontlift.*`：`auth`（Apple 登录校验 + 签发 JWT）、`account`、`workout`、`team`、`sync`、`push`、`idempotency`、`security`、`config`、`common`。

**两类数据流，务必区分：**

1. **同步域（离线优先，客户端权威 + LWW）** —— `sync/AbstractSyncService` 是通用骨架。每个同步实体带 `serverId/localId/updatedAt/deletedAt/version`，push 先按幂等键去重、pull 按 `since` 水位增量；冲突用 last-write-wins + 回传服务端值。涉及实体：`custom_exercise` / `workout_plan`（items 存 jsonb，每项有稳定 itemId），以及 `workout` 聚合根（子树 `workout_exercise`/`workout_set` 无独立信封，随聚合整树上传、服务端按 workoutId 全量替换，ON DELETE CASCADE）。
2. **服务端权威域（REST，非同步）** —— `team`（建团/邀请码/Fork 计划模板/训练即打卡 fan-out/emoji 表情），共享状态由服务端裁决，客户端进页面拉取，实时靠 APNs 推送（不用 WebSocket）。

**跨领域约定（Day-1 铁律，新增实体必须遵守）：**

- 身份三层 `user + identity_provider + provider_user_id`，绝不拿 Apple ID 当业务主键。
- 所有写接口带幂等键（`idempotency` 模块）。
- UUID v7 由应用层生成（`common/id/Uuid7`，PG16 无原生 uuidv7）。
- 错误统一经 `common/web/AppException` + `GlobalExceptionHandler` 转 ProblemDetail（404/403/409/400）。
- 统计（PR/历史曲线）能重算就重算，少存冗余。

**已知坑（compact 后勿重踩）：**

- MyBatis-Plus 3.5.6+ 需额外引 `mybatis-plus-jsqlparser`（已在 build.gradle.kts）。
- UUID 主键/外键需 `common/type/UuidTypeHandler`（已在 application.yml 注册 `type-handlers-package`）。
- 同步 SQL 里 `since` 为 null：必须写 `CAST(#{since} AS timestamptz)`，否则 PG 报无法确定参数类型。
- `@Valid` 校验失败会 forward 到 `/error`，SecurityConfig 已把 `/error` permitAll（否则 403 而非 400）。
- **软删墓碑**：MyBatis-Plus `updateById` 不写 `@TableLogic` 字段，墓碑推不上去。新增同步实体须给 mapper 加显式 `@Update softDelete(...)`，push 时 `deletedAt != null` 走 softDelete 而非 updateById（聚合根另需连带删子树）。

数据库：单一 baseline 迁移 `db/migration/V1__baseline.sql`（10 张表），新增 schema 加 `V2__*.sql` 等。

## iOS 架构

源码在 `ios/DontLift/DontLift/`，按领域分目录：`App`、`Auth`、`Networking`、`Sync`、`Push`、`Models`、`Persistence`、`Workout`、`Team`。

- **SwiftData 仅本地，显式关闭 CloudKit**（`AppModelContainer.make()` 用 `cloudKitDatabase: .none`），云同步全自写。
- **同步信封 `Syncable` 协议**：`localId`=客户端预生成 UUID v7；`serverId` 为 nil 表示未确认；`SyncStatus`（pendingCreate/Update/Delete/synced/conflicted）+ markDirty/markDeleted。
- **`SyncEngine`（@MainActor）**：每域先 push（幂等键=域+localId:updatedAt 的 SHA256）再按 since pull；LWW 比 `updatedAt`，仅当服务端较新才覆盖本地；push 失败保持 pending 即重试队列；水位线存 UserDefaults。`WorkoutPlan.items` 与 Team 的 `summary` 在线上契约是 **jsonb 序列化成的 JSON 字符串**，客户端需二次编解码。
- **离线优先**：本地编辑一律 `markDirty + save` 即时落盘，下次 `syncAll` 上传；网络层 `APIClient.tokenProvider` 是 `@Sendable` 闭包，直接读 Keychain（不能捕获 MainActor 隔离的 token）。
- **JWT 存 Keychain**（不入 SwiftData）；`SessionStore`（@MainActor @Observable）管登录态。
- **Team 数据不进 SwiftData**（服务端权威），`TeamService` 按需 REST 拉取、视图 @State 持有。
- **Live Activity**：独立 target `DontLiftWidgetsExtension`（传统 target，Sources phase 显式列文件）；`RestActivityAttributes`/`EndRestIntent` 同时编进 app 与 widget 两端（ActivityKit 按类型名跨进程匹配）。倒计时靠 `Text(timerInterval:)` 自走，无需推送；「提前结束」经 App Intent → Darwin 通知回传主 App。
- **休息计时**以墙钟 `endDate` 为基准（后台/锁屏不中断），结束提醒用本地通知 `UNTimeIntervalNotificationTrigger`。
- 历史曲线/PR 用 Swift Charts、按 `historyKey`（builtinCode??customId??name）归并，全部重算不持久化。

## 待办与软阻塞

- **数据工程未完**：内置动作（150-200+ 部位高亮图，当前仅 ~26 占位）尚未采集；6.x 真机联调/验收未做。
- **软阻塞**（需用户侧账号/密钥，不影响写码与编译）：Apple 私钥(.p8)/Service ID/APNs 凭据、Fly.io/Cloudflare 账号。无凭据时登录走 JWKS 仍可联调，APNs 自动降级 no-op。
- 真 Apple 登录与 APNs 投递需真机 + 签名 + Apple 凭据；DEBUG 连 localhost:8001 需在 Info.plist 配 ATS `NSAllowsLocalNetworking`（当前无独立 Info.plist，留到联调时建）。
