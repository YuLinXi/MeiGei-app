# 1.1 build 7 发版检查清单

## 版本、基线与候选范围

- 准备日期：2026-11-10（上海时区）。最终状态：**build 7 的设备 Archive 和分发签名通过，但实际上传被 Apple 必需合同门禁以 403 拒绝，未成功提交 TestFlight。按流程不复用失败上传号，后续改用 [build 8](release-1.1-b8-checklist.md)。**
- 版本：`MARKETING_VERSION=1.1`，`CURRENT_PROJECT_VERSION=7`，主 App、widget、单元测试与 UI 测试的 Debug／Release 共 8 处配置一致。
- 用户已确认 build 6 被占用，不能复用。上传前独立核对 App Store Connect 的构建及全部状态上传列表，未见 build 7；实际上传仍因必需合同未完成而失败，不能把失败表述为 TestFlight 可安装。
- 最近已完成发布且有 tag 的基线：`v1.1-b5`，指向 `ea6d1c0fc05e70c3227a76202d7223e1062919c1`。发布及用户验收依据见 [build 5 发布记录](release-1.1-b5-checklist.md)。build 6 目前只有占用信息，不据此改作已发布基线。
- 候选分支：沿用 `feature/v1.1-b6`。业务源码以 `b9333e5cce801d9f88e12bc0810c823cb6e9ef38` 为准；版本及三份发布文档已提交为 `df70ed8b7200508cbda104f24fe71b1c7e14f90b` 并推送。后续仅回填发布事实，不改变已验证业务源码。
- 开始时尚未推送的 `65329ab`、`140a1c2`、`b272f6c`、`b9333e5` 已随候选一起推送，远端候选由 `c075f64` 更新至 `df70ed8`。远端 `main=b6b85b3`，尚无 `v1.1-b6`／`v1.1-b7` tag。
- 已跟踪文件在本轮开始时无未提交改动；既有未跟踪 `.codex/hooks.json` 保留，排除在发布候选之外，不自动暂存。
- [功能介绍与 TestFlight 测试内容](release-1.1-b7-feature-intro.md) · [可直接发送的用户公告](release-1.1-b7-user-announcement.md)

## 本次最终差异

1. 自己的已完成历史训练可从首页／历史日历详情另存为独立个人计划，保留本次实际完成内容、备注和休息安排，不修改原训练或来源计划。
2. 增强训练、计划、自定义动作和资料的保存失败恢复；画像与同步结果可识别、可重试；保护上传期间的本地编辑与删除意图，减少重复同步造成的记录关系异常。
3. 适配系统大字号、文字对比度、操作触达、计划原生输入和键盘布局，完善动作库索引及徽章等核心页面。
4. 优化继续／丢弃／取消训练、四类排序的取消和可靠提交、浮动训练入口避让，以及训练结束后的计划更新、PR 与徽章反馈衔接。
5. 优化大量历史记录同步与读取，区分个人／Team 页面的加载、失败和真实空态，明确 Team 默认分享、取消与撤回的边界。

未把仅修改规格的多身份登录等未来能力列入更新，也未将同一功能开发期间发现的问题逐项包装成 build 5 缺陷。动作库条目、正式动作图与 manifest 相对基线无变化，本次无需重做动作图发布／覆盖校验。饮食模块保持移除。

## 本地发布门禁与证据

- [x] 锁定已发布基线，分别核对已提交差异、工作树与未跟踪文件；真实远端引用已只读核对。
- [x] 用户确认 build 6 已占用，8 处工程配置递增至 build 7，营销版本保持 1.1。
- [x] `git diff --check v1.1-b5...HEAD` 通过。
- [x] JDK 21／仓库 Gradle wrapper 的 `./gradlew build` 成功。7 个任务均为 `UP-TO-DATE`；Gradle 复用当前输入对应的既有结果，测试报告为 95 项、0 失败、0 错误、0 跳过，**本轮未重新执行这 95 项测试**。日志：`/tmp/dontlift-release-b7-backend-20261110.log`。
- [x] 本次有差异的 15 个 active change 均通过 `openspec validate <change> --strict`；主规格 15/15 通过。`add-dynamic-workout-poster-backgrounds`、`add-plan-warmup-prescriptions`、`reframe-drop-set-as-training-unit` 另有归档时找不到旧 Requirement 标题的 INFO，不等于校验失败，也不代表可直接归档。本轮不执行规格归档。完整输出：`/tmp/dontlift-release-b7-openspec-20261110.json`。
- [x] 最终 build 7 的通用 iOS Simulator Release 主 App／widget 编译通过，产物均为 1.1／7，均包含 arm64 与 x86_64。未启动模拟器，未执行签名 Archive。日志：`/tmp/dontlift-release-b7-ios-release-20261110.log`；产物检查：`/tmp/dontlift-release-b7-ios-artifacts-20261110.json`。
- [x] 静态核对 App／widget 的 App Group 一致，App 配置包含 Apple Sign-In 与 Push entitlement。此项不验证分发签名或 provisioning profile，仍须 Archive 时检查。
- [x] 复用与候选业务实现对应的既有单元／持久化及隔离 UI 证据，具体边界见下文。
- [x] 本轮新增文档、内部文件链接、标题锚点及最终工作树的 `git diff --check` 通过。

本轮完整源码 Release 编译产生 58 条 warning 输出（含双架构重复），包括 Swift 并发隔离和协议 existential 写法；0 个编译错误。版本递增后的增量复核没有重新编译全部源码，其零 warning 不能当作源码零警告。完整日志：`/tmp/dontlift-release-b7-ios-source-release-20261110.log`。未与 build 5 做逐条 warning 差分，不声称零新增 warning。

### 复用的行为验证及限制

依据 [UI／UE 专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md#验证结论) 与相关 change 的 tasks；以下历史测试未重跑。继续执行阶段另复用一个现存模拟器做正常进程交互，见后文，没有新增设备或运行时。

- 保存与取消边界：iOS 17.4、26.5 的完整单元测试各 412 个方法／496 次运行通过，失败及跳过均为 0；后续备注布局与测试等待调整未改变该保存实现，沿用专项记录的复用边界。
- 历史另存：此前 39 项转换／持久化测试及 4 项首页、日历、来源失效、完成页兼容 UI 用例通过，0 失败、0 跳过，见 [历史另存任务与验证记录](../openspec/changes/save-history-workout-as-personal-plan/tasks.md#验证记录2026-11-07)。后续共享保存实现的回归范围同时以专项记录为准。
- 计划输入、大字号、排序取消／重试、训练冲突、加载状态、浮层与收尾路径使用已执行的定向交互结果；后续最大字号计划新建、基础信息、独立备注 3 条 UI 通过。
- 批量同步子树复用、80 轮数据与落盘断言及隔离 UI 交互已有结果，仍保留过最长调度间隔异常，不据此宣称全 App 帧率、能耗或真机性能达标。
- 活动休息已有“目标 310 秒、剩余 244 秒时结束训练，完成后与重开仍保留 310 秒”的隔离落盘验证，见 [活动休息验收](ui-ux-release-readiness-plan-2026-11-07.md#活动休息验收)。
- 旧批次大字号备注自动化失败与测试框架异常按原记录保留，正常进程操作通过不把旧批次改成全绿。原 `/tmp` 测试包、`xcresult` 和截图已按用户要求清理；当前可访问证据是仓库内的验证总结，不能把旧路径当作仍可打开的附件。
- 以上不代表真实 Apple 登录、真实后端、多设备同步、APNs、HealthKit、Live Activity、widget 或真机验收通过。Release 模拟器编译也不等于这些行为通过。

## 后端与线上静态页面发布判断

**本次 iOS 功能无需依赖新的后端应用服务或数据库迁移；两张法律静态页面已更新并通过公网正文核对。**

- `backend/src/main/` 的差异只有 `DevAuthController` 与 `application.yml` 的本地导入账号登录支持，受 `app.dev.token-enabled=true` 条件控制，默认关闭；新增 `APP_DEV_USER_ID` 不改变生产登录契约。
- 训练／计划同步 DTO、API、生产服务逻辑与 Flyway 迁移文件相对基线未变。历史另存继续使用既有 `WorkoutPlan.items`，批量同步调整在客户端；无需为了这些功能重启生产应用或共享数据库。
- `backend/deploy/shared-infra/edge/site/dontlift/{privacy,terms}/index.html` 已修订为新成员默认开启分享、包括每组记录以及关闭后不自动撤回历史的说明。
- 生产 Caddy 的 `/srv/site` 实际挂载源已只读确认是 `/opt/stacks/edge/site`。`release-update.sh` 同步的是 `/opt/DontLift-app/backend` 并只重建应用，**不会自动更新这处实际提供服务的静态目录**。

发布前的 2026-11-10 10:19（上海时区）生产只读检查：

| 检查 | 结果 | 发布含义 |
| --- | --- | --- |
| `/actuator/health` | 连续 3 次 HTTP 200／`UP` | 当前服务健康 |
| Flyway 最新成功记录 | V22，`workout body weight snapshot`，`success=true` | 本次无新迁移 |
| GET `/auth/dev/token` | 404 | 未发现开放的开发 token 入口；本轮未调用 POST 造 token |
| 未登录 GET `/teams` | 401 | 未登录认证入口行为正常，不代表已登录 Team 全链路通过 |
| `/privacy`、`/terms` | HTTP 200，但仍为旧分享说明 | **正文门禁未通过，不能因 200 勾选完成** |

只读 HTTP 记录：`/tmp/dontlift-release-b7-production-20261110.json`。Flyway 为只读 SQL 查询，没有部署、修改生产配置或数据库。

### 线上静态页面发布记录

- [x] 候选冻结、提交并推送；发布脚本再次确认远端候选与 `df70ed8` 一致，两个源文件字节与该提交一致。
- [x] 发布前备份线上 privacy／terms 两个文件；备份目录为 `/opt/stacks/edge/backups/dontlift-legal-b7-20261110-104124`，两个 `*.before.html` 与原线上文件 `cmp` 一致。
- [x] 仅把两个候选 `index.html` 发布到 `/opt/stacks/edge/site/dontlift/privacy/index.html` 与 `/opt/stacks/edge/site/dontlift/terms/index.html`。共享 Caddy 配置、证书、其他站点和数据库未改，三个容器的启动时间及重启计数前后一致。
- [x] 2026-11-10 10:41:47（上海时区）公网复核通过，两个独立 URL 均 HTTP 200，正文逐字节与提交源文件一致，已包含默认开启、每组记录和不自动撤回历史的说明。
- [x] App 内关于页实际打开隐私政策与独立服务条款，正文标题和域名正确；App Store Connect 已保存的隐私政策 URL 为 `https://dontlift.peipadada.com/privacy`。登录页复用既有按钮可达 UI 证据并核对相同 URL／SafariView 引用，本轮未登出日常账号重复打开登录页，不把这项当作真实 Apple 登录回归。

发布后再次确认：health 连续三次 HTTP 200／UP，Flyway V22 `success=true`，GET `/auth/dev/token` 为 404，未登录 GET `/teams` 为 401。应用服务、Caddy 和 PostgreSQL 均未重启，本次没有应用服务部署或数据库迁移。

| 文件 | 公网及发布源 SHA-256 |
| --- | --- |
| privacy | `99657586fda5efaa05ae13a9321c172bc6c4231b41724aef11b1ca3c93d7d1b9` |
| terms | `32322990048b65817f929bfc8c8171167a8c4773a6133ee2c448673b2d2624c2` |

日志及完整备份校验和：`/tmp/dontlift-release-b7-legal-deploy-20261110.log`、`/tmp/dontlift-release-b7-legal-deploy-20261110.json`。通过重新定位到现存后端终端执行，未起停本地后端。首次执行因备份父目录不存在，在替换任何线上文件前停止；补齐目录后再执行成功，首次失败记录另存为 `legal-deploy-attempt1` 日志与 JSON。

若执行阶段决定同时让应用容器与候选后端源码对齐，先确认候选推送和数据库备份，只用 `backend/deploy/release-update.sh`，预期 Flyway 仍为 V22；另行完成 health、开发入口、启动日志与兼容核对。该应用部署不能代替上述法律静态页面发布。

## Archive、TestFlight 与真机回归

建议顺序：完成本地准备 → 核对 build 7 可用并冻结／推送候选 → 发布并复核法律页面 → 解决真实边缘返回门禁 → 签名 Archive／上传 → 等待 `VALID` → 真机主路径验收 → 合并与 tag。

- [x] 上传前核对 App Store Connect 构建和上传列表，未见 build 7；build 6 按用户已占用的信息继续避开。
- [x] 当前模拟器的正常进程 HID 返回通过，用户追加确认手动边缘返回“核对通过”。不扩大为最低系统、所有导航路径或真机验收；可读性任务 4.7 与计划手势任务 3.4 的其他历史待验范围不自动勾选。
- [x] 用 Xcode 标准 `xcodebuild archive`、`DontLift`／`generic/platform=iOS` 完成 Release arm64 Archive；主 App／widget 均为 1.1／7，同属 D566UZ8QG4，签名与 App Group 核对通过。
- [ ] 上传成功：**未通过。** 已在 Organizer 执行 `Distribute App -> Custom -> App Store Connect -> Upload`，保留 build 7、不启用仅内部测试，分发重签成功后上传返回 ContentDelivery 403：`You do not have required contracts to perform an operation`，错误 ID `26280201-50c3-400a-a813-491ce43b8cd6`。后续使用 build 8，不重复提交 build 7。
- [ ] 等待 App Store Connect 对应 build 为 `VALID` 且 TestFlight 可安装。上传或 Archive 成功不等于此项完成。
- [ ] 填写 [TestFlight 测试内容](release-1.1-b7-feature-intro.md#testflight测试内容文案)，法律链接在 App Store Connect 中也必须正确。

2026-11-10 继续执行阶段：复用 iPhone 17 Pro／iOS 26.5（`7E664C03-5566-451F-B0E3-30204B2DCF05`），Debug 编译及安装通过，使用 `-dev-auto-login -uitest-plan-readability` 的独立 `WorkoutUITests.store`，正常进程 PID 59684，不启动真实同步。首次详情及展开动作、纵向滚动后，HID 边缘手势均实际返回计划列表；桌面拖动工具结果不同，随后用户已明确确认手动核对通过。最低系统 17.4 运行时此前已移除，本轮未重新安装或扩建设备矩阵，不扩大用户确认的覆盖范围。

正常进程操作记录：`/tmp/dontlift-release-b7-runtime-20261110.json`。安装候选后数据容器路径发生系统重定位；按 Bundle ID 重新定位后，日常 `default.store`、`default.store-wal`、`default.store-shm` 三个文件的 SHA-256 与检查前完全一致。11:18 已停止隔离候选并恢复原 1.1／3 安装包，三个日常库文件哈希再次一致，保留已启动设备供复用。记录：`/tmp/dontlift-release-b7-daily-store-restored-20261110.json`。

11:18:33 设备 Archive 成功：`/Users/yu/Library/Developer/Xcode/Archives/2026-11-10/DontLift-1.1-b7.xcarchive`。主 App 与 widget 的 `codesign --verify --deep --strict` 通过；归档为 Apple Development 签名。随后 Organizer 以 Apple Distribution 重签，两个 Store profile 均到期于 2027-09-06，App Group 一致，主 App 的 `aps-environment=production`、`get-task-allow=false`，预览版本均为 1.1／7。归档验证：`/tmp/dontlift-release-b7-archive-verified-20261110.json`。

Apple Developer 账号页实际提示需接受新版许可协议以恢复会员资源访问。签名虽能利用现有 profile 完成，上传阶段仍被合同门禁拒绝；没有代用户勾选或接受法律协议。错误日志：`/var/folders/yx/jf84mf0d6gd0hsk5wpftv2rm0000gn/T/DontLift_2026-11-10_11-19-53.318.xcdistributionlogs`，其中 `ContentDelivery.log` 和 `IDEDistribution.standard.log` 均记录该合同错误。

本轮 `devicectl` 只读查询的三台既有配对真机均为 `tunnelState=unavailable`，不能执行安装或真机验收；没有自动配对新设备或修改信任设置。记录：`/tmp/dontlift-release-b7-devices-20261110.json`。

真机按本次差异回归，记录设备、iOS、时间、实际入口、结果与已知问题：

| 路径 | 核对点 | 状态 |
| --- | --- | --- |
| 升级、冷启动与 Apple 登录 | 既有数据保留；画像恢复、失败重试与返回登录；真实登录后进入主界面 | 待验 |
| 历史另存个人计划 | 首页／日历两入口；普通／热身／递减组逐组值、备注、休息；取消、保存、重开，原记录不改名 | 待验 |
| 当前训练与计划 | 大字号／键盘输入；继续／取消／丢弃；四类排序取消／完成；结束、计划更新回执及撤销、PR／徽章关闭 | 待验 |
| 离线与同步 | 离线保存后重试；同步期间继续编辑／丢弃；大量记录、完整子树、部分失败提示与跨设备最终一致 | 待验 |
| Team | 列表／历史加载、失败重试、默认分享说明、主动分享取消与显式撤回、已登录用户操作 | 待验 |
| 系统字号与辅助功能 | 默认／大字号核心记录与计划编辑；真实 VoiceOver 主要操作、计时朗读、浮层不遮挡 | 待验 |
| 休息与系统能力 | 活动休息结束回填；前后台、锁屏、Live Activity／灵动岛、真实通知、HealthKit、widget 受影响路径 | 待验 |
| 海报与复盘 | 海报排版／系统分享、历史统计、徽章／回顾，无必经弹层阻塞 | 待验 |

## 合并、Tag 与回滚

- [ ] 必要的静态页面更新、生产健康和兼容检查完成；若另行部署应用，部署记录及备份齐备。
- [ ] build 7 为 `VALID`、可安装；真机主路径通过，阻塞问题清零并由用户确认。
- [ ] 候选、版本配置与三份发布文档均已提交／推送，核对最终 commit 与已验收候选一致。
- [ ] 满足以上门禁后才合并 `main`。有冲突解决或新差异时补验受影响范围；代码一致时复用有效结果。
- [ ] 创建并推送 annotated tag `v1.1-b7`，再回填三份文档的准确发布状态。**当前不要打 tag。**

候选 `df70ed8` 与记录 `039ac7b` 已提交并推送，法律静态页面已发布；build 7 已 Archive 并尝试上传，但上传失败，没有 `VALID`／可安装结论，没有合并 main 或创建 tag。后续改用 build 8；应用服务未部署。

回滚：出现客户端阻塞问题时停止候选分发，保留已确认可用的历史版本，修复后用新 build；不删除用户训练库。新建计划沿用既有格式，无数据库降级步骤。静态页面发布前保留的文件备份可用于恢复，但恢复旧文案后法律正文门禁会重新变为未完成。若另行部署应用，单独记录实际镜像、提交与可行回退方式，不默认旧镜像仍存在。
