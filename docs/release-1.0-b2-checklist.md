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
- [x] 🤖 **A2 后端单测通过** ✅（2026-06-14 `BUILD SUCCESSFUL`）
  ```bash
  cd backend && export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
  ./gradlew test
  ```
  本次新增了 `AccountDeletionServiceTest` / `ProfileServiceTest` / `AuthServiceRefreshTokenTest`，已全绿。
- [x] 🤖 **A3 iOS Release 编译验证** ✅（`BUILD SUCCEEDED`，Release 配置）
  ```bash
  cd ios/DontLift && xcodebuild -project DontLift.xcodeproj -scheme DontLift \
    -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -configuration Release CODE_SIGNING_ALLOWED=NO build
  ```
- [x] 🤖 **A4 提交版本 bump** ✅（提交 `d9b3ed8`，**尚未 push**——按计划等 C 上传成功后与 tag 一起推）
  ```bash
  git add ios/DontLift/DontLift.xcodeproj/project.pbxproj
  git commit -m "chore(release): build 号递增至 2，准备第二次 TestFlight 发版 (1.0 build 2)"
  ```

---

## 阶段 B · 后端先行部署（生产服务器，必须先于 iOS）

> **✅ 2026-06-14 已完成部署，线上 Flyway 到 v3、health UP。**
> 服务器:腾讯云轻量 `124.222.79.121`，Docker Compose 栈,生产目录 `/opt/DontLift-app/backend`。
> ⚠️ **服务器代码不是 git 仓库**（首次由本机同步上来，无 `.git`），更新走 **rsync 从本机同步,不能 `git pull`**（DEPLOY.md 第五节已同步订正）。

- [x] 🤖 **B1 部署前基线检查**：目录定位、容器状态(`dontlift-app` Up)、Flyway 基线(部署前 v1)、health UP——确认部署前线上正常。
- [x] 🤖 **B2 rsync 同步源码**（保护 `.env.prod`/`secrets/`/`backups/`，不传 build 产物；先 `-n` dry-run 校验不碰密钥再实跑）
  ```bash
  rsync -rlptz --exclude='.env.prod' --exclude='secrets/' --exclude='backups/' \
    --exclude='build/' --exclude='.gradle/' --exclude='.git/' --exclude='.idea/' \
    backend/ root@124.222.79.121:/opt/DontLift-app/backend/
  ```
  > 等效标准脚本 `./backend/deploy/local-deploy.sh root@124.222.79.121`，但该脚本的 `rsync --delete` **未排除 `backups/`** 会误删数据库备份，故本次改用上面这套手动 rsync。
- [ ] 🧑 **B3（可选）启用 Apple 授权主动撤销** —— **本次未配，走降级**（删号只删本地数据、不调 Apple `/auth/revoke`，**不阻断上架**）。
  - 若要启用：`.env.prod` 补 `APPLE_TEAM_ID` / `APPLE_KEY_ID` / `APPLE_KEY_PATH`（`.p8` 可复用已上传的 APNs Key，Team 级密钥），重新部署。值只写在服务器 `.env.prod`，不入库。
  - ⚠️ `.p8` 文件属主须为容器用户（历史坑：root 600 会 Permission denied 降级 no-op）。
- [x] 🤖 **B4 容器内重建并重启**（Flyway 启动时自动跑 V2/V3）
  ```bash
  ssh root@124.222.79.121 'cd /opt/DontLift-app/backend && \
    docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build'
  ```
  容器内 gradle `BUILD SUCCESSFUL`，镜像重建，`dontlift-app` Recreated + Started。
- [x] 🤖 **B5 迁移与启动确认**（日志核验）
  - Flyway：`Migrating ... to version "2 - add apple refresh token"` → `"3 - profile fields"` → `Successfully applied 2 migrations, now at version v3`
  - APNs 客户端正常初始化（无 no-op 降级）、`Started DontLiftApplication`，无 ERROR/Exception。
- [x] 🤖 **B6 线上验证**
  - health `https://dontlift.peipadada.com/actuator/health` → `{"status":"UP"}` ✅
  - `flyway_schema_history` 到 **v3**，3 条全 `success = t` ✅
  - 新列已落库：`app_user.sex`（CHECK `male`/`female`）、`user_identity.apple_refresh_token` ✅
  - dev token `POST /auth/dev/token` → **404**（生产已关闭）✅
  - 账号删除 / profile PATCH 等接口需 JWT 鉴权，留待阶段 E 真机回归。

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

> 建议至少两台设备（验证 Team 自动分享偏好、跨账号可见性与 APNs）。

- [ ] 🧑 **E1 首登资料补全**：新用户首次 Apple 登录 → 强制补全称呼/性别 → 进主界面；「我的」页可二次编辑。
- [ ] 🧑 **E2 账号删除**：「我的 → 账号 → 删除账号」二次确认 → `DELETE /account` 返回 2xx → 本地清空回登录页。
  - 若阶段 B3 配了凭据：服务器日志应见 Apple revoke 成功（未配则记 warn 降级，属预期）。
- [ ] 🧑 **E3 肌群高亮图**：动作详情肌群高亮正常，性别切换男/女体型生效。
- [ ] 🧑 **E4 Team 空态 + 全局 LIVE 胶囊**：未入团空态显示正常；训练中各 Tab 常驻 LIVE 胶囊。
- [ ] 🧑 **E5 APNs 生产投递**：第二账号入团 → 首个账号在 Team 中开启自动分享后完成训练 → 对应 Team 出现打卡 → 收到推送 + 表情回应。
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
