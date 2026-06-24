# 发版操作清单 — 别练了 1.0 (build 8)

> 生成于 2026-06-24，分支 `main`，提交范围 `v1.0-b7..HEAD`。
> 本清单记录 build 8 增量；一次性基础设施盘点见 [`testflight-checklist.md`](./testflight-checklist.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 8`。
- 发布顺序：后端先上线并确认 Flyway V10 成功，再由你上传 iOS build 8 到 TestFlight。
- 后端强依赖：
  - `V8__team_owner_transfer.sql`：记录删号时 Team owner 转移来源与时间。
  - `V9__clamp_future_sync_timestamps.sql`：补同步时间戳裁剪/回传所需字段能力。
  - `V10__team_auto_share_preference.sql`：为 `team_member` 增加自动分享偏好。
- iOS 重点：MVP 风险加固、删号影响面与本地清理、Team 显式/自动分享与离线队列、Live Activity Dynamic Island 展示、法务链接与同步时间校正提示。

## 1. 已自动完成的本地准备

- [x] 已合并 `feature/v1.0-b8` 到 `main`。
- [x] iOS build 号已递增到 `8`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 后端本地构建/测试通过：`backend ./gradlew build`。
- [x] iOS Release simulator 构建通过：`DontLift` scheme，`CODE_SIGNING_ALLOWED=NO`。
- [x] iOS 单元测试通过：`DontLiftTests` scheme。
- [ ] 后端生产发布完成，备份与 Flyway V10 状态待回填。

## 2. 后端发布前检查

- [x] 本地仓库处于预期分支：`main`。
- [x] 后端最新迁移为 `V10__team_auto_share_preference.sql`。
- [x] 线上 health 当前可达：
  ```bash
  curl -fsS https://dontlift.peipadada.com/actuator/health
  ```
- [x] SSH 可免密登录生产机：
  ```bash
  ssh -o BatchMode=yes root@124.222.79.121 'hostname'
  ```
- [x] 后端构建通过：
  ```bash
  cd backend
  JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build
  ```

## 3. 后端发布步骤

> 例行发布必须使用 `backend/deploy/release-update.sh`，不要在服务器上 `git pull`，也不要运行会覆盖共享基础设施的 `local-deploy.sh`。

- [ ] 执行例行后端发布：
  ```bash
  ./backend/deploy/release-update.sh
  ```
- [ ] 发布脚本完成迁移前数据库备份：待回填。
- [ ] `rsync` 已同步 `backend/` 源码，排除 `.env.prod`、`secrets/`、`backups/`、构建产物和 `.git/`。
- [ ] 远端 `dontlift-app` 容器重建并启动成功。
- [ ] 公网 HTTPS health 返回 `UP`：
  ```bash
  curl -fsS https://dontlift.peipadada.com/actuator/health
  ```
- [ ] Flyway 最新迁移 `V10` 在生产库中 `success=true`：
  ```bash
  ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
    \"SELECT version || ' ' || description || ' success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
  ```
- [ ] 确认生产禁用 dev token：
  ```bash
  curl -i -X POST https://dontlift.peipadada.com/auth/dev/token
  # 期望 404 或非 2xx
  ```

## 4. iOS TestFlight 上传步骤

> 这部分由你在 Xcode GUI 完成，依赖 Apple ID 登录态、签名和 App Store Connect 权限。

- [ ] 确认后端 V10 已上线且 health 为 `UP`。
- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`，目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 里版本为 `1.0`、build 为 `8`。
- [ ] 菜单执行 `Product -> Archive`。
- [ ] Archive 成功后在 Organizer 里选择 `Distribute App -> App Store Connect -> Upload`。
- [ ] 走完 automatic signing；若加密合规问卷弹出，按当前配置选择未使用非豁免加密。
- [ ] 等 App Store Connect 处理完成，TestFlight 出现 `1.0 (8)`。
- [ ] 添加内部测试员；内部测试不需要 Beta App Review，处理完成后即可安装。

## 5. TestFlight 回归重点

- [ ] 新装 build 8 后 Apple 登录成功，Release API 指向 `https://dontlift.peipadada.com`。
- [ ] 删号影响面展示正确；有 owned Team 时 owner 正确转移或清空 Team；已解散 owned Team 不阻断删号。
- [ ] 删除账号后本地 SwiftData、Keychain JWT、同步水位、Team 分享队列和自动分享缓存均清理。
- [ ] 手动选择 Team 分享训练：仅选中 Team 可见，撤回单个 Team 后个人训练记录保留。
- [ ] 自动分享偏好可开关；离线完成训练后恢复网络，等待 workout 同步成功后再重放分享队列。
- [ ] Team feed 的 checkin 与 reaction 一致，emoji reaction 单选/取消/切换正常。
- [ ] 修改系统时间异常或设备时间偏移后，同步时间校正提示不会破坏本地队列。
- [ ] Live Activity / Dynamic Island / 本地通知 / 提前结束仍正常。
- [ ] 法务链接（隐私政策、服务条款）可打开且为 HTTPS。
- [ ] 计划分组、训练历史、PR 庆祝、计划实绩回写无回归。

## 6. 打 tag 与后续记录

- [ ] 后端发布成功、TestFlight 上传成功后打 tag：
  ```bash
  git tag -a v1.0-b8 -m "TestFlight 发版：1.0 (build 8)"
  git push origin main --tags
  ```
- [ ] 若 build 8 被 App Store Connect 拒收或 TestFlight 回归发现阻塞问题，修复后递增到 build 9，不复用 build 8。

## 7. 已知残余风险

- TestFlight 真机签名、Apple 登录生产链路、APNs 真实投递仍需你用账号和真机完成最终验收。
- Team 分享离线队列依赖后端 workout 已同步；若用户长期离线或 workout 冲突，本次分享会保留到后续同步周期处理。
