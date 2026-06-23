# 发版操作清单 — 别练了 1.0 (build 7)

> 生成于 2026-06-23，分支 `feature/v1.0-b7`，提交范围 `v1.0-b6..HEAD`。
> 本清单记录 build 7 增量；一次性基础设施盘点见 [`testflight-checklist.md`](./testflight-checklist.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 7`。
- 发布顺序：后端先上线并确认 Flyway V7 成功，再上传 iOS build 7 到 TestFlight。
- 后端强依赖：
  - `V6__sync_performance_indexes.sql`：补同步增量 pull 和 Team 打卡删除所需索引。
  - `V7__plan_groups.sql`：新增 `workout_plan_group` 表，并为 `workout_plan` 增加 `group_id` / `sort_order`。
- iOS 重点：训练历史日历和历史投影性能优化、计划分组与排序、统一纸感动作菜单、删号后本地计划分组清理。

## 1. 已自动完成的本地准备

- [x] 已提交发版前修复 `d0e9cd2`：统一动作菜单与删号清理。
- [x] iOS build 号已递增到 `7`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 后端本地构建通过。
- [x] iOS Release simulator 构建通过。
- [x] 后端生产发布完成（2026-06-23 21:50，备份 `dontlift_2026-06-23_214946.sql.gz`，Flyway V7 `success=true`）。

## 2. 后端发布前检查

- [x] 本地仓库处于预期分支：`feature/v1.0-b7`。
- [x] 后端最新迁移为 `V7__plan_groups.sql`。
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

- [x] 执行例行后端发布：
  ```bash
  ./backend/deploy/release-update.sh
  ```
- [x] 发布脚本完成迁移前数据库备份：`dontlift_2026-06-23_214946.sql.gz`。
- [x] `rsync` 已同步 `backend/` 源码，排除 `.env.prod`、`secrets/`、`backups/`、构建产物和 `.git/`。
- [x] 远端 `dontlift-app` 容器重建并启动成功。
- [x] 公网 HTTPS health 返回 `UP`：
  ```bash
  curl -fsS https://dontlift.peipadada.com/actuator/health
  ```
- [x] Flyway 最新迁移 `V7` 在生产库中 `success=true`：
  ```bash
  ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
    \"SELECT version || ' ' || description || ' success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
  ```
- [x] 确认生产禁用 dev token：
  ```bash
  curl -i -X POST https://dontlift.peipadada.com/auth/dev/token
  # 期望 404 或非 2xx
  ```

## 4. iOS TestFlight 上传步骤

> 这部分由你在 Xcode GUI 完成，依赖 Apple ID 登录态、签名和 App Store Connect 权限。

- [ ] 确认后端 V7 已上线且 health 为 `UP`。
- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`，目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 里版本为 `1.0`、build 为 `7`。
- [ ] 菜单执行 `Product -> Archive`。
- [ ] Archive 成功后在 Organizer 里选择 `Distribute App -> App Store Connect -> Upload`。
- [ ] 走完 automatic signing；若加密合规问卷弹出，按当前配置选择未使用非豁免加密。
- [ ] 等 App Store Connect 处理完成，TestFlight 出现 `1.0 (7)`。
- [ ] 添加内部测试员；内部测试不需要 Beta App Review，处理完成后即可安装。

## 5. TestFlight 回归重点

- [ ] 新装 build 7 后 Apple 登录成功，Release API 指向 `https://dontlift.peipadada.com`。
- [ ] 删除账号后本地计划分组、计划、训练、动作、Keychain JWT 均清理，重新登录不出现旧账号分组。
- [ ] 计划页顶部 `+`、分组 `...`、计划详情 `...` 均显示统一纸感动作菜单，菜单紧贴触发按钮且不溢出。
- [ ] 新建计划分组、重命名分组、移动计划到分组、调整分组顺序后，重启 App 仍保持分组和排序。
- [ ] 离线创建/编辑/删除计划分组后恢复网络，push/pull 同步一致。
- [ ] 历史日历可切换月份，训练详情进入和返回流畅。
- [ ] 训练历史列表和统计在大量数据下无明显卡顿。
- [ ] Team fork 计划模板、训练完成打卡 feed、emoji reaction 仍正常。
- [ ] 休息计时 Live Activity / 本地通知 / 提前结束仍正常。

## 6. 打 tag 与后续记录

- [ ] 后端发布成功、TestFlight 上传成功后打 tag：
  ```bash
  git tag -a v1.0-b7 -m "TestFlight 发版：1.0 (build 7)"
  git push origin feature/v1.0-b7 --tags
  ```
- [ ] 若 build 7 被 App Store Connect 拒收或 TestFlight 回归发现阻塞问题，修复后递增到 build 8，不复用 build 7。

## 7. 已知残余风险

- Team 顶部 `+` 的纸感菜单运行时验证受当前账号无 Team 且 `/teams` 返回 403 限制，入口不可触达；代码路径已替换为同一个 `CircleAddMenu`。
- TestFlight 真机签名、Apple 登录生产链路、APNs 真实投递仍需你用账号和真机完成最终验收。
