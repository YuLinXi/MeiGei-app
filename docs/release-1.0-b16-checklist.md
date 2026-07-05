# 发版操作清单：别练了 1.0 (build 16)

> 生成于 2026-07-05 23:01 CST，分支 `feature/v1.0-b16`。
> 后端部署更新于 2026-07-05 23:22 CST。
> TestFlight 状态更新于 2026-07-05 23:33 CST。
> 本次发版功能介绍见 [`release-1.0-b16-feature-intro.md`](./release-1.0-b16-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 16`。
- 后端部署：已完成。生产 Flyway 最新为 `V18 workout set is warmup success=true`。
- iOS 状态：TestFlight `1.0 (16)` 已发布，用户已确认。
- iOS 重点：超级组训练单元、递减组升格为独立训练单元、热身标记独立化、训练 kcal 本地估算、分享海报 kcal 强展示。
- 发布顺序：后端已部署到 `V18` 并确认 health/Flyway；TestFlight `1.0 (16)` 已发布。
- Tag 策略：后端部署完成、TestFlight `1.0 (16)` 处理完成并确认可安装，允许创建并推送 `v1.0-b16`。

## 1. 已完成准备

- [x] 当前分支为 `feature/v1.0-b16`。
- [x] iOS build 号已递增到 `16`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 本次发版功能介绍已生成。
- [x] OpenSpec 校验通过：`openspec validate add-workout-calorie-estimates --type change --strict`。
- [x] 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- [x] iOS simulator test 通过：XcodeBuildMCP `test_sim CODE_SIGNING_ALLOWED=NO`，`145 passed, 0 failed, 0 skipped`。
- [x] iOS simulator build 通过：XcodeBuildMCP `build_sim CODE_SIGNING_ALLOWED=NO`。
- [x] `git diff --check` 通过。
- [x] 生产 health 当前为 `UP`。
- [x] 生产 dev token 当前返回 `404`，确认关闭。
- [x] 生产 Flyway 当前最新记录已查询：`18  workout set is warmup  success=true`。
- [x] 后端生产部署完成并确认 `V18` 迁移成功。
- [x] 部署前生产 DB 备份完成：`./backups/dontlift_2026-07-05_231315.sql.gz`。
- [x] TestFlight `1.0 (16)` 上传完成并可安装，2026-07-05 23:33 CST 由用户确认。
- [ ] TestFlight 真机主流程回归细节已补充到发版记录。
- [ ] `feature/v1.0-b16` 已合并回 `main`。
- [ ] `v1.0-b16` tag 已创建并推送。

## 2. 后端生产部署步骤

> 本次 build 16 包含后端迁移 `V17__workout_units.sql` 与 `V18__workout_set_is_warmup.sql`，需要先部署后端。
> 本次后端部署已于 2026-07-05 23:13 CST 完成，部署前 DB 备份为 `./backups/dontlift_2026-07-05_231315.sql.gz`。

- [x] 确认本地后端构建已通过。
- [x] 确认生产健康检查当前返回 `UP`：

```bash
curl -fsS https://dontlift.peipadada.com/actuator/health
```

- [x] 运行发布脚本：

```bash
./backend/deploy/release-update.sh
```

如需显式指定目标：

```bash
./backend/deploy/release-update.sh root@124.222.79.121 https://dontlift.peipadada.com/actuator/health
```

- [x] 确认脚本完成：
  - 迁移前生产 DB 备份完成。
  - `backend/` 已 rsync 到服务器，未覆盖 `.env.prod`、`secrets/`、`backups/`。
  - Docker build 和容器重启完成。
  - 公网 HTTPS health 返回 `UP`。
  - Flyway 最新迁移为 `18 workout set is warmup success=true`。

- [x] 部署后查询生产 Flyway：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
```

预期最新记录：

```text
18  workout set is warmup  success=true
17  workout units  success=true
16  workout set segments  success=true
15  checkin reaction push receipts  success=true
14  workout set rest seconds  success=true
```

- [x] 确认生产 dev token 仍关闭：

```bash
curl -s -o /tmp/dontlift_dev_token_status.txt -w '%{http_code}\n' \
  -X POST https://dontlift.peipadada.com/auth/dev/token
```

预期返回 `404`。

## 3. iOS TestFlight 上传步骤

- [x] 确认后端已部署到 `V18`，生产 health 为 `UP`。
- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `16`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 与 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (16)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (16)`。
- [ ] 安装 TestFlight build `1.0 (16)` 后开始真机回归。

## 4. TestFlight 主流程回归

- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动、同步、Team 页加载正常，不出现 401/403 或空白卡死。
- [ ] 训练中底部「添加动作」添加普通动作；结构菜单可添加递减组和超级组。
- [ ] 普通组、递减组、超级组创建后不可互相转换；删除后重新添加目标类型。
- [ ] 超级组创建两个动作、统一轮数，并按轮展示两个成员动作输入。
- [ ] 完成超级组一轮时两个成员组同步完成；取消完成时同步取消。
- [ ] 超级组轮后休息、下一组提示、加减轮数、删除超级组正常。
- [ ] 递减组独立训练单元可录入、添加/删除内部组、整体完成、整体热身和组后休息。
- [ ] 热身不计入组数、训练量、次数、PR；超级组热身按整轮生效，递减组热身按整个递减组生效。
- [ ] 训练详情、历史日历、PR、周统计和分享海报展示超级组/递减组结构正确。
- [ ] 「我的 > 训练偏好」可开启/关闭消耗估算，并可设置估算体重。
- [ ] 设置估算体重后，已完成训练详情展示 `约 xxx kcal · <强度>`。
- [ ] 未设置估算体重或关闭消耗估算时，训练详情和分享海报不展示 kcal。
- [ ] 分享海报展示 kcal 时仍保持时长、训练量、组数、动作列表可读。
- [ ] 计划详情可创建/编辑超级组和递减组；从计划开始训练能生成对应训练单元。
- [ ] 保存训练为计划后保留超级组/递减组结构。
- [ ] Team 分享计划与 Fork 保留结构和次数，重量字段仍被清空。
- [ ] Team 打卡详情能展示超级组与递减组结构；Team 摘要不展示 kcal。
- [ ] 跨设备同步一条包含超级组、递减组和热身标记的训练后，另一设备展示一致。

## 5. 合并、Tag 与推送

> 仅在后端部署完成、TestFlight 可安装、主流程回归通过后执行。

- [ ] 确认工作区只包含 build 16 预期改动。
- [ ] 推送发版分支：

```bash
git push origin feature/v1.0-b16
```

- [ ] 切换并更新 `main`：

```bash
git switch main
git pull --ff-only origin main
```

- [ ] 合并发版分支：

```bash
git merge --no-ff feature/v1.0-b16
```

- [ ] 创建并推送 tag：

```bash
git tag v1.0-b16
git push origin main
git push origin v1.0-b16
```

- [ ] 在发版记录中补充：
  - 后端部署完成时间。
  - DB 备份文件名。
  - 生产 Flyway 最新记录。
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 真机回归设备和 iOS 版本。
  - 是否发现超级组、递减组、kcal 估算、Team 同步或计划模板问题。
