# TestFlight 上架前准备清单

> 生成于 2026-06-11，基于工程实际配置盘点（分支 `chore/rename-dontlift`）。
> 总链条：**备案完成 → 服务器迁移 + APNs 凭据 → 删 ATS 例外 → 注册 App ID → Archive 上传 → 内部测试**。

## 一、仓库内已完成 ✅

- [x] App 图标就位：1024 尺寸 light / dark / tinted 三态（`Assets.xcassets/AppIcon.appiconset`）。
- [x] Release 构建强制走线上域名：`AppConfig.swift` 中 `#if DEBUG` 之外固定 `.production`（`https://dontlift.peipadada.com`）。
- [x] 隐私清单 `DontLift/PrivacyInfo.xcprivacy`（2026-06-11 新增）：
  - 唯一命中 required-reason API 的是 `UserDefaults`（SyncSupport 同步水位线、RestTimer 偏好），理由码 CA92.1。
  - 不追踪、无第三方 SDK；widget extension 未用到 required-reason API，无需单独清单。
  - **注意**：后续若新用到 文件时间戳 / 磁盘空间 / 系统启动时间 / 键盘列表 等 API，须同步补充声明，否则上传收 ITMS-91053 警告。
- [x] 出口合规声明 `ITSAppUsesNonExemptEncryption = false`（`DontLift-Info.plist`，2026-06-11 新增）：只用系统标准 HTTPS/Keychain 属豁免，每次上传免答合规问卷。

## 二、上传前必做的代码项（有前置依赖，暂不能动）

- [x] **删除 `NSAllowsArbitraryLoads` 公网明文口子**（2026-06-11 完成，已验证 `https://dontlift.peipadada.com/actuator/health` 返回 UP）。
  - `NSAppTransportSecurity` 改为仅含 `NSAllowsLocalNetworking`：保住模拟器 Debug 连 `localhost:8001` 明文联调，公网一律强制 HTTPS，随包发布不影响过审。
  - `AppConfig.swift` 的 `.serverIP`（公网 IP 明文）已标注不可用，真机联调改用 `.production`。
- [ ] **每次上传前递增 build 号**：当前 `MARKETING_VERSION = 1.0`、`CURRENT_PROJECT_VERSION = 1`；同版本号重复上传会被 App Store Connect 拒收，第二次起 build 改 2、3……

**无需手动改的**：entitlements 里 `aps-environment = development` 不用换——TestFlight 走 App Store 分发签名时 Xcode 自动换成 production；对应地后端推送须走 **APNs 生产网关**（客户端 Release 下上报 `apnsEnvironment = "production"`）。

## 三、服务器侧（剧本见 `backend/DEPLOY.md`）

- [x] **执行第七节「meigei → dontlift 迁移」**（2026-06-11 完成，已实测核验）：DNS A 记录生效、`dontlift` 库/角色已建、`.env.prod` 全新生成（`APNS_TOPIC`/`APPLE_AUDIENCES` 均为 `com.yulinxi.app.DontLift`）、新栈 `dontlift-app` 运行中、Caddy + Let's Encrypt 已上线、旧 meigei 栈已删。
- [x] **过一遍第六节上线检查清单**（2026-06-12 全部通过）：`JWT_SECRET` 48 位强随机 ✅、`APP_DEV_TOKEN=false`（`POST /auth/dev/token` 实测 404）✅、`/actuator/health` 返回 UP ✅、HTTPS 证书正常 ✅、备份 cron 已配（每日 3:30，手动跑通一次产物正常）✅。另：遗留的 `ip-access` socat 8080 明文口子已下线（**防火墙 8080 放行规则还需在轻量控制台「防火墙」标签页手动删除**）。
- [x] **APNs 生产凭据（.p8）配进 `.env.prod`**（2026-06-12 完成）：Key `YP8TF66M39` 已上传服务器 `secrets/apns.p8`（属主须为容器用户 `1001:999`，root 600 会 Permission denied），`APNS_KEY_ID`/`APNS_TEAM_ID` 已补全，compose 挂载已启用（仓库与服务器同步）。重启后实测 APNs 客户端正常初始化、无 no-op 降级日志。⚠️ .p8 不可再次下载，本机 `~/Desktop/yumengyuan/AuthKey_YP8TF66M39.p8` 务必另行备份（密码管理器/加密盘），勿入 git。

## 四、Apple Developer / App Store Connect 侧（需账号操作）

- [x] 主 App ID `com.yulinxi.app.DontLift` 已注册（2026-06-10 Xcode automatic signing 自动生成，本机已有对应 Team provisioning profile，entitlements 含 **Sign in with Apple、HealthKit（含 background delivery）、aps-environment** 三项 capability）。
  - widget ID `com.yulinxi.app.DontLift.DontLiftWidgets` 本机未见独立 profile（widget 无特殊 entitlements，开发期走通配）；Archive 分发时 Xcode automatic signing 会自动注册，无需手动建。
- [ ] App Store Connect 以新 bundle ID 新建 App「别练了」（改名后等于全新 App，旧 MeiGei 记录若建过则废弃）。
- [ ] 填 **App 隐私**问卷（健康数据、账号信息）和**隐私政策 URL**——用了 HealthKit 这是硬要求。
  - **隐私政策页面已就绪（2026-06-12）**：`https://dontlift.peipadada.com/privacy` 已上线（源文件 `backend/deploy/shared-infra/edge/site/dontlift/privacy/index.html`，经 Caddy file_server 托管），ASC 表单里直接填此 URL；问卷本身仍需账号操作。

### 上架硬卡点：账号删除与法律链接（change `profile-account-deletion-and-prefs`，2026-06-14）

- [x] **App 内「删除账号」路径已补齐（Apple 5.1.1(v) 硬要求）**：「我的 → 账号 → 删除账号」二次确认后调 `DELETE /account`，后端单事务**物理硬删**该用户本人数据；团主删号时多人 Team 保留并转移 owner，空 Team 才会删除。客户端成功后清本地 SwiftData + Keychain JWT 并回登录页。已用 dev token 端到端实测级联清零、影响面计数、重复删幂等（均 204）。
- [x] **隐私政策 / 服务条款 App 内可达**：登录页底部法律链接与「我的 → 关于」组均经 `SFSafariViewController` 打开后端页面（URL 收敛于 `AppConfig`，单一来源）。
- [ ] **发布硬门禁：独立法律链接已上线且 App 内可达**：外部 TestFlight / App Store 提交前必须确认 `https://dontlift.peipadada.com/privacy` 与 `https://dontlift.peipadada.com/terms` 均为独立 HTTPS 页面，登录页与「我的 → 关于」均可打开，且 `AppConfig.termsOfServiceURL != AppConfig.privacyPolicyURL`。
- [ ] **（可选，软阻塞）Apple 授权主动撤销凭据**：删号时若配 `APPLE_TEAM_ID` / `APPLE_KEY_ID` / `APPLE_KEY_PATH`（client_secret 签发用 .p8，可复用 APNs 同一 Key 或单独建），后端会调 Apple `/auth/revoke` 真正撤销授权；**凭据缺失时自动降级**（记 warn、跳过 revoke、仍完整删除本地数据并返回 2xx），不阻塞上架。登录持久化 `refresh_token` 同样依赖该凭据，缺失则老用户删号走 S2S 反向通知兜底。
- [ ] Xcode：Product → Archive → Distribute App（App Store Connect）上传；TestFlight 页填测试信息。
  - **内部测试员（≤100 人）不需要 Beta 审核**，处理完即可安装；外部测试员才走 Beta App Review。

## 五、发布前回归（对应 openspec 任务 5.3 / 5.4）

- [ ] 5.3 真机验证（iPhone 必测）：HealthKit 读写、休息 Live Activity（锁屏/灵动岛）、本地通知、前台声音与触觉反馈。
- [ ] 5.3 条件验证（有设备时）：iOS 18+ iPhone 配对 watchOS 11+ Apple Watch，观察 Watch Smart Stack 是否呈现；无匹配设备或系统未转呈时记录为“条件未测/平台未呈现”，不得判定为休息提醒失败。
- [ ] 5.4 TestFlight 灰度回归（**2026-06-12 已过半**，服务器日志逐项核验）：
  - [x] 真 Apple 登录（生产首个用户创建成功）
  - [x] 离线记录 → 云同步（workouts push/pull 200，幂等重推正常）
  - [x] APNs 设备令牌注册（`POST /devices/token` 200）
  - [x] 建团（含邀请码）
  - [ ] Team 自动分享偏好：默认关闭时完成训练不进 Team；在 Team 详情首次确认开启后，后续训练才自动进入该 Team；关闭后不再分享，历史可按次撤回。
  - [ ] APNs 真实投递 + 表情回应（需第二个账号入团：另一台手机装 TestFlight 包、用其自身 Apple ID 登录、邀请码入团）
- 已知观察项：①国行 iOS 首次联网权限未授予时首启报「offline」（设置→别练了→无线数据）；②服务器拉 Apple JWKS 偶发超时致首次登录 401、重试即好，频发再优化。
- 提醒：测试设备上的旧 MeiGei App 直接删掉（bundle ID 变了，沙盒数据不迁移）。

## 六、正式上架（App Store 审核）前的已知缺口

- [x] **App 内账号删除入口**（2026-06-14 完成，见第四节「上架硬卡点」小节）：后端 `DELETE /account` 级联硬删 + iOS「我的 → 账号 → 删除账号」二次确认入口已落地，满足 5.1.1(v)。
