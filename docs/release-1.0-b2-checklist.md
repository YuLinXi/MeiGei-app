# 发版操作清单 — 别练了 1.0 (build 2)

> 第二次 TestFlight 发版。生成于 2026-06-14,提交范围 `f196cc5..HEAD`(28 个提交)。
> 基础设施（服务器 / Caddy / 共享 PG / APNs `.p8` / 隐私页 / App ID / App Store Connect 记录）
> 在**第一次发版**时已就绪,盘点见 [`testflight-checklist.md`](./testflight-checklist.md)。
> 本清单**只列本次增量**,不重复一次性的基础设施搭建。

## 🔐 安全约定（务必遵守）

- 本文档**只写环境变量名 / 占位符,绝不写任何真实密钥值**（JWT secret、Apple Key ID、Team ID、`.p8` 内容、数据库密码等）。
- 真实密钥只存在于:服务器 `backend/.env.prod`、服务器 `backend/secrets/`、你的密码管理器 / 加密盘。
- `.env.prod`、`*.p8` 已被 `.gitignore` 忽略,**永不提交**。提交前用 `git status` 确认没有密钥文件被误加。

## 图例

| 标记 | 含义 |
|---|---|
| 🤖 | **Claude 可代办**——本机命令、改代码、git 操作、写文案 |
| 🧑 | **必须你手动**——SSH 服务器、Xcode GUI、Apple 账号后台、真机、控制台 |
| 🤝 | 我给命令/内容,你来粘贴执行（涉及服务器凭据或线上副作用） |

---

## 0. 本次发版摘要

- **版本号**:`MARKETING_VERSION = 1.0`(不变) / `CURRENT_PROJECT_VERSION = 2`(build +1)
- **强依赖后端更新**:后端改动 1048 行 + **两个新 Flyway 迁移**(V2/V3),iOS build 2 的新功能（账号删除 / 首登补全）直接依赖。**后端必须先于或同步于 iOS build 2 上线。**
- **顺序安全性**:V2/V3 均为「加可空列、向后兼容」,旧 build 1 仍可正常运行 → 后端先上线**不会影响**存量 TestFlight 用户,可放心先发后端。
- iOS 端主要新功能:肌群高亮图（MuscleMap SDK，性别切换）、账号删除端到端、首登资料补全（称呼/性别）、Team 空态重设计、全局 LIVE 胶囊、各页 Header 统一。

---

## 阶段 A · 本地准备与验证

- [x] 🤖 **A1 build 号递增到 2**（已完成）
  - `project.pbxproj` 中 8 处 `CURRENT_PROJECT_VERSION` 全部 `1 → 2`，`MARKETING_VERSION` 保持 `1.0`（app 与 widget 两 target 同号）。
- [ ] 🤖 **A2 后端单测通过**
  ```bash
  cd backend && export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
  ./gradlew test
  ```
  本次新增了 `AccountDeletionServiceTest` / `ProfileServiceTest` / `AuthServiceRefreshTokenTest`，应全绿。
- [ ] 🤖 **A3 iOS Release 编译验证**（不签名，排除非签名问题）
  ```bash
  cd ios/DontLift && xcodebuild -project DontLift.xcodeproj -scheme DontLift \
    -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -configuration Release CODE_SIGNING_ALLOWED=NO build
  ```
- [ ] 🤖 **A4 提交版本 bump**（在 Archive 之前，保证发出去的代码=仓库某提交）
  ```bash
  git add ios/DontLift/DontLift.xcodeproj/project.pbxproj
  git commit -m "chore(release): build 号递增至 2，准备第二次 TestFlight 发版 (1.0 build 2)"
  ```

---

## 阶段 B · 后端先行部署（生产服务器，必须先于 iOS）

> 服务器:腾讯云轻量 `124.222.79.121`，Docker Compose 栈，剧本见 [`backend/DEPLOY.md`](../backend/DEPLOY.md) 第五节「更新 DontLift」。
> 生产目录通常为 `/opt/DontLift-app`（若改名前为 `/opt/MeiGei-app`，以服务器实际为准）。

- [ ] 🧑 **B1 SSH 登录生产服务器**（凭据只在你手上）
- [ ] 🤝 **B2 拉取新代码**
  ```bash
  cd /opt/DontLift-app && git pull
  ```
- [ ] 🧑 **B3（可选）启用 Apple 授权主动撤销（删号 revoke 完整路径）**
  - 本次后端新增 `application.yml` 配置项 `app.apple.client-id / team-id / key-id / key-path`。
  - **留空则自动降级**：删号仅删本地数据、不调 Apple `/auth/revoke`，**不阻断上架**。
  - 若要启用完整 revoke：`.p8` **可复用第一次已上传的 APNs Key**（Team 级密钥，见 `backend/secrets/`），在 `.env.prod` 补这三个变量（**只写变量名，值填你自己的**）：
    ```ini
    APPLE_TEAM_ID=<你的 Apple Team ID>
    APPLE_KEY_ID=<复用的 .p8 对应 Key ID>
    APPLE_KEY_PATH=/app/secrets/<你的 .p8 文件名>
    ```
  - ⚠️ `.p8` 文件属主须为容器用户（第一次踩过坑：root 600 会 Permission denied）。
- [ ] 🤝 **B4 重新构建并启动栈**（Flyway 启动时自动跑 V2/V3）
  ```bash
  cd /opt/DontLift-app/backend
  docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
  ```
- [ ] 🤝 **B5 看日志确认迁移与启动**
  ```bash
  docker compose -f docker-compose.prod.yml logs -f app
  ```
  关注：Flyway 报告 `Migrating ... V2__add_apple_refresh_token`、`V3__profile_fields`，随后 Spring `Started ... UP`。
- [ ] 🤝 **B6 线上验证**
  ```bash
  curl -s https://dontlift.peipadada.com/actuator/health      # 期望 {"status":"UP"}
  # 确认迁移落库（schema 版本应到 V3）
  docker exec -it shared-postgres psql -U dontlift -d dontlift -c "select version, description, success from flyway_schema_history order by installed_rank desc limit 3;"
  ```
  - 账号删除 / profile PATCH 等接口需 JWT 鉴权，真机登录后在阶段 E 回归，无需在此裸调。

---

## 阶段 C · iOS Archive 与上传（Xcode GUI + 真签名）

> 这几步必须在你本机 Xcode 里点，我无法代劳（需登录态签名 + Apple ID）。

- [ ] 🧑 **C1** Xcode 顶部目标设备选 **Any iOS Device (arm64)**（不能选模拟器）。
- [ ] 🧑 **C2** 菜单 **Product → Archive**（自动用 Release 配置 → API 强制走 `.production`）。
- [ ] 🧑 **C3** Organizer → **Distribute App → TestFlight & App Store Connect → Upload**，走完签名向导。
- [ ] 🧑 **C4 合规问卷**：已设 `ITSAppUsesNonExemptEncryption = false`，正常免答；若仍弹出选「未使用非豁免加密」。
- [ ] 🧑 **C5** 等 App Store Connect 处理完成（数分钟～半小时），TestFlight 出现 `1.0 (2)`。
  - 内部测试员（≤100 人）无需 Beta 审核，处理完即可安装。

---

## 阶段 D · 打 tag（上传成功后，锚定真正发出去的代码）

> 第一次发版未打 tag，从本次开始规范化。tag 同时带 marketing 与 build 号（同一 1.0 会有多个 build）。

- [ ] 🤖 **D1 打 tag 并推送**（**务必在 C5 上传成功后**执行）
  ```bash
  git tag -a v1.0-b2 -m "TestFlight 第二次发版：1.0 (build 2)

  - 肌群高亮图改用 MuscleMap SDK，支持性别切换
  - 账号删除端到端 + 我的页隐私链接/训练偏好/HealthKit
  - 首登资料补全（称呼/性别）+ 我的页二次编辑
  - Team 空态重设计、全局 LIVE 胶囊、各页 Header 统一"
  git push origin main --tags
  ```

---

## 阶段 E · 真机回归（重点压本次新功能）

> 建议至少两台设备（验证 Team 跨账号 fan-out 与 APNs）。

- [ ] 🧑 **E1 首登资料补全**：新用户首次 Apple 登录 → 强制补全称呼/性别 → 进主界面；「我的」页可二次编辑。
- [ ] 🧑 **E2 账号删除**：「我的 → 账号 → 删除账号」二次确认 → `DELETE /account` 返回 2xx → 本地清空回登录页。
  - 若阶段 B3 配了凭据：服务器日志应见 Apple revoke 成功（未配则记 warn 降级，属预期）。
- [ ] 🧑 **E3 肌群高亮图**：动作详情肌群高亮正常，性别切换男/女体型生效。
- [ ] 🧑 **E4 Team 空态 + 全局 LIVE 胶囊**：未入团空态显示正常；训练中各 Tab 常驻 LIVE 胶囊。
- [ ] 🧑 **E5 APNs 生产投递**：第二账号入团 → 完成训练触发打卡 fan-out → 收到推送 + 表情回应。
- [ ] 🧑 **E6** 测试设备删掉旧 build 1（如有沙盒脏数据，重装验证全新安装路径）。

---

## 回滚预案

- **后端**：`git checkout <上一个 tag/commit>` 后重新 `docker compose ... up -d --build` 即回退应用层。
  - V2/V3 是加可空列、向后兼容，**无需回滚 schema**（旧代码忽略新列即可正常运行）；不要手动 `DROP COLUMN`。
- **iOS**：TestFlight 可在内测组下线某个 build；新问题修复后递增到 build 3 重新上传（同一 1.0 下 build 号只增不减）。

---

## 附录 · TestFlight「本次更新」测试员文案（中文，可直接粘贴）

```
本次更新（1.0 build 2）：
• 训练动作详情支持肌群高亮图，可按性别切换体型
• 新增账号删除入口（我的 → 账号 → 删除账号）
• 首次登录引导补全称呼与性别，可在「我的」页随时修改
• 重做未加入团队时的引导页
• 训练中各页面常驻 LIVE 悬浮胶囊，随时回到当前训练
• 统一各页面顶部导航样式，多处文案与细节打磨

重点帮忙验证：账号删除、首次登录补全、肌群图性别切换。
```
