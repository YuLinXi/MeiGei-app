# 发版操作清单 — 别练了 1.0 (build 5)

> 生成于 2026-06-21，分支 `feature/v1.0-b5`，提交范围 `v1.0-b4..HEAD`。
> 本清单只记录 build 5 增量；一次性基础设施盘点见 [`testflight-checklist.md`](./testflight-checklist.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 5`。
- 后端强依赖：新增 Flyway `V5__plan_adaptive_mode.sql`，为 `workout_plan.mode` 和 `workout_exercise.plan_item_id` 落库。iOS build 5 的严格/自适应训练计划、实绩回写计划依赖该 schema。
- iOS 重点：训练计划 strict/adaptive 模式、开始训练时按历史或计划预填、训练后实绩回写计划、重复同动作计划项按 `planItemId` 精确归并、动作排序体验优化。
- 发布顺序：后端先上线并确认 Flyway V5 成功，再上传 iOS build 5 到 TestFlight。

## 1. Review 结论与已修复项

- [x] 已开启后端/发布子代理 review：未发现阻塞级后端代码问题；指出发布脚本只打印 Flyway 记录、不强校验最新迁移，以及备份脚本 `docker exec -t` 在非交互环境可能失败。
- [x] 已开启 iOS 子代理 review：发现重复同动作计划项可能被 historyKey 误归并、PR 庆祝弹窗与计划回写弹窗可能竞争、计划回写弹窗大列表按钮可能不可达。
- [x] 已修复 iOS `PlanPrefill` / `PlanWriteback`：优先按 `planItemId` 精确匹配；historyKey fallback 仅在唯一命中时生效，避免重复同动作串味。
- [x] 已修复根视图 sheet 队列：`MainTabView` 统一用一个根 sheet 依次展示计划回写和 PR 庆祝，避免同次训练弹窗竞争。
- [x] 已修复计划回写弹窗长列表：变更列表进入受限高度 `ScrollView`，底部操作按钮保持可达。
- [x] 已修复 `ExerciseHistoryMergeTests` 的 SwiftData 容器生命周期问题：测试用例显式持有 `ModelContainer`，避免 `ModelContext` 脱离容器后插入崩溃。

## 2. 已自动完成的本地准备

- [x] iOS build 号已递增到 `5`，App、widget、测试 target 同步。
- [x] iOS deployment target 已校正为 `17.4`，与项目最低系统要求一致，也避免 Xcode 26.4 simulator 无法运行测试 target。
- [x] 后端发布脚本已增强：自动识别本地最新 `V*__*.sql`，发布后断言 `flyway_schema_history` 中该版本 `success=true`。
- [x] 后端备份脚本已去掉 `docker exec -t`，适配 SSH/cron 非交互执行。
- [x] `backend/DEPLOY.md` 已更新为通用 `V*__*.sql` 迁移校验说明。
- [x] 本机已为 `124.222.79.121` 写入 ED25519 SSH host key（`SHA256:uUGxVKNAoW/tFdKNNGzfYowOh+cr/oLzaKJ1vSxAFec`），解决首次连接 host key 校验问题。

## 3. 自动验证结果

- [x] 后端脚本语法检查通过：
  ```bash
  bash -n backend/deploy/release-update.sh backend/scripts/db-backup.sh
  ```
- [x] 后端构建通过：
  ```bash
  cd backend
  JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home ./gradlew build
  ```
- [x] iOS 单测通过，`DontLiftTests` 共 52 个测试、6 个 suite：
  ```bash
  cd ios/DontLift
  xcodebuild -project DontLift.xcodeproj -scheme DontLiftTests \
    -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
  ```
- [x] iOS Release simulator 构建通过：
  ```bash
  cd ios/DontLift
  xcodebuild -project DontLift.xcodeproj -scheme DontLift \
    -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -configuration Release CODE_SIGNING_ALLOWED=NO build
  ```
- [x] 线上 health 当前可达：
  ```bash
  curl -fsS https://dontlift.peipadada.com/actuator/health
  # {"status":"UP","groups":["liveness","readiness"]}
  ```
- [x] 后端生产发布已完成（2026-06-21）：把 `id_ed25519` 加入 ssh-agent 后即可免密登录 `root@124.222.79.121`（此前失败仅因 agent 未加载 key）。`release-update.sh` 全流程通过：迁移前备份 `dontlift_2026-06-21_214150.sql.gz`、远程重建 `dontlift-app`、health `UP`、Flyway V5 `success=true`。

## 4. 后端发布步骤

> SSH 认证：把可登录 `root@124.222.79.121` 的私钥加入本机 ssh-agent（本次用 `ssh-add ~/.ssh/id_ed25519`），或用可用账号作为脚本第一个参数。

- [x] 确认可 SSH 登录（`VM-0-2-ubuntu`，三容器 `dontlift-app`/`edge-caddy`/`shared-postgres` 均 Up）。
- [x] 执行例行后端发布 `./backend/deploy/release-update.sh`（2026-06-21 成功）。
- [x] 发布脚本依次完成：
  - 远端备份生产库 `dontlift` → `dontlift_2026-06-21_214150.sql.gz`；
  - `rsync` 同步 `backend/` 源码（排除机密/备份/构建产物）；
  - 远端 `docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build`，Gradle `BUILD SUCCESSFUL`；
  - 公网 health `https://dontlift.peipadada.com/actuator/health` 返回 `UP`；
  - Flyway 最新迁移 `V5` 在 `flyway_schema_history` 中 `success=true`。
- [x] 发布后抽查（见下方命令，V5 已确认 success=true）：
  ```bash
  ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
    \"SELECT version || ' ' || description || ' success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""

  curl -fsS https://dontlift.peipadada.com/actuator/health
  ```
- [ ] 后端回归重点：登录/JWT、workout sync push/pull、计划 strict/adaptive mode 序列化、Team fork 计划模板、Team 自动分享偏好与显式 checkin API。

## 5. iOS TestFlight 上传步骤

> 这部分需你在 Xcode GUI 里完成，因为依赖 Apple ID 登录态、签名和 App Store Connect 权限。

- [ ] 确认后端 V5 已上线且 health 为 `UP`。
- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`，目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 里版本为 `1.0`、build 为 `5`。
- [ ] 菜单执行 `Product -> Archive`。
- [ ] Archive 成功后在 Organizer 里选择 `Distribute App -> App Store Connect -> Upload`。
- [ ] 走完 automatic signing；若加密合规问卷弹出，按当前配置选择未使用非豁免加密。
- [ ] 等 App Store Connect 处理完成，TestFlight 出现 `1.0 (5)`。
- [ ] 添加内部测试员；内部测试不需要 Beta App Review，处理完成后即可安装。

## 6. TestFlight 回归重点

- [ ] 新装 build 5 后 Apple 登录成功，Release API 指向 `https://dontlift.peipadada.com`。
- [ ] 新建训练计划，分别验证严格模式和自适应模式。
- [ ] 计划中放两个相同动作，开始训练后确认历史预填和训练后回写不会更新错计划项。
- [ ] 完成训练后若同时触发 PR 与计划回写，两个弹窗都能依次展示；计划回写可撤销。
- [ ] 大计划回写弹窗可滚动，底部操作按钮可点击。
- [ ] 训练动作排序、保存、同步后重启 App 仍保持顺序。
- [ ] Team fork 计划模板后，历史重量不被带入共享模板。
- [ ] 休息计时 Live Activity / 本地通知 / 提前结束仍正常。

## 7. 打 tag 与后续记录

- [ ] 后端发布成功、TestFlight 上传成功后打 tag：
  ```bash
  git tag -a v1.0-b5 -m "TestFlight 发版：1.0 (build 5)"
  git push origin feature/v1.0-b5 --tags
  ```
- [ ] 若 build 5 被 App Store Connect 拒收或 TestFlight 回归发现阻塞问题，修复后递增到 build 6，不复用 build 5。

## 8. 已知残余风险

- iOS 构建仍有既有 Swift 6 并发 warning；当前工程以 Swift 5 构建，未阻塞 Release build，但后续升级 Swift 6 前需要集中治理。
- TestFlight 真机签名、Apple 登录生产链路、APNs 真实投递仍需你用账号和真机完成最终验收。
- 后端生产发布已于 2026-06-21 完成（Flyway V5 上线）；后续若需复发，先 `ssh-add ~/.ssh/id_ed25519` 再重跑 `./backend/deploy/release-update.sh`。
